import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _followedTeamsKey = 'followed_team_ids';
const _followedPlayersKey = 'followed_player_ids';

const List<String> _preferredPlayerNames = [
  'Bukayo Saka',
  'Martin Odegaard',
  'Declan Rice',
  'Cole Palmer',
  'Enzo Fernandez',
  'Reece James',
  'Erling Haaland',
  'Kevin De Bruyne',
  'Phil Foden',
  'Bruno Fernandes',
  'Marcus Rashford',
  'Rasmus Hojlund',
];

const Map<String, List<String>> _defaultClubMatchers = {
  'arsenal': ['arsenal'],
  'chelsea': ['chelsea'],
  'manchester_city': ['manchester city', 'man city'],
  'manchester_united': ['manchester united', 'man utd', 'man united'],
};

@immutable
class FollowingSelectionState {
  const FollowingSelectionState({
    required this.teamIds,
    required this.playerIds,
  });

  final Set<String> teamIds;
  final Set<String> playerIds;

  FollowingSelectionState copyWith({
    Set<String>? teamIds,
    Set<String>? playerIds,
  }) {
    return FollowingSelectionState(
      teamIds: teamIds ?? this.teamIds,
      playerIds: playerIds ?? this.playerIds,
    );
  }
}

class FollowingSelectionController extends Notifier<FollowingSelectionState> {
  @override
  FollowingSelectionState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final teams = prefs.getStringList(_followedTeamsKey) ?? const [];
    final players = prefs.getStringList(_followedPlayersKey) ?? const [];
    return FollowingSelectionState(
      teamIds: teams.toSet(),
      playerIds: players.toSet(),
    );
  }

  Future<void> seedDefaults({
    required List<String> defaultTeamIds,
    required List<String> defaultPlayerIds,
  }) async {
    if (state.teamIds.isNotEmpty || state.playerIds.isNotEmpty) {
      return;
    }

    final seeded = FollowingSelectionState(
      teamIds: defaultTeamIds.toSet(),
      playerIds: defaultPlayerIds.toSet(),
    );
    state = seeded;
    await _persist(seeded);
  }

  Future<void> toggleTeam(String teamId) async {
    final nextTeams = Set<String>.from(state.teamIds);
    if (!nextTeams.add(teamId)) {
      nextTeams.remove(teamId);
    }

    final next = state.copyWith(teamIds: nextTeams);
    state = next;
    await _persist(next);
  }

  Future<void> togglePlayer(String playerId) async {
    final nextPlayers = Set<String>.from(state.playerIds);
    if (!nextPlayers.add(playerId)) {
      nextPlayers.remove(playerId);
    }

    final next = state.copyWith(playerIds: nextPlayers);
    state = next;
    await _persist(next);
  }

  Future<void> _persist(FollowingSelectionState value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(
      _followedTeamsKey,
      value.teamIds.toList(growable: false),
    );
    await prefs.setStringList(
      _followedPlayersKey,
      value.playerIds.toList(growable: false),
    );
  }
}

final followingSelectionProvider =
    NotifierProvider<FollowingSelectionController, FollowingSelectionState>(
      FollowingSelectionController.new,
    );

class FollowedTeamCardData {
  const FollowedTeamCardData({
    required this.team,
    required this.competitionName,
    required this.nextMatch,
    required this.nextOpponentName,
  });

  final TeamRow team;
  final String? competitionName;
  final HomeMatchView? nextMatch;
  final String? nextOpponentName;
}

class FollowedPlayerCardData {
  const FollowedPlayerCardData({required this.player, required this.team});

  final PlayerRow player;
  final TeamRow? team;
}

class FollowingDashboardState {
  const FollowingDashboardState({
    required this.teams,
    required this.players,
    required this.availableTeams,
    required this.availablePlayers,
    required this.competitionNameByTeamId,
    required this.teamNameById,
  });

  final List<FollowedTeamCardData> teams;
  final List<FollowedPlayerCardData> players;
  final List<TeamRow> availableTeams;
  final List<PlayerRow> availablePlayers;
  final Map<String, String> competitionNameByTeamId;
  final Map<String, String> teamNameById;
}

