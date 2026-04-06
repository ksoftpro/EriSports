import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StandingsState {
  const StandingsState({
    required this.competitionId,
    required this.competitionName,
    required this.rows,
  });

  final String competitionId;
  final String competitionName;
  final List<StandingsTableView> rows;
}

final standingsProvider = FutureProvider.family<StandingsState, String>((
  ref,
  competitionId,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.standings));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  final services = ref.read(appServicesProvider);

  final competitions = await services.database.readCompetitionsSorted();
  CompetitionRow? competition;
  for (final row in competitions) {
    if (row.id == competitionId) {
      competition = row;
      break;
    }
  }

  final rows = await services.database.readStandingsTableView(competitionId);

  return StandingsState(
    competitionId: competitionId,
    competitionName: competition?.name ?? 'Standings',
    rows: rows,
  );
});
