import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/parsers/fixtures_parser.dart';
import 'package:eri_sports/data/import/parsers/match_detail_parser.dart';
import 'package:eri_sports/data/import/parsers/players_parser.dart';
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
  }) : _teamsParser = TeamsParser(),
       _fixturesParser = FixturesParser(),
       _standingsParser = StandingsParser(),
       _playersParser = PlayersParser(),
       _matchDetailParser = MatchDetailParser();

  final AppDatabase database;
  final DaylySportLocator daylySportLocator;
  final FileInventoryScanner scanner;
  final AppLogger logger;
  final TeamsParser _teamsParser;
  final FixturesParser _fixturesParser;
  final StandingsParser _standingsParser;
  final PlayersParser _playersParser;
  final MatchDetailParser _matchDetailParser;

  Future<ImportRunReport> runLocalImport({required String triggerType}) async {
    final startedAtUtc = DateTime.now().toUtc();
    final runId = await database
        .into(database.importRuns)
        .insert(
          ImportRunsCompanion.insert(
            triggerType: triggerType,
            startedAtUtc: startedAtUtc,
            status: 'running',
          ),
        );

    try {
      final daylySportDir =
          await daylySportLocator.getOrCreateDaylySportDirectory();
      final snapshots = await scanner.scanJsonFiles(daylySportDir);

      final latestChecksums = await _latestChecksumsByPath();
      var importedFileCount = 0;
      var skippedFileCount = 0;
      var failedFileCount = 0;

      for (final snapshot in snapshots) {
        final importFileId = await database
            .into(database.importFiles)
            .insert(
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
          await _markImportFileStatus(
            importFileId,
            status: 'skipped_unchanged',
          );
          continue;
        }

        try {
          final wasImported = await _importSnapshot(snapshot);
          if (wasImported) {
            importedFileCount++;
            await _markImportFileStatus(importFileId, status: 'imported');
          } else {
            skippedFileCount++;
            await _markImportFileStatus(
              importFileId,
              status: 'skipped_unsupported',
            );
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
        ..where((tbl) => tbl.id.equals(runId))).write(
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
        ..where((tbl) => tbl.id.equals(runId))).write(
        ImportRunsCompanion(
          finishedAtUtc: Value(finishedAtUtc),
          status: const Value('failed'),
          summaryJson: Value(jsonEncode({'error': error.toString()})),
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
    final rows =
        await (database.select(database.importFiles)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])).get();

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
      ..where((tbl) => tbl.id.equals(importFileId))).write(
      ImportFilesCompanion(
        status: Value(status),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  Future<bool> _importSnapshot(LocalJsonFileSnapshot snapshot) async {
    final filePath = snapshot.absolutePath;
    final lowerName = snapshot.fileName.toLowerCase();

    if (lowerName == 'fotmob_leagues_complete_data.json') {
      await _importFotmobLeaguesCompleteFile(File(filePath));
      return true;
    }

    if (lowerName == 'fotmob_matches_data.json') {
      await _importFotmobMatchesFile(File(filePath));
      return true;
    }

    if (lowerName == 'fotmob_teams_data.json') {
      await _importFotmobTeamsFile(File(filePath));
      return true;
    }

    if (lowerName == 'fotmob_standings_data.json') {
      await _importFotmobStandingsFile(File(filePath));
      return true;
    }

    if (lowerName == 'fotmob_match_details_data.json') {
      await _importFotmobMatchDetailsSummaryFile(File(filePath));
      return true;
    }

    if (lowerName == 'fixtures_full_data.json') {
      await _importFixturesFullFile(File(filePath));
      return true;
    }

    if (lowerName == 'top_score_data.json') {
      await _importTopScoreDataFile(File(filePath));
      return true;
    }

    if (lowerName.startsWith('top_standings_full_data') &&
        lowerName.endsWith('.json')) {
      await _importTopStandingsFullFile(File(filePath));
      return true;
    }

    if (lowerName.contains('match_detail') ||
        lowerName.contains('match-detail') ||
        lowerName.contains('timeline') ||
        lowerName.contains('incidents') ||
        lowerName.contains('events')) {
      await _importMatchDetailFile(File(filePath));
      return true;
    }

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

    if (lowerName.contains('player') || lowerName.contains('squad')) {
      await _importPlayersFile(File(filePath));
      return true;
    }

    return false;
  }

  Future<void> _importFotmobLeaguesCompleteFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final leagues = decoded['leagues'];
    if (leagues is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in leagues.entries) {
        final leagueKey = entry.key;
        final leagueData = entry.value;
        if (leagueData is! Map<String, dynamic>) {
          continue;
        }

        final meta = leagueData['meta'] as Map<String, dynamic>?;
        final explicitLeagueId = _asString(meta?['leagueId']);
        final competitionId = _competitionIdFromLeagueKey(
          leagueKey,
          explicitId: explicitLeagueId,
        );

        final leagueName =
            _asString(meta?['slug']) ??
            _competitionNameFromLeagueKey(leagueKey);

        await database
            .into(database.competitions)
            .insertOnConflictUpdate(
              CompetitionsCompanion.insert(
                id: competitionId,
                name: _normalizeLeagueName(leagueName),
                country: const Value(null),
                updatedAtUtc: now,
              ),
            );

        final teams = leagueData['teams'];
        if (teams is List) {
          for (final rawTeam in teams) {
            if (rawTeam is! Map<String, dynamic>) {
              continue;
            }

            final teamId = _asString(rawTeam['teamId']);
            final teamName = _asString(rawTeam['teamName']);
            if (teamId == null || teamName == null) {
              continue;
            }

            final isLeaguePlaceholder =
                teamId == competitionId &&
                _asString(rawTeam['pageUrl']) == null;
            if (isLeaguePlaceholder) {
              continue;
            }

            await database
                .into(database.teams)
                .insertOnConflictUpdate(
                  TeamsCompanion.insert(
                    id: teamId,
                    name: teamName,
                    shortName: Value(_asString(rawTeam['shortName'])),
                    competitionId: Value(competitionId),
                    updatedAtUtc: now,
                  ),
                );
          }
        }

        final matches = leagueData['matches'];
        if (matches is List) {
          await _importFotmobMatchRows(
            rows: matches,
            competitionId: competitionId,
            competitionName: _normalizeLeagueName(leagueName),
            now: now,
          );
        }

        final standingsRoot = leagueData['standings'];
        await _importFotmobStandingsForLeague(
          competitionId: competitionId,
          standingsRoot: standingsRoot,
          now: now,
        );
      }
    });
  }

  Future<void> _importFotmobMatchesFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in decoded.entries) {
        final leagueKey = entry.key;
        final rows = entry.value;
        if (rows is! List) {
          continue;
        }

        final competitionId = _competitionIdFromLeagueKey(leagueKey);
        final competitionName = _competitionNameFromLeagueKey(leagueKey);

        await _ensureCompetitionByName(competitionId, competitionName, now);
        await _importFotmobMatchRows(
          rows: rows,
          competitionId: competitionId,
          competitionName: competitionName,
          now: now,
        );
      }
    });
  }

  Future<void> _importFotmobTeamsFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in decoded.entries) {
        final leagueKey = entry.key;
        final rows = entry.value;
        if (rows is! List) {
          continue;
        }

        String competitionId = _competitionIdFromLeagueKey(leagueKey);
        String competitionName = _competitionNameFromLeagueKey(leagueKey);

        if (rows.isNotEmpty && rows.first is Map<String, dynamic>) {
          final first = rows.first as Map<String, dynamic>;
          final firstId = _asString(first['teamId']);
          final firstName = _asString(first['teamName']);
          final pageUrl = _asString(first['pageUrl']);
          if (firstId != null && firstName != null && pageUrl == null) {
            competitionId = firstId;
            competitionName = firstName;
          }
        }

        await _ensureCompetitionByName(competitionId, competitionName, now);

        for (final rawTeam in rows) {
          if (rawTeam is! Map<String, dynamic>) {
            continue;
          }

          final teamId = _asString(rawTeam['teamId']);
          final teamName = _asString(rawTeam['teamName']);
          if (teamId == null || teamName == null) {
            continue;
          }

          final isLeaguePlaceholder =
              teamId == competitionId && _asString(rawTeam['pageUrl']) == null;
          if (isLeaguePlaceholder) {
            continue;
          }

          await database
              .into(database.teams)
              .insertOnConflictUpdate(
                TeamsCompanion.insert(
                  id: teamId,
                  name: teamName,
                  shortName: Value(_asString(rawTeam['shortName'])),
                  competitionId: Value(competitionId),
                  updatedAtUtc: now,
                ),
              );
        }
      }
    });
  }

  Future<void> _importFotmobStandingsFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in decoded.entries) {
        final leagueKey = entry.key;
        final standingsRoot = entry.value;
        final competitionId = _competitionIdFromLeagueKey(leagueKey);
        final competitionName = _competitionNameFromLeagueKey(leagueKey);

        await _ensureCompetitionByName(competitionId, competitionName, now);
        await _importFotmobStandingsForLeague(
          competitionId: competitionId,
          standingsRoot: standingsRoot,
          now: now,
        );
      }
    });
  }

  Future<void> _importFotmobMatchDetailsSummaryFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in decoded.entries) {
        final leagueKey = entry.key;
        final rows = entry.value;
        if (rows is! List) {
          continue;
        }

        final competitionId = _competitionIdFromLeagueKey(leagueKey);
        final competitionName = _competitionNameFromLeagueKey(leagueKey);
        await _ensureCompetitionByName(competitionId, competitionName, now);

        for (final row in rows) {
          if (row is! Map<String, dynamic>) {
            continue;
          }

          final summary = row['summary'];
          if (summary is! Map<String, dynamic>) {
            continue;
          }

          final matchId =
              _asString(summary['matchId']) ?? _asString(row['matchId']);
          final homeTeamId = _asString(
            summary['homeTeam'] is Map
                ? (summary['homeTeam'] as Map)['id']
                : null,
          );
          final awayTeamId = _asString(
            summary['awayTeam'] is Map
                ? (summary['awayTeam'] as Map)['id']
                : null,
          );
          if (matchId == null || homeTeamId == null || awayTeamId == null) {
            continue;
          }

          final homeTeamName = _asString(
            summary['homeTeam'] is Map
                ? (summary['homeTeam'] as Map)['name']
                : null,
          );
          final awayTeamName = _asString(
            summary['awayTeam'] is Map
                ? (summary['awayTeam'] as Map)['name']
                : null,
          );

          final kickoff =
              DateTime.tryParse(_asString(summary['utcTime']) ?? '')?.toUtc();
          if (kickoff == null) {
            continue;
          }

          await _ensureTeamWithName(
            homeTeamId,
            homeTeamName,
            competitionId,
            now,
          );
          await _ensureTeamWithName(
            awayTeamId,
            awayTeamName,
            competitionId,
            now,
          );

          await database
              .into(database.matches)
              .insertOnConflictUpdate(
                MatchesCompanion.insert(
                  id: matchId,
                  competitionId: competitionId,
                  seasonId: const Value(null),
                  homeTeamId: homeTeamId,
                  awayTeamId: awayTeamId,
                  kickoffUtc: kickoff,
                  status: Value(_asString(summary['status']) ?? 'scheduled'),
                  homeScore: Value(
                    _asInt(
                          summary['homeTeam'] is Map
                              ? (summary['homeTeam'] as Map)['score']
                              : null,
                        ) ??
                        0,
                  ),
                  awayScore: Value(
                    _asInt(
                          summary['awayTeam'] is Map
                              ? (summary['awayTeam'] as Map)['score']
                              : null,
                        ) ??
                        0,
                  ),
                  roundLabel: Value(_asString(summary['roundName'])),
                  updatedAtUtc: now,
                ),
              );

          final detailPayload =
              Map<String, dynamic>.from(row)
                ..putIfAbsent('matchId', () => matchId)
                ..putIfAbsent('homeTeamId', () => homeTeamId)
                ..putIfAbsent('awayTeamId', () => awayTeamId);

          final parsedDetail = _matchDetailParser.parse(
            jsonEncode(detailPayload),
          );
          if (parsedDetail != null &&
              (parsedDetail.events.isNotEmpty ||
                  parsedDetail.stats.isNotEmpty)) {
            await _upsertParsedMatchDetail(parsedDetail, now);
          }
        }
      }
    });
  }

  Future<void> _importFixturesFullFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in decoded.entries) {
        final leagueKey = entry.key;
        final root = entry.value;
        if (root is! Map<String, dynamic>) {
          continue;
        }

        final meta = root['meta'] as Map<String, dynamic>?;
        final explicitLeagueId = _asString(meta?['leagueId']);
        final competitionId = _competitionIdFromLeagueKey(
          leagueKey,
          explicitId: explicitLeagueId,
        );
        final competitionName = _normalizeLeagueName(
          _asString(meta?['slug']) ?? _competitionNameFromLeagueKey(leagueKey),
        );

        await _ensureCompetitionByName(competitionId, competitionName, now);

        final fixtures = root['fixtures'];
        final extracted =
            fixtures is Map<String, dynamic> ? fixtures['extracted'] : null;
        final rows =
            extracted is Map<String, dynamic> ? extracted['allMatches'] : null;
        if (rows is! List) {
          continue;
        }

        await _importFotmobMatchRows(
          rows: rows,
          competitionId: competitionId,
          competitionName: competitionName,
          now: now,
        );
      }
    });
  }

  Future<void> _importTopStandingsFullFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in decoded.entries) {
        final leagueKey = entry.key;
        final root = entry.value;
        if (root is! Map<String, dynamic>) {
          continue;
        }

        final meta = root['meta'] as Map<String, dynamic>?;
        final explicitLeagueId = _asString(meta?['leagueId']);
        final competitionId = _competitionIdFromLeagueKey(
          leagueKey,
          explicitId: explicitLeagueId,
        );
        final competitionName = _normalizeLeagueName(
          _asString(meta?['slug']) ?? _competitionNameFromLeagueKey(leagueKey),
        );

        await _ensureCompetitionByName(competitionId, competitionName, now);

        await _importFotmobStandingsForLeague(
          competitionId: competitionId,
          standingsRoot: root['standings'],
          now: now,
        );
      }
    });
  }

  Future<void> _importTopScoreDataFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final entry in decoded.entries) {
        final leagueKey = entry.key;
        final root = entry.value;
        if (root is! Map<String, dynamic>) {
          continue;
        }

        final competitionId = _competitionIdFromLeagueKey(leagueKey);
        final competitionName = _competitionNameFromLeagueKey(leagueKey);

        await _ensureCompetitionByName(competitionId, competitionName, now);

        await (database.delete(database.topPlayerStats)
          ..where((tbl) => tbl.competitionId.equals(competitionId))).go();

        for (final statEntry in root.entries) {
          final statType = statEntry.key;
          final statRoot = statEntry.value;
          if (statRoot is! Map<String, dynamic>) {
            continue;
          }

          final statsData = statRoot['statsData'];
          if (statsData is! List) {
            continue;
          }

          for (final raw in statsData) {
            if (raw is! Map<String, dynamic>) {
              continue;
            }

            final playerId = _asString(raw['id']);
            final playerName = _asString(raw['name']);
            if (playerId == null || playerName == null) {
              continue;
            }

            final teamId = _asString(raw['teamId']);
            if (teamId != null) {
              await _ensureTeam(teamId, now);
            }
            await _ensurePlayer(playerId, playerName, teamId, now);

            final statValue = _asDouble(
              raw['statValue'] is Map
                  ? (raw['statValue'] as Map)['value']
                  : null,
            );
            if (statValue == null) {
              continue;
            }

            final subStatValue = _asDouble(
              raw['substatValue'] is Map
                  ? (raw['substatValue'] as Map)['value']
                  : null,
            );

            await database
                .into(database.topPlayerStats)
                .insert(
                  TopPlayerStatsCompanion.insert(
                    competitionId: competitionId,
                    seasonId: const Value(null),
                    statType: statType,
                    playerId: playerId,
                    teamId: Value(teamId),
                    playerName: playerName,
                    rank: _asInt(raw['rank']) ?? 999,
                    statValue: statValue,
                    subStatValue: Value(subStatValue),
                    updatedAtUtc: now,
                  ),
                );
          }
        }
      }
    });
  }

  Future<void> _importFotmobMatchRows({
    required List rows,
    required String competitionId,
    required String competitionName,
    required DateTime now,
  }) async {
    await _ensureCompetitionByName(competitionId, competitionName, now);

    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final matchId = _asString(raw['matchId']) ?? _asString(raw['id']);
      final homeTeamId =
          _asString(raw['homeTeamId']) ??
          _asString(raw['home'] is Map ? (raw['home'] as Map)['id'] : null);
      final awayTeamId =
          _asString(raw['awayTeamId']) ??
          _asString(raw['away'] is Map ? (raw['away'] as Map)['id'] : null);
      if (matchId == null || homeTeamId == null || awayTeamId == null) {
        continue;
      }

      final homeTeamName =
          _asString(raw['homeTeamName']) ??
          _asString(raw['home'] is Map ? (raw['home'] as Map)['name'] : null);
      final awayTeamName =
          _asString(raw['awayTeamName']) ??
          _asString(raw['away'] is Map ? (raw['away'] as Map)['name'] : null);

      final kickoff =
          DateTime.tryParse(
            _asString(raw['startTime']) ??
                _asString(
                  raw['status'] is Map
                      ? (raw['status'] as Map)['utcTime']
                      : null,
                ) ??
                '',
          )?.toUtc();
      if (kickoff == null) {
        continue;
      }

      String status = 'scheduled';
      final rawStatus = raw['status'];
      if (rawStatus is Map) {
        status =
            _asString(
              rawStatus['reason'] is Map
                  ? (rawStatus['reason'] as Map)['short']
                  : null,
            ) ??
            _asString(rawStatus['short']) ??
            status;
      }

      final scoreStr = _asString(
        rawStatus is Map ? rawStatus['scoreStr'] : null,
      );
      final parsedScore = _parseScoresStr(scoreStr);

      await _ensureTeamWithName(homeTeamId, homeTeamName, competitionId, now);
      await _ensureTeamWithName(awayTeamId, awayTeamName, competitionId, now);

      await database
          .into(database.matches)
          .insertOnConflictUpdate(
            MatchesCompanion.insert(
              id: matchId,
              competitionId: competitionId,
              seasonId: const Value(null),
              homeTeamId: homeTeamId,
              awayTeamId: awayTeamId,
              kickoffUtc: kickoff,
              status: Value(status),
              homeScore: Value(_asInt(raw['homeScore']) ?? parsedScore.$1),
              awayScore: Value(_asInt(raw['awayScore']) ?? parsedScore.$2),
              roundLabel: Value(
                _asString(raw['round']) ?? _asString(raw['roundName']),
              ),
              updatedAtUtc: now,
            ),
          );
    }
  }

  Future<void> _importFotmobStandingsForLeague({
    required String competitionId,
    required dynamic standingsRoot,
    required DateTime now,
  }) async {
    final rows = _extractFotmobStandingsRows(standingsRoot);

    await (database.delete(database.standingsRows)
      ..where((tbl) => tbl.competitionId.equals(competitionId))).go();

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final teamId =
          _asString(row['teamId']) ??
          _asString(row['id']) ??
          _asString(row['team'] is Map ? (row['team'] as Map)['id'] : null);
      final teamName =
          _asString(row['teamName']) ??
          _asString(row['name']) ??
          _asString(row['team'] is Map ? (row['team'] as Map)['name'] : null);
      if (teamId == null) {
        continue;
      }

      await _ensureTeamWithName(teamId, teamName, competitionId, now);

      final scoresStr = _asString(row['scoresStr']);
      final goals = _parseScoresStr(scoresStr);
      final goalsFor = _asInt(row['goalsFor']) ?? goals.$1;
      final goalsAgainst = _asInt(row['goalsAgainst']) ?? goals.$2;

      await database
          .into(database.standingsRows)
          .insert(
            StandingsRowsCompanion.insert(
              competitionId: competitionId,
              seasonId: const Value(null),
              teamId: teamId,
              position:
                  _asInt(row['idx']) ?? _asInt(row['position']) ?? (index + 1),
              played: Value(_asInt(row['played']) ?? _asInt(row['mp']) ?? 0),
              won: Value(
                _asInt(row['wins']) ??
                    _asInt(row['won']) ??
                    _asInt(row['w']) ??
                    0,
              ),
              draw: Value(
                _asInt(row['draws']) ??
                    _asInt(row['draw']) ??
                    _asInt(row['d']) ??
                    0,
              ),
              lost: Value(
                _asInt(row['losses']) ??
                    _asInt(row['lost']) ??
                    _asInt(row['l']) ??
                    0,
              ),
              goalsFor: Value(goalsFor),
              goalsAgainst: Value(goalsAgainst),
              goalDiff: Value(
                _asInt(row['goalConDiff']) ??
                    _asInt(row['goalDiff']) ??
                    (goalsFor - goalsAgainst),
              ),
              points: Value(_asInt(row['pts']) ?? _asInt(row['points']) ?? 0),
              form: Value(_asString(row['form']) ?? _asString(row['formStr'])),
              updatedAtUtc: now,
            ),
          );
    }
  }

  List<dynamic> _extractFotmobStandingsRows(dynamic standingsRoot) {
    if (standingsRoot is! Map<String, dynamic>) {
      return const [];
    }

    final flat = standingsRoot['flatTable'];
    if (flat is List) {
      return flat;
    }

    final tables = standingsRoot['tables'];
    if (tables is List) {
      final rows = <dynamic>[];
      for (final table in tables) {
        if (table is Map<String, dynamic>) {
          final tableRows = table['table'];
          if (tableRows is List) {
            rows.addAll(tableRows);
          }
        }
      }
      return rows;
    }

    final table = standingsRoot['table'];
    if (table is Map<String, dynamic>) {
      final all = table['all'];
      if (all is List) {
        return all;
      }
    }

    return const [];
  }

  Future<void> _ensureCompetitionByName(
    String competitionId,
    String competitionName,
    DateTime now,
  ) async {
    await database
        .into(database.competitions)
        .insertOnConflictUpdate(
          CompetitionsCompanion.insert(
            id: competitionId,
            name: competitionName,
            country: const Value(null),
            updatedAtUtc: now,
          ),
        );
  }

  Future<void> _ensureTeamWithName(
    String teamId,
    String? teamName,
    String? competitionId,
    DateTime now,
  ) async {
    final existing =
        await (database.select(database.teams)
          ..where((tbl) => tbl.id.equals(teamId))).getSingleOrNull();

    await database
        .into(database.teams)
        .insertOnConflictUpdate(
          TeamsCompanion.insert(
            id: teamId,
            name: teamName ?? existing?.name ?? 'Unknown Team',
            shortName: Value(existing?.shortName),
            competitionId: Value(competitionId ?? existing?.competitionId),
            updatedAtUtc: now,
          ),
        );
  }

  String _competitionIdFromLeagueKey(String key, {String? explicitId}) {
    if (explicitId != null && explicitId.isNotEmpty) {
      return explicitId;
    }
    final known = _fotmobLeagueIdByKey[key];
    if (known != null) {
      return known;
    }
    return key;
  }

  String _competitionNameFromLeagueKey(String key) {
    return key
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _normalizeLeagueName(String name) {
    return name
        .replaceAll('-', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) {
          final lower = p.toLowerCase();
          if (lower.length <= 2) {
            return lower.toUpperCase();
          }
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  (int, int) _parseScoresStr(String? scoresStr) {
    if (scoresStr == null || scoresStr.isEmpty) {
      return (0, 0);
    }

    final separator = scoresStr.contains('-') ? '-' : ':';
    final parts = scoresStr.split(separator);
    if (parts.length != 2) {
      return (0, 0);
    }

    final gf = int.tryParse(parts[0].trim()) ?? 0;
    final ga = int.tryParse(parts[1].trim()) ?? 0;
    return (gf, ga);
  }

  static const Map<String, String> _fotmobLeagueIdByKey = {
    'premier_league': '47',
    'europa_league': '73',
    'champions_league': '42',
    'laliga': '87',
    'bundesliga': '54',
    'serie_a': '55',
    'ligue1': '53',
    'fa_cup': '132',
  };

  Future<void> _importTeamsFile(File file) async {
    final content = await file.readAsString();
    final parsed = _teamsParser.parse(content);
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      for (final competition in parsed.competitions) {
        await database
            .into(database.competitions)
            .insertOnConflictUpdate(
              CompetitionsCompanion.insert(
                id: competition.id,
                name: competition.name,
                country: Value(competition.country),
                updatedAtUtc: now,
              ),
            );
      }

      for (final team in parsed.teams) {
        await database
            .into(database.teams)
            .insertOnConflictUpdate(
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
        await database
            .into(database.competitions)
            .insertOnConflictUpdate(
              CompetitionsCompanion.insert(
                id: competition.id,
                name: competition.name,
                country: Value(competition.country),
                updatedAtUtc: now,
              ),
            );
      }

      for (final team in parsed.teams) {
        await database
            .into(database.teams)
            .insertOnConflictUpdate(
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

        await database
            .into(database.matches)
            .insertOnConflictUpdate(
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
        await database
            .into(database.competitions)
            .insertOnConflictUpdate(
              CompetitionsCompanion.insert(
                id: competition.id,
                name: competition.name,
                country: Value(competition.country),
                updatedAtUtc: now,
              ),
            );
      }

      for (final team in parsed.teams) {
        await database
            .into(database.teams)
            .insertOnConflictUpdate(
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

        await database
            .into(database.standingsRows)
            .insert(
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

  Future<void> _importPlayersFile(File file) async {
    final content = await file.readAsString();
    final parsed = _playersParser.parse(content);
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      for (final player in parsed.players) {
        if (player.teamId != null) {
          await _ensureTeam(player.teamId!, now);
        }

        await database
            .into(database.players)
            .insertOnConflictUpdate(
              PlayersCompanion.insert(
                id: player.id,
                teamId: Value(player.teamId),
                name: player.name,
                position: Value(player.position),
                jerseyNumber: Value(player.jerseyNumber),
                photoAssetKey: const Value(null),
                updatedAtUtc: now,
              ),
            );
      }
    });
  }

  Future<void> _importMatchDetailFile(File file) async {
    final content = await file.readAsString();
    final parsed = _matchDetailParser.parse(content);
    if (parsed == null) {
      return;
    }

    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      await _upsertParsedMatchDetail(parsed, now);
    });
  }

  Future<void> _upsertParsedMatchDetail(
    MatchDetailParseResult parsed,
    DateTime now,
  ) async {
    await (database.delete(database.matchEvents)
      ..where((tbl) => tbl.matchId.equals(parsed.matchId))).go();
    await (database.delete(database.matchTeamStats)
      ..where((tbl) => tbl.matchId.equals(parsed.matchId))).go();

    for (final event in parsed.events) {
      if (event.teamId != null) {
        await _ensureTeam(event.teamId!, now);
      }
      if (event.playerId != null) {
        await _ensurePlayer(
          event.playerId!,
          event.playerName,
          event.teamId,
          now,
        );
      }

      await database
          .into(database.matchEvents)
          .insert(
            MatchEventsCompanion.insert(
              matchId: event.matchId,
              minute: event.minute,
              eventType: event.eventType,
              teamId: Value(event.teamId),
              playerId: Value(event.playerId),
              playerName: Value(event.playerName),
              detail: Value(event.detail),
            ),
          );
    }

    for (final stat in parsed.stats) {
      await _ensureTeam(stat.teamId, now);
      await database
          .into(database.matchTeamStats)
          .insert(
            MatchTeamStatsCompanion.insert(
              matchId: stat.matchId,
              teamId: stat.teamId,
              statKey: stat.statKey,
              statValue: stat.statValue,
            ),
          );
    }
  }

  Future<void> _ensureCompetition(String competitionId, DateTime now) async {
    final existing =
        await (database.select(database.competitions)
          ..where((tbl) => tbl.id.equals(competitionId))).getSingleOrNull();
    if (existing != null) {
      return;
    }

    await database
        .into(database.competitions)
        .insert(
          CompetitionsCompanion.insert(
            id: competitionId,
            name: 'Unknown Competition',
            country: const Value(null),
            updatedAtUtc: now,
          ),
        );
  }

  Future<void> _ensureTeam(String teamId, DateTime now) async {
    final existing =
        await (database.select(database.teams)
          ..where((tbl) => tbl.id.equals(teamId))).getSingleOrNull();
    if (existing != null) {
      return;
    }

    await database
        .into(database.teams)
        .insert(
          TeamsCompanion.insert(
            id: teamId,
            name: 'Unknown Team',
            shortName: const Value(null),
            competitionId: const Value(null),
            updatedAtUtc: now,
          ),
        );
  }

  Future<void> _ensurePlayer(
    String playerId,
    String? playerName,
    String? teamId,
    DateTime now,
  ) async {
    final existing =
        await (database.select(database.players)
          ..where((tbl) => tbl.id.equals(playerId))).getSingleOrNull();
    if (existing != null) {
      return;
    }

    await database
        .into(database.players)
        .insert(
          PlayersCompanion.insert(
            id: playerId,
            teamId: Value(teamId),
            name: playerName ?? 'Unknown Player',
            position: const Value(null),
            jerseyNumber: const Value(null),
            photoAssetKey: const Value(null),
            updatedAtUtc: now,
          ),
        );
  }
}
