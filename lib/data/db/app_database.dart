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
  TextColumn get competitionId => text().nullable().references(Competitions, #id)();
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

@DriftDatabase(
  tables: [
    Competitions,
    Teams,
    Players,
    Matches,
    StandingsRows,
    AssetRefs,
    ImportRuns,
    ImportFiles,
  ],
)
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

class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
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
    return (select(competitions)
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.displayOrder),
            (tbl) => OrderingTerm.asc(tbl.name),
          ]))
        .get();
  }

  Future<List<StandingsTableView>> readStandingsTableView(
    String competitionId,
  ) async {
    final teamAlias = alias(teams, 'standings_team');
    final query = select(standingsRows).join([
      leftOuterJoin(teamAlias, teamAlias.id.equalsExp(standingsRows.teamId)),
    ])
      ..where(standingsRows.competitionId.equals(competitionId))
      ..orderBy([OrderingTerm.asc(standingsRows.position)]);

    final rows = await query.get();
    return rows
        .map(
          (item) => StandingsTableView(
            row: item.readTable(standingsRows),
            teamName:
                item.readTableOrNull(teamAlias)?.name ?? 'Unknown Team',
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

    final query = select(matches).join([
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'eri_sports.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}