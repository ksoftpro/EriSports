import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/leagues/presentation/league_theme_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LeagueTableMode { short, full, form }

enum LeagueScopeMode { overall, home, away }

enum LeagueFixtureFilter { all, live, upcoming, finished }

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
  const LeagueHeaderPreference({this.isFollowing = false});

  final bool isFollowing;

  LeagueHeaderPreference copyWith({bool? isFollowing}) {
    return LeagueHeaderPreference(isFollowing: isFollowing ?? this.isFollowing);
  }
}

final leagueHeaderPreferenceProvider =
    StateProvider.family<LeagueHeaderPreference, String>(
      (ref, competitionId) => const LeagueHeaderPreference(),
    );

class LeagueTransferItem {
  const LeagueTransferItem({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.position,
    required this.updatedAtUtc,
  });

  final String playerId;
  final String playerName;
  final String? teamId;
  final String teamName;
  final String? position;
  final DateTime updatedAtUtc;
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
    required this.standings,
    required this.overallStandingsRows,
    required this.fixtureRows,
    required this.playerStatCategories,
    required this.playerStatsByType,
    required this.transferItems,
  });

  final String competitionId;
  final String competitionName;
  final String countryLabel;
  final List<String> availableSeasonLabels;
  final LeagueVisualTheme visualTheme;
  final LeagueStandingsLeague? standings;
  final List<LeagueStandingsRow> overallStandingsRows;
  final List<HomeMatchView> fixtureRows;
  final List<TopStatCategoryView> playerStatCategories;
  final Map<String, List<TopPlayerLeaderboardEntryView>> playerStatsByType;
  final List<LeagueTransferItem> transferItems;
}

@immutable
class LeagueOverviewRequest {
  const LeagueOverviewRequest({
    required this.competitionId,
    this.competitionNameHint,
  });

  final String competitionId;
  final String? competitionNameHint;

  @override
  bool operator ==(Object other) {
    return other is LeagueOverviewRequest &&
        other.competitionId == competitionId &&
        other.competitionNameHint == competitionNameHint;
  }

  @override
  int get hashCode => Object.hash(competitionId, competitionNameHint);
}

final leagueOverviewProvider = FutureProvider.family<
  LeagueOverviewState,
  LeagueOverviewRequest
>((ref, request) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.standings));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.matches));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  final services = ref.read(appServicesProvider);
  final competitionId = request.competitionId;
  final competition = await services.database.readCompetitionById(
    competitionId,
  );
  final sourceCompetitionName =
      competition?.name ?? request.competitionNameHint;
  final leagueDataset = await services.leagueStandingsSource
      .readLeagueDatasetByCompetitionId(
        competitionId,
        competitionName: sourceCompetitionName,
        allowSharedFallback: false,
      );
  final standings = leagueDataset.standings;
  final overallRows = _resolveOverallStandingsRows(standings);
  final fixtureRows = leagueDataset.fixtures;
  final playerStatCategories = leagueDataset.playerStatCategories;
  final playerStatsByType = leagueDataset.playerStatsByType;

  final competitionName =
      sourceCompetitionName ?? standings?.displayName ?? 'League';
  final country = competition?.country;
  final visualTheme = LeagueThemeResolver.resolve(
    competitionId: competitionId,
    competitionName: competitionName,
  );

  final seasonLabels = _deriveSeasonLabels(
    fixtureRows,
    explicitSeason: standings?.meta.season,
  );
  final transferItems = _buildTransferItems(
    transferFeed: leagueDataset.transferFeed,
  );

  return LeagueOverviewState(
    competitionId: competitionId,
    competitionName: competitionName,
    countryLabel: _countryLabel(country, competitionName),
    availableSeasonLabels: seasonLabels,
    visualTheme: visualTheme,
    standings: standings,
    overallStandingsRows: overallRows,
    fixtureRows: fixtureRows,
    playerStatCategories: playerStatCategories,
    playerStatsByType: playerStatsByType,
    transferItems: transferItems,
  );
});

final leaguePlayerStatCategoriesProvider = FutureProvider.family<
  List<TopStatCategoryView>,
  String
>((ref, competitionId) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
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
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  final services = ref.read(appServicesProvider);
  return services.database.readTopPlayersForCategory(
    query.competitionId,
    query.statType,
    limit: query.limit,
  );
});

