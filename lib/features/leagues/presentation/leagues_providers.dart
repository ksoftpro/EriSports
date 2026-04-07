import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/features/leagues/domain/league_ordering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final leaguesProvider = FutureProvider<List<CompetitionRow>>((ref) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  final services = ref.read(appServicesProvider);
  final competitions = await services.database.readCompetitionsSorted();
  return orderLeaguesForReference(
    ensureFeaturedInternationalLeagues(competitions),
  );
});
