import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/parsers/fixtures_parser.dart';
import 'package:eri_sports/data/import/parsers/standings_parser.dart';
import 'package:eri_sports/data/import/parsers/teams_parser.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';

class ImportRunReport {
  const ImportRunReport({
    required this.runId,
    required this.triggerType,
    required this.startedAtUtc,
    required this.finishedAtUtc,
    required this.sourcePath,
    required this.jsonFileCount,
    required this.status,
    this.errorMessage,
  });

  final int runId;
  final String triggerType;
  final DateTime startedAtUtc;
  final DateTime finishedAtUtc;
  final String sourcePath;
  final int jsonFileCount;
  final String status;
  final String? errorMessage;
}

class ImportCoordinator {
  ImportCoordinator({
    required this.database,
    required this.daylySportLocator,
    required this.scanner,
    required this.logger,
  })  : _teamsParser = TeamsParser(),
      _fixturesParser = FixturesParser(),
      _standingsParser = StandingsParser();

  final AppDatabase database;
  final DaylySportLocator daylySportLocator;
  final FileInventoryScanner scanner;
  final AppLogger logger;
  final TeamsParser _teamsParser;
  final FixturesParser _fixturesParser;
  final StandingsParser _standingsParser;

  Future<ImportRunReport> runLocalImport({
    required String triggerType,
  }) async {
    final startedAtUtc = DateTime.now().toUtc();
    final runId = await database.into(database.importRuns).insert(
          ImportRunsCompanion.insert(
            triggerType: triggerType,
            startedAtUtc: startedAtUtc,
            status: 'running',
          ),
        );

    try {
      final daylySportDir = await daylySportLocator.getOrCreateDaylySportDirectory();
      final snapshots = await scanner.scanJsonFiles(daylySportDir);

      final latestChecksums = await _latestChecksumsByPath();
      var importedFileCount = 0;
      var skippedFileCount = 0;
      var failedFileCount = 0;

      for (final snapshot in snapshots) {
        final importFileId = await database.into(database.importFiles).insert(
              ImportFilesCompanion.insert(
                runId: runId,
                fileName: snapshot.fileName,
                relativePath: snapshot.relativePath,
                checksum: snapshot.checksum,
                status: 'queued',
              ),
            );

        final previousChecksum = latestChecksums[snapshot.relativePath];
        if (previousChecksum != null && previousChecksum == snapshot.checksum) {
          skippedFileCount++;
          await _markImportFileStatus(importFileId, status: 'skipped_unchanged');
          continue;
        }

        try {
          final wasImported = await _importSnapshot(snapshot);
          if (wasImported) {
            importedFileCount++;
            await _markImportFileStatus(importFileId, status: 'imported');
          } else {
            skippedFileCount++;
            await _markImportFileStatus(importFileId, status: 'skipped_unsupported');
          }
        } catch (error) {
          failedFileCount++;
          await _markImportFileStatus(
            importFileId,
            status: 'failed',
            errorMessage: error.toString(),
          );
          logger.warn('Failed to import ${snapshot.relativePath}: $error');
        }
      }

      final finishedAtUtc = DateTime.now().toUtc();
      final runStatus = failedFileCount == 0 ? 'success' : 'partial_success';
      final summary = {
        'files_scanned': snapshots.length,
        'files_imported': importedFileCount,
        'files_skipped': skippedFileCount,
        'files_failed': failedFileCount,
        'source_path': daylySportDir.path,
      };

      await (database.update(database.importRuns)
            ..where((tbl) => tbl.id.equals(runId)))
          .write(
        ImportRunsCompanion(
          finishedAtUtc: Value(finishedAtUtc),
          status: Value(runStatus),
          summaryJson: Value(jsonEncode(summary)),
        ),
      );

      logger.info(
        'Local import completed. imported=$importedFileCount skipped=$skippedFileCount failed=$failedFileCount',
      );

      return ImportRunReport(
        runId: runId,
        triggerType: triggerType,
        startedAtUtc: startedAtUtc,
        finishedAtUtc: finishedAtUtc,
        sourcePath: daylySportDir.path,
        jsonFileCount: snapshots.length,
        status: runStatus,
      );
    } catch (error) {
      final finishedAtUtc = DateTime.now().toUtc();
      await (database.update(database.importRuns)
            ..where((tbl) => tbl.id.equals(runId)))
          .write(
        ImportRunsCompanion(
          finishedAtUtc: Value(finishedAtUtc),
          status: const Value('failed'),
          summaryJson: Value(
            jsonEncode({
              'error': error.toString(),
            }),
          ),
        ),
      );

      logger.error('Local import failed.', error);

      return ImportRunReport(
        runId: runId,
        triggerType: triggerType,
        startedAtUtc: startedAtUtc,
        finishedAtUtc: finishedAtUtc,
        sourcePath: '',
        jsonFileCount: 0,
        status: 'failed',
        errorMessage: error.toString(),
      );
    }
  }