final followingDashboardProvider = FutureProvider<FollowingDashboardState>((
  ref,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.matches));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  final services = ref.read(appServicesProvider);

  final availableTeams = await services.database.readTeamsSorted();
  final availablePlayers = await services.database.readPlayersSorted();

  final competitionById = await services.database.readCompetitionMapByIds(
    availableTeams
        .map((team) => team.competitionId)
        .whereType<String>()
        .toSet(),
  );

  final competitionNameByTeamId = <String, String>{
    for (final team in availableTeams)
      if (team.competitionId != null)
        team.id:
            competitionById[team.competitionId!]?.name ??
            (team.competitionId ?? 'Competition'),
  };

  final teamNameById = <String, String>{
    for (final team in availableTeams) team.id: team.name,
  };

  final defaultTeamIds = _resolveDefaultTeamIds(availableTeams);
  final defaultPlayerIds = _resolveDefaultPlayerIds(
    players: availablePlayers,
    defaultTeamIds: defaultTeamIds,
  );

  ref.watch(followingSelectionProvider);

  await ref
      .read(followingSelectionProvider.notifier)
      .seedDefaults(
        defaultTeamIds: defaultTeamIds,
        defaultPlayerIds: defaultPlayerIds,
      );

  final latestSelection = ref.read(followingSelectionProvider);
  final teamsById = <String, TeamRow>{
    for (final team in availableTeams) team.id: team,
  };
  final playersById = <String, PlayerRow>{
    for (final player in availablePlayers) player.id: player,
  };

  final followedTeams = <FollowedTeamCardData>[];
  for (final teamId in latestSelection.teamIds) {
    final team = teamsById[teamId] ?? await services.database.readTeamById(teamId);
    if (team == null) {
      continue;
    }

    final matches = await services.database.readTeamMatches(teamId, limit: 30);
    final now = DateTime.now().toUtc();
    HomeMatchView? next;
    String? opponent;

    for (final match in matches) {
      final isUpcoming = match.match.kickoffUtc.isAfter(now);
      if (!isUpcoming) {
        continue;
      }

      next = match;
      opponent =
          match.match.homeTeamId == teamId
              ? match.awayTeamName
              : match.homeTeamName;
      break;
    }

    followedTeams.add(
      FollowedTeamCardData(
        team: team,
        competitionName: competitionNameByTeamId[team.id],
        nextMatch: next,
        nextOpponentName: opponent,
      ),
    );
  }

  final followedPlayers = <FollowedPlayerCardData>[];
  for (final playerId in latestSelection.playerIds) {
    final player =
        playersById[playerId] ?? await services.database.readPlayerById(playerId);
    if (player == null) {
      continue;
    }

    final team = player.teamId == null ? null : teamsById[player.teamId!];
    followedPlayers.add(FollowedPlayerCardData(player: player, team: team));
  }

  return FollowingDashboardState(
    teams: followedTeams,
    players: followedPlayers,
    availableTeams: availableTeams,
    availablePlayers: availablePlayers,
    competitionNameByTeamId: competitionNameByTeamId,
    teamNameById: teamNameById,
  );
});

List<String> _resolveDefaultTeamIds(List<TeamRow> teams) {
  final selected = <String>[];

  for (final matcherSet in _defaultClubMatchers.values) {
    TeamRow? match;
    for (final team in teams) {
      final normalizedTeamName = _normalizeSearchKey(team.name);
      if (matcherSet.any(normalizedTeamName.contains)) {
        match = team;
        break;
      }
    }

    if (match != null && !selected.contains(match.id)) {
      selected.add(match.id);
    }
  }

  if (selected.isEmpty) {
    return teams.take(4).map((team) => team.id).toList(growable: false);
  }

  return selected;
}

List<String> _resolveDefaultPlayerIds({
  required List<PlayerRow> players,
  required List<String> defaultTeamIds,
}) {
  final eligiblePlayers = players
      .where(
        (player) =>
            player.teamId != null && defaultTeamIds.contains(player.teamId),
      )
      .toList(growable: false);

  if (eligiblePlayers.isEmpty) {
    return players.take(8).map((player) => player.id).toList(growable: false);
  }

  final selected = <String>[];
  final selectedSet = <String>{};

  for (final preferredName in _preferredPlayerNames) {
    final normalizedPreferred = _normalizeSearchKey(preferredName);
    for (final player in eligiblePlayers) {
      if (selectedSet.contains(player.id)) {
        continue;
      }

      final normalizedPlayerName = _normalizeSearchKey(player.name);
      if (normalizedPlayerName == normalizedPreferred ||
          normalizedPlayerName.contains(normalizedPreferred) ||
          normalizedPreferred.contains(normalizedPlayerName)) {
        selected.add(player.id);
        selectedSet.add(player.id);
        break;
      }
    }
  }

  for (final player in eligiblePlayers) {
    if (selected.length >= 10) {
      break;
    }
    if (selectedSet.add(player.id)) {
      selected.add(player.id);
    }
  }

  return selected;
}

String _normalizeSearchKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
