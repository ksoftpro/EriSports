import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/bootstrap/startup_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchCenterState {
  const MatchCenterState({
    required this.detail,
    required this.events,
    required this.stats,
  });

  final MatchDetailView detail;
  final List<MatchEventView> events;
  final List<MatchTeamStatComparison> stats;
}

final matchDetailProvider = FutureProvider.family<MatchCenterState, String>((
  ref,
  matchId,
) async {
  ref.watch(dataRefreshTokenProvider);
  final services = ref.read(appServicesProvider);
  final detail = await services.database.readMatchDetailById(matchId);
  if (detail == null) {
    throw StateError('Match not found: $matchId');
  }

  final events = await services.database.readMatchEventsByMatchId(matchId);
  final stats = await services.database.readMatchStatComparisons(matchId);

  return MatchCenterState(detail: detail, events: events, stats: stats);
});
