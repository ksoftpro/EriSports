import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/presentation/league_theme_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LeagueTableMode { short, full, form }

enum LeagueScopeMode { overall, home, away }

enum LeagueFixtureFilter { all, live, upcoming, finished }

enum LeagueNewsFilter { all, updates, insights }

enum LeagueTeamStatMetric {
  points,
  goalsFor,
  goalDiff,
  bestDefence,
  wins,
  form,
}

@immutable
class LeagueHeaderPreference {
  const LeagueHeaderPreference({
    this.isFollowing = false,
    this.notificationsOn = false,
  });

  final bool isFollowing;
  final bool notificationsOn;

  LeagueHeaderPreference copyWith({bool? isFollowing, bool? notificationsOn}) {
    return LeagueHeaderPreference(
      isFollowing: isFollowing ?? this.isFollowing,
      notificationsOn: notificationsOn ?? this.notificationsOn,
    );
  }
}

final leagueHeaderPreferenceProvider =
    StateProvider.family<LeagueHeaderPreference, String>(
      (ref, competitionId) => const LeagueHeaderPreference(),
    );

class LeagueNewsItem {
  const LeagueNewsItem({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.source,
    required this.publishedAtUtc,
    required this.isInsight,
    this.matchId,
  });

  final String id;
  final String title;
  final String excerpt;
  final String source;
  final DateTime publishedAtUtc;
  final bool isInsight;
  final String? matchId;
}

class LeagueTeamStatRow {
  const LeagueTeamStatRow({
    required this.rank,
    required this.teamId,
    required this.teamName,
    required this.primary,
    required this.secondary,
  });

  final int rank;
  final String teamId;
  final String teamName;
  final String primary;
  final String secondary;
}

class LeagueOverviewState {
  const LeagueOverviewState({
    required this.competitionId,
    required this.competitionName,
    required this.countryLabel,
    required this.availableSeasonLabels,
    required this.visualTheme,
    required this.standingsRows,
    required this.fixtureRows,
    required this.newsItems,
  });

  final String competitionId;
  final String competitionName;
  final String countryLabel;
  final List<String> availableSeasonLabels;
  final LeagueVisualTheme visualTheme;
  final List<StandingsTableView> standingsRows;
  final List<HomeMatchView> fixtureRows;
  final List<LeagueNewsItem> newsItems;
}

final leagueOverviewProvider =
    FutureProvider.family<LeagueOverviewState, String>((
      ref,
      competitionId,
    ) async {
      final services = ref.read(appServicesProvider);
      final competition = await services.database.readCompetitionById(
        competitionId,
      );
      final standingsRows = await services.database.readStandingsTableView(
        competitionId,
      );
      final fixtureRows = await services.database.readMatchesForCompetition(
        competitionId,
        limit: 240,
      );
      final goalLeaders = await services.database.readTopPlayersForCategory(
        competitionId,
        'goals',
        limit: 3,
      );

      final competitionName = competition?.name ?? 'League';
      final country = competition?.country;
      final visualTheme = LeagueThemeResolver.resolve(
        competitionId: competitionId,
        competitionName: competitionName,
      );

      final seasonLabels = _deriveSeasonLabels(fixtureRows);
      final newsItems = _buildLeagueNews(
        competitionName: competitionName,
        standingsRows: standingsRows,
        fixtures: fixtureRows,
        goalLeaders: goalLeaders,
      );

      return LeagueOverviewState(
        competitionId: competitionId,
        competitionName: competitionName,
        countryLabel: _countryLabel(country, competitionName),
        availableSeasonLabels: seasonLabels,
        visualTheme: visualTheme,
        standingsRows: standingsRows,
        fixtureRows: fixtureRows,
        newsItems: newsItems,
      );
    });

final leaguePlayerStatCategoriesProvider =
    FutureProvider.family<List<TopStatCategoryView>, String>((
      ref,
      competitionId,
    ) async {
      final services = ref.read(appServicesProvider);
      return services.database.readTopStatCategories(competitionId);
    });

