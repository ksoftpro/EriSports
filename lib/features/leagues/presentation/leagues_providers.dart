import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/domain/league_ordering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final leaguesProvider =
    FutureProvider<List<CompetitionRow>>((ref) async {
  final services = ref.read(appServicesProvider);
  final competitions = await services.database.readCompetitionsSorted();
  return orderLeaguesForReference(competitions);
});