List<LeagueTeamStatRow> buildTeamStatRows(
  List<LeagueStandingsRow> rows,
  LeagueTeamStatMetric metric,
) {
  final items = List<LeagueStandingsRow>.from(rows);

  switch (metric) {
    case LeagueTeamStatMetric.points:
      items.sort((a, b) => b.points.compareTo(a.points));
      break;
    case LeagueTeamStatMetric.goalsFor:
      items.sort((a, b) => b.goalsFor.compareTo(a.goalsFor));
      break;
    case LeagueTeamStatMetric.goalDiff:
      items.sort((a, b) => b.goalConDiff.compareTo(a.goalConDiff));
      break;
    case LeagueTeamStatMetric.bestDefence:
      items.sort((a, b) => a.goalsAgainst.compareTo(b.goalsAgainst));
      break;
    case LeagueTeamStatMetric.wins:
      items.sort((a, b) => b.wins.compareTo(a.wins));
      break;
    case LeagueTeamStatMetric.form:
      items.sort((a, b) => _formPoints(b.form).compareTo(_formPoints(a.form)));
      break;
  }

  return [
    for (var i = 0; i < items.length; i++)
      LeagueTeamStatRow(
        rank: i + 1,
        teamId: items[i].teamId,
        teamName: items[i].displayTeamName,
        primary: _primaryTeamMetric(items[i], metric),
        secondary: _secondaryTeamMetric(items[i], metric),
      ),
  ];
}

String _primaryTeamMetric(LeagueStandingsRow row, LeagueTeamStatMetric metric) {
  switch (metric) {
    case LeagueTeamStatMetric.points:
      return '${row.points} pts';
    case LeagueTeamStatMetric.goalsFor:
      return '${row.goalsFor} GF';
    case LeagueTeamStatMetric.goalDiff:
      final gd = row.goalConDiff;
      return gd > 0 ? '+$gd GD' : '$gd GD';
    case LeagueTeamStatMetric.bestDefence:
      return '${row.goalsAgainst} GA';
    case LeagueTeamStatMetric.wins:
      return '${row.wins} wins';
    case LeagueTeamStatMetric.form:
      return '${_formPoints(row.form)} pts';
  }
}

String _secondaryTeamMetric(
  LeagueStandingsRow row,
  LeagueTeamStatMetric metric,
) {
  switch (metric) {
    case LeagueTeamStatMetric.points:
      return 'W${row.wins} D${row.draws} L${row.losses}';
    case LeagueTeamStatMetric.goalsFor:
      return 'Matches ${row.played}';
    case LeagueTeamStatMetric.goalDiff:
      return '${row.goalsFor}:${row.goalsAgainst}';
    case LeagueTeamStatMetric.bestDefence:
      return '${row.goalConDiff > 0 ? '+' : ''}${row.goalConDiff} GD';
    case LeagueTeamStatMetric.wins:
      return '${row.points} points';
    case LeagueTeamStatMetric.form:
      return row.form ?? 'No form';
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

List<String> _deriveSeasonLabels(
  List<HomeMatchView> fixtures, {
  String? explicitSeason,
}) {
  final labels = <String>{};
  if (explicitSeason != null && explicitSeason.trim().isNotEmpty) {
    labels.add(explicitSeason.trim());
  }

  final seasons = <int>{};
  for (final fixture in fixtures) {
    final date = fixture.match.kickoffUtc;
    final seasonStartYear = date.month >= 7 ? date.year : date.year - 1;
    seasons.add(seasonStartYear);
  }

  final now = DateTime.now();
  seasons.add(now.month >= 7 ? now.year : now.year - 1);

  final ordered = seasons.toList()..sort((a, b) => b.compareTo(a));
  labels.addAll(ordered.map((year) => '$year/${year + 1}'));
  return labels.toList(growable: false);
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

List<LeagueTransferItem> _buildTransferItems({
  List<LeagueTransferFeedEntry> transferFeed = const [],
}) {
  if (transferFeed.isEmpty) {
    return const [];
  }

  final fromTransferFeed = [
    for (final item in transferFeed)
      LeagueTransferItem(
        playerId: item.playerId,
        playerName: item.playerName,
        teamId: item.teamId,
        teamName: item.teamName,
        position: item.position,
        updatedAtUtc: item.transferDateUtc,
      ),
  ]..sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));

  return fromTransferFeed;
}

List<LeagueStandingsRow> _resolveOverallStandingsRows(
  LeagueStandingsLeague? standings,
) {
  final fromAll = standings?.overallMode?.rows;
  if (fromAll != null && fromAll.isNotEmpty) {
    return fromAll;
  }

  return const [];
}
