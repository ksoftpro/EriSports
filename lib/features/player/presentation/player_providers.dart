import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerDetailState {
  const PlayerDetailState({required this.player, required this.team});

  final PlayerRow player;
  final TeamRow? team;
}

final playerDetailProvider = FutureProvider.family<PlayerDetailState, String>((
  ref,
  playerId,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  final services = ref.read(appServicesProvider);
  final player = await services.database.readPlayerById(playerId);
  if (player == null) {
    throw StateError('Player not found: $playerId');
  }

  final team =
      player.teamId == null
          ? null
          : await services.database.readTeamById(player.teamId!);

  return PlayerDetailState(player: player, team: team);
});
