import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeagueOverviewState {
  const LeagueOverviewState({
    required this.competitionId,
    required this.competitionName,
    required this.countryLabel,
    required this.seasonLabel,
    required this.rows,
  });

  final String competitionId;
  final String competitionName;
  final String countryLabel;
  final String seasonLabel;
  final List<StandingsTableView> rows;
}

final leagueOverviewProvider = FutureProvider.family<
  LeagueOverviewState,
  String
>((ref, competitionId) async {
  final services = ref.read(appServicesProvider);
  final competition = await services.database.readCompetitionById(
    competitionId,
  );
  final rows = await services.database.readStandingsTableView(competitionId);

  final competitionName = competition?.name ?? 'League';
  final country = competition?.country;

  return LeagueOverviewState(
    competitionId: competitionId,
    competitionName: competitionName,
    countryLabel: _countryLabel(country, competitionName),
    seasonLabel: _defaultSeasonLabel(),
    rows: rows,
  );
});

String _countryLabel(String? country, String competitionName) {
  if (country != null && country.trim().isNotEmpty) {
    return country.trim();
  }

  final normalized = competitionName.toLowerCase();
  if (normalized.contains('premier')) {
    return 'England';
  }
  if (normalized.contains('laliga') || normalized.contains('la liga')) {
    return 'Spain';
  }
  if (normalized.contains('bundesliga')) {
    return 'Germany';
  }
  if (normalized.contains('serie a')) {
    return 'Italy';
  }
  if (normalized.contains('ligue')) {
    return 'France';
  }

  return 'Competition';
}

String _defaultSeasonLabel() {
  final now = DateTime.now();
  final seasonStartYear = now.month >= 7 ? now.year : now.year - 1;
  return '$seasonStartYear/${seasonStartYear + 1}';
}
