import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('CompetitionRow')
class Competitions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get country => text().nullable()();
  TextColumn get logoAssetKey => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TeamRow')
class Teams extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get shortName => text().nullable()();
  TextColumn get competitionId =>
      text().nullable().references(Competitions, #id)();
  TextColumn get badgeAssetKey => text().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PlayerRow')
class Players extends Table {
  TextColumn get id => text()();
  TextColumn get teamId => text().nullable().references(Teams, #id)();
  TextColumn get name => text()();
  TextColumn get position => text().nullable()();
  IntColumn get jerseyNumber => integer().nullable()();
  TextColumn get photoAssetKey => text().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MatchRow')
class Matches extends Table {
  TextColumn get id => text()();
  TextColumn get competitionId => text().references(Competitions, #id)();
  TextColumn get seasonId => text().nullable()();
  TextColumn get homeTeamId => text().references(Teams, #id)();
  TextColumn get awayTeamId => text().references(Teams, #id)();
  DateTimeColumn get kickoffUtc => dateTime()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  IntColumn get homeScore => integer().withDefault(const Constant(0))();
  IntColumn get awayScore => integer().withDefault(const Constant(0))();
  TextColumn get roundLabel => text().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MatchEventRow')
class MatchEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get matchId => text().references(Matches, #id)();
  IntColumn get minute => integer()();
  TextColumn get eventType => text()();
  TextColumn get teamId => text().nullable().references(Teams, #id)();
  TextColumn get playerId => text().nullable().references(Players, #id)();
  TextColumn get playerName => text().nullable()();
  TextColumn get detail => text().nullable()();
}

@DataClassName('MatchTeamStatRow')
class MatchTeamStats extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get matchId => text().references(Matches, #id)();
  TextColumn get teamId => text().references(Teams, #id)();
  TextColumn get statKey => text()();
  RealColumn get statValue => real()();
}

@DataClassName('TopPlayerStatRow')
class TopPlayerStats extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get competitionId => text().references(Competitions, #id)();
  TextColumn get seasonId => text().nullable()();
  TextColumn get statType => text()();
  TextColumn get playerId => text().references(Players, #id)();
  TextColumn get teamId => text().nullable().references(Teams, #id)();
  TextColumn get playerName => text()();
  IntColumn get rank => integer()();
  RealColumn get statValue => real()();
  RealColumn get subStatValue => real().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();
}

@DataClassName('StandingsRowData')
class StandingsRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get competitionId => text().references(Competitions, #id)();
  TextColumn get seasonId => text().nullable()();
  TextColumn get teamId => text().references(Teams, #id)();
  IntColumn get position => integer()();
  IntColumn get played => integer().withDefault(const Constant(0))();
  IntColumn get won => integer().withDefault(const Constant(0))();
  IntColumn get draw => integer().withDefault(const Constant(0))();
  IntColumn get lost => integer().withDefault(const Constant(0))();
  IntColumn get goalsFor => integer().withDefault(const Constant(0))();
  IntColumn get goalsAgainst => integer().withDefault(const Constant(0))();
  IntColumn get goalDiff => integer().withDefault(const Constant(0))();
  IntColumn get points => integer().withDefault(const Constant(0))();
  TextColumn get form => text().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();
}

@DataClassName('AssetRefRow')
class AssetRefs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get variant => text().withDefault(const Constant('default'))();
  TextColumn get filePath => text()();
  TextColumn get fileHash => text().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();
}

@DataClassName('ImportRunRow')
class ImportRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get triggerType => text()();
  DateTimeColumn get startedAtUtc => dateTime()();
  DateTimeColumn get finishedAtUtc => dateTime().nullable()();
  TextColumn get status => text()();
  TextColumn get summaryJson => text().withDefault(const Constant('{}'))();
}

@DataClassName('ImportFileRow')
class ImportFiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get runId => integer().references(ImportRuns, #id)();
  TextColumn get fileName => text()();
  TextColumn get relativePath => text()();
  TextColumn get checksum => text()();
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();
}

class HomeMatchView {
  const HomeMatchView({
    required this.match,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  final MatchRow match;
  final String homeTeamName;
  final String awayTeamName;
}

class StandingsTableView {
  const StandingsTableView({
    required this.row,
    required this.teamName,
    required this.teamId,
  });

  final StandingsRowData row;
  final String teamName;
  final String teamId;
}

class TopStatsCompetitionView {
  const TopStatsCompetitionView({
    required this.competitionId,
    required this.competitionName,
  });

  final String competitionId;
  final String competitionName;
}

class TopStatCategoryView {
  const TopStatCategoryView({required this.statType, required this.entryCount});

  final String statType;
  final int entryCount;
}

class TopPlayerLeaderboardEntryView {
  const TopPlayerLeaderboardEntryView({
    required this.stat,
    required this.teamName,
  });

  final TopPlayerStatRow stat;
  final String? teamName;
}

class MatchDetailView {
  const MatchDetailView({
    required this.match,
    required this.competitionName,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  final MatchRow match;
  final String competitionName;
  final String homeTeamName;
  final String awayTeamName;
}

class MatchEventView {
  const MatchEventView({required this.event, required this.teamName});

  final MatchEventRow event;
  final String? teamName;
}

class MatchTeamStatComparison {
  const MatchTeamStatComparison({
    required this.statKey,
    required this.homeValue,
    required this.awayValue,
  });

  final String statKey;
  final double homeValue;
  final double awayValue;
}

@DriftDatabase(
  tables: [
    Competitions,
    Teams,
    Players,
    Matches,
    MatchEvents,
    MatchTeamStats,
    TopPlayerStats,
    StandingsRows,
    AssetRefs,
    ImportRuns,
    ImportFiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(matchEvents);
        await m.createTable(matchTeamStats);
      }
      if (from < 3) {
        await m.createTable(topPlayerStats);
      }
    },
  );

  Future<List<MatchRow>> readHomeMatchesByDate(DateTime dayUtc) {
    final start = DateTime.utc(dayUtc.year, dayUtc.month, dayUtc.day);
    final end = start.add(const Duration(days: 1));
    return (select(matches)
          ..where((tbl) => tbl.kickoffUtc.isBiggerOrEqualValue(start))
          ..where((tbl) => tbl.kickoffUtc.isSmallerThanValue(end))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.kickoffUtc)]))
        .get();
  }

  Future<List<StandingsRowData>> readStandingsForCompetition(
    String competitionId,
  ) {
    return (select(standingsRows)
          ..where((tbl) => tbl.competitionId.equals(competitionId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.position)]))
        .get();
  }

  Future<List<CompetitionRow>> readCompetitionsSorted() {
    return (select(competitions)..orderBy([
      (tbl) => OrderingTerm.asc(tbl.displayOrder),
      (tbl) => OrderingTerm.asc(tbl.name),
    ])).get();
  }

  Future<bool> hasBootstrapData() async {
    final competitionCountExpression = competitions.id.count();
    final competitionQuery = selectOnly(competitions)
      ..addColumns([competitionCountExpression]);
    final competitionCount =
        await competitionQuery.map((row) {
          return row.read(competitionCountExpression) ?? 0;
        }).getSingle();

    if (competitionCount > 0) {
      return true;
    }

    final matchCountExpression = matches.id.count();
    final matchQuery = selectOnly(matches)..addColumns([matchCountExpression]);
    final matchCount =
        await matchQuery.map((row) {
          return row.read(matchCountExpression) ?? 0;
        }).getSingle();

    return matchCount > 0;
  }

  Future<List<TeamRow>> readTeamsSorted({int? limit}) {
    final query = (select(teams)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]));
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  Future<List<PlayerRow>> readPlayersSorted({int? limit}) {
    final query = (select(players)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]));
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  Future<Map<String, CompetitionRow>> readCompetitionMapByIds(
    Iterable<String> ids,
  ) async {
    final uniqueIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) {
      return const {};
    }

    final rows =
        await (select(competitions)..where(
          (tbl) => tbl.id.isIn(uniqueIds.toList(growable: false)),
        )).get();

    return {for (final row in rows) row.id: row};
  }

  Future<TeamRow?> readTeamById(String teamId) {
    return (select(teams)
      ..where((tbl) => tbl.id.equals(teamId))).getSingleOrNull();
  }

  Future<CompetitionRow?> readCompetitionById(String competitionId) {
    return (select(competitions)
      ..where((tbl) => tbl.id.equals(competitionId))).getSingleOrNull();
  }

  Future<PlayerRow?> readPlayerById(String playerId) {
    return (select(players)
      ..where((tbl) => tbl.id.equals(playerId))).getSingleOrNull();
  }

  Future<List<PlayerRow>> readPlayersByTeam(String teamId) {
    return (select(players)
          ..where((tbl) => tbl.teamId.equals(teamId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Future<List<HomeMatchView>> readTeamMatches(
    String teamId, {
    int limit = 20,
  }) async {
    final homeTeam = alias(teams, 'team_matches_home_team');
    final awayTeam = alias(teams, 'team_matches_away_team');

    final query =
        select(matches).join([
            leftOuterJoin(homeTeam, homeTeam.id.equalsExp(matches.homeTeamId)),
            leftOuterJoin(awayTeam, awayTeam.id.equalsExp(matches.awayTeamId)),
          ])
          ..where(
            matches.homeTeamId.equals(teamId) |
                matches.awayTeamId.equals(teamId),
          )
          ..orderBy([OrderingTerm.desc(matches.kickoffUtc)])
          ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (row) => HomeMatchView(
            match: row.readTable(matches),
            homeTeamName: row.readTableOrNull(homeTeam)?.name ?? 'Unknown Team',
            awayTeamName: row.readTableOrNull(awayTeam)?.name ?? 'Unknown Team',
          ),
        )
        .toList();
  }

  Future<List<MatchEventView>> readMatchEventsByMatchId(String matchId) async {
    final teamAlias = alias(teams, 'match_event_team');
    final query =
        select(matchEvents).join([
            leftOuterJoin(
              teamAlias,
              teamAlias.id.equalsExp(matchEvents.teamId),
            ),
          ])
          ..where(matchEvents.matchId.equals(matchId))
          ..orderBy([
            OrderingTerm.desc(matchEvents.minute),
            OrderingTerm.desc(matchEvents.id),
          ]);

    final rows = await query.get();
    return rows
        .map(
          (row) => MatchEventView(
            event: row.readTable(matchEvents),
            teamName: row.readTableOrNull(teamAlias)?.name,
          ),
        )
        .toList();
  }

  Future<List<MatchTeamStatComparison>> readMatchStatComparisons(
    String matchId,
  ) async {
    final match =
        await (select(matches)
          ..where((tbl) => tbl.id.equals(matchId))).getSingleOrNull();
    if (match == null) {
      return const [];
    }

    final stats =
        await (select(matchTeamStats)
          ..where((tbl) => tbl.matchId.equals(matchId))).get();

    final homeByKey = <String, double>{};
    final awayByKey = <String, double>{};

    for (final stat in stats) {
      if (stat.teamId == match.homeTeamId) {
        homeByKey[stat.statKey] = stat.statValue;
      } else if (stat.teamId == match.awayTeamId) {
        awayByKey[stat.statKey] = stat.statValue;
      }
    }

    final allKeys = {...homeByKey.keys, ...awayByKey.keys}.toList()..sort();

    return allKeys
        .map(
          (key) => MatchTeamStatComparison(
            statKey: key,
            homeValue: homeByKey[key] ?? 0,
            awayValue: awayByKey[key] ?? 0,
          ),
        )
        .toList();
  }

  Future<MatchDetailView?> readMatchDetailById(String matchId) async {
    final competitionAlias = alias(competitions, 'match_detail_competition');
    final homeTeamAlias = alias(teams, 'match_detail_home_team');
    final awayTeamAlias = alias(teams, 'match_detail_away_team');

    final query = select(matches).join([
      leftOuterJoin(
        competitionAlias,
        competitionAlias.id.equalsExp(matches.competitionId),
      ),
      leftOuterJoin(
        homeTeamAlias,
        homeTeamAlias.id.equalsExp(matches.homeTeamId),
      ),
      leftOuterJoin(
        awayTeamAlias,
        awayTeamAlias.id.equalsExp(matches.awayTeamId),
      ),
    ])..where(matches.id.equals(matchId));

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    return MatchDetailView(
      match: row.readTable(matches),
      competitionName:
          row.readTableOrNull(competitionAlias)?.name ?? 'Unknown Competition',
      homeTeamName: row.readTableOrNull(homeTeamAlias)?.name ?? 'Unknown Team',
      awayTeamName: row.readTableOrNull(awayTeamAlias)?.name ?? 'Unknown Team',
    );
  }

  Future<List<TeamRow>> searchTeamsByName(String query, {int limit = 12}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return Future.value(const []);
    }

    return (select(teams)
          ..where((tbl) => tbl.name.lower().like('%$normalized%'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
          ..limit(limit))
        .get();
  }

  Future<List<PlayerRow>> searchPlayersByName(String query, {int limit = 12}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return Future.value(const []);
    }

    return (select(players)
          ..where((tbl) => tbl.name.lower().like('%$normalized%'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
          ..limit(limit))
        .get();
  }

  Future<List<CompetitionRow>> searchCompetitionsByName(
    String query, {
    int limit = 12,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return Future.value(const []);
    }

    return (select(competitions)
          ..where((tbl) => tbl.name.lower().like('%$normalized%'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
          ..limit(limit))
        .get();
  }

  Future<List<String>> readAllTeamIds() async {
    final rows = await select(teams).get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  Future<List<String>> readAllPlayerIds() async {
    final rows = await select(players).get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  Future<List<String>> readAllCompetitionIds() async {
    final rows = await select(competitions).get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  Future<List<TopStatsCompetitionView>> readTopStatsCompetitions() async {
    final rows =
        await customSelect('''
      SELECT DISTINCT
        t.competition_id AS competition_id,
        COALESCE(c.name, t.competition_id) AS competition_name,
        COALESCE(c.display_order, 9999) AS display_order
      FROM top_player_stats t
      LEFT JOIN competitions c ON c.id = t.competition_id
      ORDER BY display_order ASC, competition_name ASC
      ''').get();

    return rows
        .map(
          (row) => TopStatsCompetitionView(
            competitionId: row.data['competition_id'] as String,
            competitionName: row.data['competition_name'] as String,
          ),
        )
        .toList(growable: false);
  }

  Future<List<TopStatCategoryView>> readTopStatCategories(
    String competitionId,
  ) async {
    final rows =
        await customSelect(
          '''
      SELECT
        stat_type,
        COUNT(*) AS entry_count
      FROM top_player_stats
      WHERE competition_id = ?
      GROUP BY stat_type
      ORDER BY MIN(rank) ASC, stat_type ASC
      ''',
          variables: [Variable.withString(competitionId)],
        ).get();

    return rows
        .map(
          (row) => TopStatCategoryView(
            statType: row.data['stat_type'] as String,
            entryCount: row.data['entry_count'] as int,
          ),
        )
        .toList(growable: false);
  }

  Future<List<TopPlayerLeaderboardEntryView>> readTopPlayersForCategory(
    String competitionId,
    String statType, {
    int limit = 40,
  }) async {
    final teamAlias = alias(teams, 'top_stat_team');
    final query =
        select(topPlayerStats).join([
            leftOuterJoin(
              teamAlias,
              teamAlias.id.equalsExp(topPlayerStats.teamId),
            ),
          ])
          ..where(topPlayerStats.competitionId.equals(competitionId))
          ..where(topPlayerStats.statType.equals(statType))
          ..orderBy([
            OrderingTerm.asc(topPlayerStats.rank),
            OrderingTerm.desc(topPlayerStats.statValue),
            OrderingTerm.asc(topPlayerStats.playerName),
          ])
          ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (row) => TopPlayerLeaderboardEntryView(
            stat: row.readTable(topPlayerStats),
            teamName: row.readTableOrNull(teamAlias)?.name,
          ),
        )
        .toList(growable: false);
  }

  Future<List<StandingsTableView>> readStandingsTableView(
    String competitionId,
  ) async {
    final teamAlias = alias(teams, 'standings_team');
    final query =
        select(standingsRows).join([
            leftOuterJoin(
              teamAlias,
              teamAlias.id.equalsExp(standingsRows.teamId),
            ),
          ])
          ..where(standingsRows.competitionId.equals(competitionId))
          ..orderBy([OrderingTerm.asc(standingsRows.position)]);

    final rows = await query.get();
    return rows
        .map(
          (item) => StandingsTableView(
            row: item.readTable(standingsRows),
            teamName: item.readTableOrNull(teamAlias)?.name ?? 'Unknown Team',
            teamId: item.readTable(standingsRows).teamId,
          ),
        )
        .toList();
  }

  Future<List<HomeMatchView>> readHomeFeedMatches({
    required DateTime nowUtc,
    int lookBackHours = 18,
    int lookAheadDays = 2,
    int limit = 80,
  }) async {
    final start = nowUtc.subtract(Duration(hours: lookBackHours));
    final end = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
    ).add(Duration(days: lookAheadDays + 1));

    final homeTeam = alias(teams, 'home_team');
    final awayTeam = alias(teams, 'away_team');

    final query =
        select(matches).join([
            leftOuterJoin(homeTeam, homeTeam.id.equalsExp(matches.homeTeamId)),
            leftOuterJoin(awayTeam, awayTeam.id.equalsExp(matches.awayTeamId)),
          ])
          ..where(matches.kickoffUtc.isBiggerOrEqualValue(start))
          ..where(matches.kickoffUtc.isSmallerThanValue(end))
          ..orderBy([OrderingTerm.asc(matches.kickoffUtc)])
          ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (row) => HomeMatchView(
            match: row.readTable(matches),
            homeTeamName: row.readTableOrNull(homeTeam)?.name ?? 'Unknown Team',
            awayTeamName: row.readTableOrNull(awayTeam)?.name ?? 'Unknown Team',
          ),
        )
        .toList();
  }

  Future<List<HomeMatchView>> readMatchesForCompetition(
    String competitionId, {
    int limit = 160,
  }) async {
    final homeTeam = alias(teams, 'league_fixture_home_team');
    final awayTeam = alias(teams, 'league_fixture_away_team');

    final query =
        select(matches).join([
            leftOuterJoin(homeTeam, homeTeam.id.equalsExp(matches.homeTeamId)),
            leftOuterJoin(awayTeam, awayTeam.id.equalsExp(matches.awayTeamId)),
          ])
          ..where(matches.competitionId.equals(competitionId))
          ..orderBy([OrderingTerm.desc(matches.kickoffUtc)])
          ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (row) => HomeMatchView(
            match: row.readTable(matches),
            homeTeamName: row.readTableOrNull(homeTeam)?.name ?? 'Unknown Team',
            awayTeamName: row.readTableOrNull(awayTeam)?.name ?? 'Unknown Team',
          ),
        )
        .toList(growable: false);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'eri_sports.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}
