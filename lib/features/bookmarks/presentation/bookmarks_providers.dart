import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _followedTeamsKey = 'followed_team_ids';
const _followedPlayersKey = 'followed_player_ids';

@immutable
class FollowingSelectionState {
  const FollowingSelectionState({required this.teamIds, required this.playerIds});

  final Set<String> teamIds;
  final Set<String> playerIds;

  FollowingSelectionState copyWith({Set<String>? teamIds, Set<String>? playerIds}) {
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
  const FollowedPlayerCardData({
    required this.player,
    required this.team,
  });

  final PlayerRow player;
  final TeamRow? team;
}

class FollowingDashboardState {
  const FollowingDashboardState({
    required this.teams,
    required this.players,
    required this.availableTeams,
    required this.availablePlayers,
  });

  final List<FollowedTeamCardData> teams;
  final List<FollowedPlayerCardData> players;
  final List<TeamRow> availableTeams;
  final List<PlayerRow> availablePlayers;
}

final followingDashboardProvider = FutureProvider<FollowingDashboardState>((ref) async {
  final services = ref.read(appServicesProvider);

  final availableTeams = await services.database.readTeamsSorted(limit: 40);
  final availablePlayers = await services.database.readPlayersSorted(limit: 60);

  ref.watch(followingSelectionProvider);

  await ref
      .read(followingSelectionProvider.notifier)
      .seedDefaults(
        defaultTeamIds: availableTeams.take(8).map((t) => t.id).toList(growable: false),
        defaultPlayerIds:
            availablePlayers.take(8).map((p) => p.id).toList(growable: false),
      );

  final latestSelection = ref.read(followingSelectionProvider);

  final followedTeams = <FollowedTeamCardData>[];
  for (final teamId in latestSelection.teamIds) {
    final team = await services.database.readTeamById(teamId);
    if (team == null) {
      continue;
    }

    final competition = team.competitionId == null
        ? null
        : await services.database.readCompetitionById(team.competitionId!);
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
      opponent = match.match.homeTeamId == teamId
          ? match.awayTeamName
          : match.homeTeamName;
      break;
    }

    followedTeams.add(
      FollowedTeamCardData(
        team: team,
        competitionName: competition?.name,
        nextMatch: next,
        nextOpponentName: opponent,
      ),
    );
  }

  final followedPlayers = <FollowedPlayerCardData>[];
  for (final playerId in latestSelection.playerIds) {
    final player = await services.database.readPlayerById(playerId);
    if (player == null) {
      continue;
    }

    final team = player.teamId == null
        ? null
        : await services.database.readTeamById(player.teamId!);
    followedPlayers.add(FollowedPlayerCardData(player: player, team: team));
  }

  return FollowingDashboardState(
    teams: followedTeams,
    players: followedPlayers,
    availableTeams: availableTeams,
    availablePlayers: availablePlayers,
  );
});
