import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchResults {
  const SearchResults({
    required this.query,
    required this.teams,
    required this.players,
    required this.competitions,
  });

  final String query;
  final List<TeamRow> teams;
  final List<PlayerRow> players;
  final List<CompetitionRow> competitions;
}

final searchResultsProvider = FutureProvider.family<SearchResults, String>((
  ref,
  query,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  final normalized = query.trim();
  if (normalized.isEmpty) {
    return const SearchResults(
      query: '',
      teams: [],
      players: [],
      competitions: [],
    );
  }

  final services = ref.read(appServicesProvider);
  final teams = await services.database.searchTeamsByName(normalized);
  final players = await services.database.searchPlayersByName(normalized);
  final competitions = await services.database.searchCompetitionsByName(
    normalized,
  );

  return SearchResults(
    query: normalized,
    teams: teams,
    players: players,
    competitions: competitions,
  );
});
