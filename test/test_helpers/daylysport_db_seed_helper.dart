import 'package:drift/drift.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';

Future<ImportRunReport> seedOfflineDbForTests(AppDatabase database) async {
  final now = DateTime.now().toUtc();

  await database.into(database.competitions).insertOnConflictUpdate(
    CompetitionsCompanion.insert(
      id: '47',
      name: 'Premier League',
      country: const Value('England'),
      updatedAtUtc: now,
    ),
  );

  await database.into(database.teams).insertOnConflictUpdate(
    TeamsCompanion.insert(
      id: '9825',
      name: 'Arsenal',
      shortName: const Value('ARS'),
      competitionId: const Value('47'),
      updatedAtUtc: now,
    ),
  );
  await database.into(database.teams).insertOnConflictUpdate(
    TeamsCompanion.insert(
      id: '8650',
      name: 'Liverpool',
      shortName: const Value('LIV'),
      competitionId: const Value('47'),
      updatedAtUtc: now,
    ),
  );

  await database.into(database.players).insertOnConflictUpdate(
    PlayersCompanion.insert(
      id: '961995',
      teamId: const Value('9825'),
      name: 'Bukayo Saka',
      position: const Value('MID'),
      jerseyNumber: const Value(7),
      photoAssetKey: const Value(null),
      updatedAtUtc: now,
    ),
  );

  await database.into(database.matches).insertOnConflictUpdate(
    MatchesCompanion.insert(
      id: '1001',
      competitionId: '47',
      seasonId: const Value('2025/2026'),
      homeTeamId: '9825',
      awayTeamId: '8650',
      kickoffUtc: now,
      status: const Value('live'),
      homeScore: const Value(2),
      awayScore: const Value(1),
      roundLabel: const Value('Matchday 30'),
      updatedAtUtc: now,
    ),
  );

  await database.into(database.standingsRows).insert(
    StandingsRowsCompanion.insert(
      competitionId: '47',
      seasonId: const Value('2025/2026'),
      teamId: '9825',
      position: 1,
      played: const Value(30),
      won: const Value(25),
      draw: const Value(4),
      lost: const Value(1),
      goalsFor: const Value(72),
      goalsAgainst: const Value(20),
      goalDiff: const Value(52),
      points: const Value(79),
      form: const Value('WWDWW'),
      updatedAtUtc: now,
    ),
  );
  await database.into(database.standingsRows).insert(
    StandingsRowsCompanion.insert(
      competitionId: '47',
      seasonId: const Value('2025/2026'),
      teamId: '8650',
      position: 2,
      played: const Value(30),
      won: const Value(22),
      draw: const Value(5),
      lost: const Value(3),
      goalsFor: const Value(68),
      goalsAgainst: const Value(28),
      goalDiff: const Value(40),
      points: const Value(71),
      form: const Value('WDWWW'),
      updatedAtUtc: now,
    ),
  );

  await database.into(database.matchEvents).insert(
    MatchEventsCompanion.insert(
      matchId: '1001',
      minute: 12,
      eventType: 'goal',
      teamId: const Value('9825'),
      playerId: const Value('961995'),
      playerName: const Value('Bukayo Saka'),
      detail: const Value('Left-footed finish'),
    ),
  );

  await database.into(database.matchTeamStats).insert(
    MatchTeamStatsCompanion.insert(
      matchId: '1001',
      teamId: '9825',
      statKey: 'possession',
      statValue: 56,
    ),
  );
  await database.into(database.matchTeamStats).insert(
    MatchTeamStatsCompanion.insert(
      matchId: '1001',
      teamId: '8650',
      statKey: 'possession',
      statValue: 44,
    ),
  );
  await database.into(database.matchTeamStats).insert(
    MatchTeamStatsCompanion.insert(
      matchId: '1001',
      teamId: '9825',
      statKey: 'shots_on_target',
      statValue: 7,
    ),
  );
  await database.into(database.matchTeamStats).insert(
    MatchTeamStatsCompanion.insert(
      matchId: '1001',
      teamId: '8650',
      statKey: 'shots_on_target',
      statValue: 4,
    ),
  );
  await database.into(database.matchTeamStats).insert(
    MatchTeamStatsCompanion.insert(
      matchId: '1001',
      teamId: '9825',
      statKey: 'corners',
      statValue: 5,
    ),
  );
  await database.into(database.matchTeamStats).insert(
    MatchTeamStatsCompanion.insert(
      matchId: '1001',
      teamId: '8650',
      statKey: 'corners',
      statValue: 2,
    ),
  );

  return ImportRunReport(
    runId: 1,
    triggerType: 'startup',
    startedAtUtc: now,
    finishedAtUtc: now,
    sourcePath: 'test-seed',
    jsonFileCount: 6,
    processedFileCount: 6,
    status: 'completed',
    importedFileCount: 6,
    skippedFileCount: 0,
    failedFileCount: 0,
    importedRelativePaths: const [
      'teams_2026_04_03.json',
      'fixtures_2026_04_03.json',
      'standings_2026_04_03.json',
      'top_standings_full_data_2026_04_03.json',
      'players_2026_04_03.json',
      'match_detail_1001.json',
    ],
    skippedRelativePaths: const [],
    failedRelativePaths: const [],
    affectedDomains: const {
      DaylysportDataDomain.catalog,
      DaylysportDataDomain.matches,
      DaylysportDataDomain.playerStats,
      DaylysportDataDomain.standings,
    },
  );
}