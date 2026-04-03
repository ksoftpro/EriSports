import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeamDetailState {
  const TeamDetailState({
    required this.team,
    required this.competition,
    required this.matches,
    required this.players,
  });

  final TeamRow team;
  final CompetitionRow? competition;
  final List<HomeMatchView> matches;
  final List<PlayerRow> players;
}

final teamDetailProvider =
    FutureProvider.family<TeamDetailState, String>((ref, teamId) async {
  final services = ref.read(appServicesProvider);
  final team = await services.database.readTeamById(teamId);
  if (team == null) {
    throw StateError('Team not found: $teamId');
  }

  final competition = team.competitionId == null
      ? null
      : await services.database.readCompetitionById(team.competitionId!);
  final matches = await services.database.readTeamMatches(teamId);
  final players = await services.database.readPlayersByTeam(teamId);

  return TeamDetailState(
    team: team,
    competition: competition,
    matches: matches,
    players: players,
  );
});