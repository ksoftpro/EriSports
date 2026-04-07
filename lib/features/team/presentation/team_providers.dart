import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/features/team/data/team_raw_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class TeamColorPalette {
  const TeamColorPalette({
    this.darkMode,
    this.lightMode,
    this.fontDarkMode,
    this.fontLightMode,
  });

  final String? darkMode;
  final String? lightMode;
  final String? fontDarkMode;
  final String? fontLightMode;
}

class TeamDetailState {
  const TeamDetailState({
    required this.team,
    required this.competition,
    required this.matches,
    required this.players,
    required this.rawTeam,
    required this.rawDetails,
    required this.rawTabs,
    required this.availableSeasonLabels,
    required this.teamColors,
  });

  final TeamRow team;
  final CompetitionRow? competition;
  final List<HomeMatchView> matches;
  final List<PlayerRow> players;
  final Map<String, dynamic>? rawTeam;
  final Map<String, dynamic>? rawDetails;
  final List<String> rawTabs;
  final List<String> availableSeasonLabels;
  final TeamColorPalette? teamColors;
}

final teamHeaderFollowingProvider = StateProvider.family<bool, String>(
  (ref, _) => false,
);

final teamDetailProvider = FutureProvider.family<TeamDetailState, String>((
  ref,
  teamId,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.matches));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  final services = ref.read(appServicesProvider);
  final team = await services.database.readTeamById(teamId);
  if (team == null) {
    throw StateError('Team not found: $teamId');
  }

  final competition =
      team.competitionId == null
          ? null
          : await services.database.readCompetitionById(team.competitionId!);
  final matches = await services.database.readTeamMatches(teamId);
  final players = await services.database.readPlayersByTeam(teamId);
  final rawEntry = await services.teamRawSource.readTeamById(teamId);

  final rawTeam = rawEntry?.raw;
  final rawDetails = _asMap(rawTeam?['details']);
  final rawTabs = _stringList(rawTeam?['tabs'])
      .map(_normalizeTabKey)
      .where((key) => key.isNotEmpty)
      .toList(growable: false);
  final seasons = _deriveSeasonLabels(rawTeam, rawDetails, matches);
  final teamColors = _extractTeamColors(rawTeam);

  return TeamDetailState(
    team: team,
    competition: competition,
    matches: matches,
    players: players,
    rawTeam: rawTeam,
    rawDetails: rawDetails,
    rawTabs: rawTabs,
    availableSeasonLabels: seasons,
    teamColors: teamColors,
  );
});

TeamColorPalette? _extractTeamColors(Map<String, dynamic>? rawTeam) {
  if (rawTeam == null) {
    return null;
  }

  final candidates = <Map<String, dynamic>>[];

  void addCandidate(Map<String, dynamic>? value) {
    if (value != null && value.isNotEmpty) {
      candidates.add(value);
    }
  }

  addCandidate(_asMap(rawTeam['teamColors']));

  final squad = _asMap(rawTeam['squad']);
  addCandidate(_asMap(squad?['teamColors']));

  final overview = _asMap(rawTeam['overview']);
  addCandidate(_asMap(overview?['teamColors']));

  final topPlayers =
      _asMap(overview?['topPlayers']) ?? _asMap(rawTeam['topPlayers']);
  for (final key in const ['byGoals', 'byAssists', 'byRating']) {
    final category = _asMap(topPlayers?[key]);
    final players = _asList(category?['players']);
    if (players.isEmpty) {
      continue;
    }
    addCandidate(_asMap(_asMap(players.first)?['teamColors']));
  }

  final history = _asMap(rawTeam['history']);
  final historyMap = _asMap(history?['teamColorMap']);
  if (historyMap != null) {
    addCandidate({
      'lightMode': _stringValue(historyMap['color']),
      'darkMode':
          _stringValue(historyMap['colorAlternate']) ??
          _stringValue(historyMap['color']),
      'fontLightMode': null,
      'fontDarkMode': null,
    });
  }

  for (final candidate in candidates) {
    final darkMode = _stringValue(candidate['darkMode']);
    final lightMode = _stringValue(candidate['lightMode']);
    if (darkMode == null && lightMode == null) {
      continue;
    }

    return TeamColorPalette(
      darkMode: darkMode,
      lightMode: lightMode,
      fontDarkMode: _stringValue(candidate['fontDarkMode']),
      fontLightMode: _stringValue(candidate['fontLightMode']),
    );
  }

  return null;
}

List<String> _deriveSeasonLabels(
  Map<String, dynamic>? rawTeam,
  Map<String, dynamic>? rawDetails,
  List<HomeMatchView> matches,
) {
  final labels = <String>{};

  labels.addAll(_stringList(rawTeam?['allAvailableSeasons']));

  final latestSeason = _stringValue(rawDetails?['latestSeason']);
  if (latestSeason != null) {
    labels.add(latestSeason);
  }

  final overview = _asMap(rawTeam?['overview']);
  final overviewSeason = _stringValue(overview?['season']);
  if (overviewSeason != null) {
    labels.add(overviewSeason);
  }

  final history = _asMap(rawTeam?['history']);
  final tables = _asMap(history?['tables']);
  for (final phase in const ['current', 'historic']) {
    final entries = _asList(tables?[phase]);
    for (final entry in entries) {
      final links = _asList(_asMap(entry)?['link']);
      for (final link in links) {
        final seasonValues = _asList(_asMap(link)?['season']);
        for (final season in seasonValues) {
          final label = _stringValue(season);
          if (label != null) {
            labels.add(label);
          }
        }
      }
    }
  }

  for (final item in matches) {
    final kickoff = item.match.kickoffUtc;
    final startYear = kickoff.month >= 7 ? kickoff.year : kickoff.year - 1;
    labels.add('$startYear/${startYear + 1}');
  }

  final sorted = labels.toList(growable: false)
    ..sort((a, b) {
      final aYear = int.tryParse(a.split('/').first) ?? 0;
      final bYear = int.tryParse(b.split('/').first) ?? 0;
      if (aYear != bYear) {
        return bYear.compareTo(aYear);
      }
      return b.compareTo(a);
    });

  return sorted;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries) '${entry.key}': entry.value,
    };
  }
  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const [];
}

List<String> _stringList(dynamic value) {
  final list = _asList(value);
  return [
    for (final item in list)
      if (_stringValue(item) case final text?) text,
  ];
}

String? _stringValue(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) {
    return value.toString();
  }
  return null;
}

String _normalizeTabKey(String value) => value.trim().toLowerCase();