@immutable
class LeaguePlayerLeadersQuery {
  const LeaguePlayerLeadersQuery({
    required this.competitionId,
    required this.statType,
    this.limit = 30,
  });

  final String competitionId;
  final String statType;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is LeaguePlayerLeadersQuery &&
        other.competitionId == competitionId &&
        other.statType == statType &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(competitionId, statType, limit);
}

final leaguePlayerLeadersProvider = FutureProvider.family<
  List<TopPlayerLeaderboardEntryView>,
  LeaguePlayerLeadersQuery
>((ref, query) async {
  final services = ref.read(appServicesProvider);
  return services.database.readTopPlayersForCategory(
    query.competitionId,
    query.statType,
    limit: query.limit,
  );
});

List<LeagueTeamStatRow> buildTeamStatRows(
  List<StandingsTableView> rows,
  LeagueTeamStatMetric metric,
) {
  final items = List<StandingsTableView>.from(rows);

  switch (metric) {
    case LeagueTeamStatMetric.points:
      items.sort((a, b) => b.row.points.compareTo(a.row.points));
      break;
    case LeagueTeamStatMetric.goalsFor:
      items.sort((a, b) => b.row.goalsFor.compareTo(a.row.goalsFor));
      break;
    case LeagueTeamStatMetric.goalDiff:
      items.sort((a, b) => b.row.goalDiff.compareTo(a.row.goalDiff));
      break;
    case LeagueTeamStatMetric.bestDefence:
      items.sort((a, b) => a.row.goalsAgainst.compareTo(b.row.goalsAgainst));
      break;
    case LeagueTeamStatMetric.wins:
      items.sort((a, b) => b.row.won.compareTo(a.row.won));
      break;
    case LeagueTeamStatMetric.form:
      items.sort(
        (a, b) => _formPoints(b.row.form).compareTo(_formPoints(a.row.form)),
      );
      break;
  }

  return [
    for (var i = 0; i < items.length; i++)
      LeagueTeamStatRow(
        rank: i + 1,
        teamId: items[i].teamId,
        teamName: items[i].teamName,
        primary: _primaryTeamMetric(items[i], metric),
        secondary: _secondaryTeamMetric(items[i], metric),
      ),
  ];
}

String _primaryTeamMetric(StandingsTableView row, LeagueTeamStatMetric metric) {
  switch (metric) {
    case LeagueTeamStatMetric.points:
      return '${row.row.points} pts';
    case LeagueTeamStatMetric.goalsFor:
      return '${row.row.goalsFor} GF';
    case LeagueTeamStatMetric.goalDiff:
      final gd = row.row.goalDiff;
      return gd > 0 ? '+$gd GD' : '$gd GD';
    case LeagueTeamStatMetric.bestDefence:
      return '${row.row.goalsAgainst} GA';
    case LeagueTeamStatMetric.wins:
      return '${row.row.won} wins';
    case LeagueTeamStatMetric.form:
      return '${_formPoints(row.row.form)} pts';
  }
}

String _secondaryTeamMetric(
  StandingsTableView row,
  LeagueTeamStatMetric metric,
) {
  switch (metric) {
    case LeagueTeamStatMetric.points:
      return 'W${row.row.won} D${row.row.draw} L${row.row.lost}';
    case LeagueTeamStatMetric.goalsFor:
      return 'Matches ${row.row.played}';
    case LeagueTeamStatMetric.goalDiff:
      return '${row.row.goalsFor}:${row.row.goalsAgainst}';
    case LeagueTeamStatMetric.bestDefence:
      return '${row.row.goalDiff > 0 ? '+' : ''}${row.row.goalDiff} GD';
    case LeagueTeamStatMetric.wins:
      return '${row.row.points} points';
    case LeagueTeamStatMetric.form:
      return row.row.form ?? 'No form';
  }
}

String _countryLabel(String? country, String competitionName) {
  if (country != null && country.trim().isNotEmpty) {
    return country.trim();
  }

  final normalized = competitionName.toLowerCase();
  if (normalized.contains('premier')) {
    return 'England';
  }
  if (normalized.contains('laliga') || normalized.contains('la liga')) {
    return 'Spain';
  }
  if (normalized.contains('bundesliga')) {
    return 'Germany';
  }
  if (normalized.contains('serie a')) {
    return 'Italy';
  }
  if (normalized.contains('ligue')) {
    return 'France';
  }

  return 'Competition';
}