  Future<Map<String, String>> _latestChecksumsByPath() async {
    final rows = await (database.select(database.importFiles)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .get();

    final checksumsByPath = <String, String>{};
    for (final row in rows) {
      checksumsByPath.putIfAbsent(row.relativePath, () => row.checksum);
    }

    return checksumsByPath;
  }

  Future<void> _markImportFileStatus(
    int importFileId, {
    required String status,
    String? errorMessage,
  }) {
    return (database.update(database.importFiles)
          ..where((tbl) => tbl.id.equals(importFileId)))
        .write(
      ImportFilesCompanion(
        status: Value(status),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  Future<bool> _importSnapshot(LocalJsonFileSnapshot snapshot) async {
    final filePath = snapshot.absolutePath;
    final lowerName = snapshot.fileName.toLowerCase();

    if (lowerName.contains('team')) {
      await _importTeamsFile(File(filePath));
      return true;
    }

    if (lowerName.contains('fixture') || lowerName.contains('match')) {
      await _importFixturesFile(File(filePath));
      return true;
    }

    if (lowerName.contains('standing') || lowerName.contains('table')) {
      await _importStandingsFile(File(filePath));
      return true;
    }

    return false;
  }

  Future<void> _importTeamsFile(File file) async {
    final content = await file.readAsString();
    final parsed = _teamsParser.parse(content);
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      for (final competition in parsed.competitions) {
        await database.into(database.competitions).insertOnConflictUpdate(
              CompetitionsCompanion.insert(
                id: competition.id,
                name: competition.name,
                country: Value(competition.country),
                updatedAtUtc: now,
              ),
            );
      }

      for (final team in parsed.teams) {
        await database.into(database.teams).insertOnConflictUpdate(
              TeamsCompanion.insert(
                id: team.id,
                name: team.name,
                shortName: Value(team.shortName),
                competitionId: Value(team.competitionId),
                updatedAtUtc: now,
              ),
            );
      }
    });
  }

  Future<void> _importFixturesFile(File file) async {
    final content = await file.readAsString();
    final parsed = _fixturesParser.parse(content);
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      for (final competition in parsed.competitions) {
        await database.into(database.competitions).insertOnConflictUpdate(
              CompetitionsCompanion.insert(
                id: competition.id,
                name: competition.name,
                country: Value(competition.country),
                updatedAtUtc: now,
              ),
            );
      }

      for (final team in parsed.teams) {
        await database.into(database.teams).insertOnConflictUpdate(
              TeamsCompanion.insert(
                id: team.id,
                name: team.name,
                shortName: Value(team.shortName),
                competitionId: Value(team.competitionId),
                updatedAtUtc: now,
              ),
            );
      }

      for (final match in parsed.matches) {
        await _ensureCompetition(match.competitionId, now);
        await _ensureTeam(match.homeTeamId, now);
        await _ensureTeam(match.awayTeamId, now);

        await database.into(database.matches).insertOnConflictUpdate(
              MatchesCompanion.insert(
                id: match.id,
                competitionId: match.competitionId,
                seasonId: const Value(null),
                homeTeamId: match.homeTeamId,
                awayTeamId: match.awayTeamId,
                kickoffUtc: match.kickoffUtc,
                status: Value(match.status),
                homeScore: Value(match.homeScore),
                awayScore: Value(match.awayScore),
                roundLabel: Value(match.roundLabel),
                updatedAtUtc: now,
              ),
            );
      }
    });
  }

  Future<void> _importStandingsFile(File file) async {
    final content = await file.readAsString();
    final parsed = _standingsParser.parse(content);
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      for (final competition in parsed.competitions) {
        await database.into(database.competitions).insertOnConflictUpdate(
              CompetitionsCompanion.insert(
                id: competition.id,
                name: competition.name,
                country: Value(competition.country),
                updatedAtUtc: now,
              ),
            );
      }

      for (final team in parsed.teams) {
        await database.into(database.teams).insertOnConflictUpdate(
              TeamsCompanion.insert(
                id: team.id,
                name: team.name,
                shortName: Value(team.shortName),
                competitionId: Value(team.competitionId),
                updatedAtUtc: now,
              ),
            );
      }

      final keyPairs = <(String, String?)>{};
      for (final row in parsed.rows) {
        keyPairs.add((row.competitionId, row.seasonId));
      }

      for (final keyPair in keyPairs) {
        final competitionId = keyPair.$1;
        final seasonId = keyPair.$2;
        final deleteQuery = database.delete(database.standingsRows)
          ..where((tbl) => tbl.competitionId.equals(competitionId));
        if (seasonId == null) {
          deleteQuery.where((tbl) => tbl.seasonId.isNull());
        } else {
          deleteQuery.where((tbl) => tbl.seasonId.equals(seasonId));
        }
        await deleteQuery.go();
      }

      for (final row in parsed.rows) {
        await _ensureCompetition(row.competitionId, now);
        await _ensureTeam(row.teamId, now);

        await database.into(database.standingsRows).insert(
              StandingsRowsCompanion.insert(
                competitionId: row.competitionId,
                seasonId: Value(row.seasonId),
                teamId: row.teamId,
                position: row.position,
                played: Value(row.played),
                won: Value(row.won),
                draw: Value(row.draw),
                lost: Value(row.lost),
                goalsFor: Value(row.goalsFor),
                goalsAgainst: Value(row.goalsAgainst),
                goalDiff: Value(row.goalDiff),
                points: Value(row.points),
                form: Value(row.form),
                updatedAtUtc: now,
              ),
            );
      }
    });
  }

  Future<void> _ensureCompetition(String competitionId, DateTime now) async {
    final existing = await (database.select(database.competitions)
          ..where((tbl) => tbl.id.equals(competitionId)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }

    await database.into(database.competitions).insert(
          CompetitionsCompanion.insert(
            id: competitionId,
            name: 'Unknown Competition',
            country: const Value(null),
            updatedAtUtc: now,
          ),
        );
  }

  Future<void> _ensureTeam(String teamId, DateTime now) async {
    final existing = await (database.select(database.teams)
          ..where((tbl) => tbl.id.equals(teamId)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }

    await database.into(database.teams).insert(
          TeamsCompanion.insert(
            id: teamId,
            name: 'Unknown Team',
            shortName: const Value(null),
            competitionId: const Value(null),
            updatedAtUtc: now,
          ),
        );
  }
}