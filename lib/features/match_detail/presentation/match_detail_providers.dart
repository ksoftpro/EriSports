import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchDetailProvider =
    FutureProvider.family<MatchDetailView, String>((ref, matchId) async {
  final services = ref.read(appServicesProvider);
  final detail = await services.database.readMatchDetailById(matchId);
  if (detail == null) {
    throw StateError('Match not found: $matchId');
  }
  return detail;
});