List<String> _deriveSeasonLabels(List<HomeMatchView> fixtures) {
  final seasons = <int>{};
  for (final fixture in fixtures) {
    final date = fixture.match.kickoffUtc;
    final seasonStartYear = date.month >= 7 ? date.year : date.year - 1;
    seasons.add(seasonStartYear);
  }

  final now = DateTime.now();
  seasons.add(now.month >= 7 ? now.year : now.year - 1);

  final ordered = seasons.toList()..sort((a, b) => b.compareTo(a));
  return ordered.map((year) => '$year/${year + 1}').toList(growable: false);
}

int _formPoints(String? form) {
  if (form == null || form.trim().isEmpty) {
    return 0;
  }

  var points = 0;
  final tokens = form.toUpperCase().replaceAll(RegExp('[^WDL]'), '');
  for (final rune in tokens.runes) {
    final char = String.fromCharCode(rune);
    if (char == 'W') {
      points += 3;
    } else if (char == 'D') {
      points += 1;
    }
  }
  return points;
}

List<LeagueNewsItem> _buildLeagueNews({
  required String competitionName,
  required List<StandingsTableView> standingsRows,
  required List<HomeMatchView> fixtures,
  required List<TopPlayerLeaderboardEntryView> goalLeaders,
}) {
  final items = <LeagueNewsItem>[];
  final now = DateTime.now().toUtc();

  if (standingsRows.isNotEmpty) {
    final top = standingsRows.first;
    items.add(
      LeagueNewsItem(
        id: 'table-top-${top.teamId}',
        title: '${top.teamName} lead the $competitionName table',
        excerpt:
            '${top.teamName} are on ${top.row.points} points after ${top.row.played} matches.',
        source: 'Offline Desk',
        publishedAtUtc: now,
        isInsight: true,
      ),
    );
  }

  if (goalLeaders.isNotEmpty) {
    final scorer = goalLeaders.first;
    items.add(
      LeagueNewsItem(
        id: 'goal-leader-${scorer.stat.playerId}',
        title: '${scorer.stat.playerName} tops the scoring chart',
        excerpt:
            'The ${competitionName.toLowerCase()} race is led with ${scorer.stat.statValue.toInt()} goals.',
        source: 'Stats Hub',
        publishedAtUtc: now.subtract(const Duration(hours: 2)),
        isInsight: true,
      ),
    );
  }

  final recent =
      fixtures
          .where((fixture) => fixture.match.kickoffUtc.isBefore(now))
          .toList()
        ..sort((a, b) => b.match.kickoffUtc.compareTo(a.match.kickoffUtc));

  for (final match in recent.take(4)) {
    items.add(
      LeagueNewsItem(
        id: 'result-${match.match.id}',
        title:
            '${match.homeTeamName} ${match.match.homeScore}-${match.match.awayScore} ${match.awayTeamName}',
        excerpt: 'Full-time result in the $competitionName.',
        source: 'Match Centre',
        publishedAtUtc: match.match.kickoffUtc,
        isInsight: false,
        matchId: match.match.id,
      ),
    );
  }

  final upcoming =
      fixtures
          .where((fixture) => fixture.match.kickoffUtc.isAfter(now))
          .toList()
        ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

  for (final match in upcoming.take(4)) {
    items.add(
      LeagueNewsItem(
        id: 'preview-${match.match.id}',
        title: '${match.homeTeamName} vs ${match.awayTeamName} preview',
        excerpt: 'Upcoming fixture coverage and match centre access.',
        source: 'Match Centre',
        publishedAtUtc: match.match.kickoffUtc.subtract(
          const Duration(hours: 4),
        ),
        isInsight: false,
        matchId: match.match.id,
      ),
    );
  }

  items.sort((a, b) => b.publishedAtUtc.compareTo(a.publishedAtUtc));
  return items;
}
