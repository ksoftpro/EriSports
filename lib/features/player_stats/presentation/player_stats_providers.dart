import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final topStatsCompetitionsProvider =
    FutureProvider<List<TopStatsCompetitionView>>((ref) async {
      ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
      ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
      final services = ref.read(appServicesProvider);
      return services.database.readTopStatsCompetitions();
    });

final topStatCategoriesProvider =
    FutureProvider.family<List<TopStatCategoryView>, String>((
      ref,
      competitionId,
    ) async {
      ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
      final services = ref.read(appServicesProvider);
      return services.database.readTopStatCategories(competitionId);
    });

@immutable
class TopPlayersQuery {
  const TopPlayersQuery({
    required this.competitionId,
    required this.statType,
    this.limit = 60,
  });

  final String competitionId;
  final String statType;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is TopPlayersQuery &&
        other.competitionId == competitionId &&
        other.statType == statType &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(competitionId, statType, limit);
}

final topPlayersLeaderboardProvider =
    FutureProvider.family<List<TopPlayerLeaderboardEntryView>, TopPlayersQuery>(
      (ref, query) async {
        ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
        final services = ref.read(appServicesProvider);
        return services.database.readTopPlayersForCategory(
          query.competitionId,
          query.statType,
          limit: query.limit,
        );
      },
    );

String statTypeLabel(String key) {
  const custom = {
    'goals': 'Goals',
    'assists': 'Assists',
    'goals_per_90': 'Goals / 90',
    'expected_goals': 'Expected Goals',
    'expected_assists': 'Expected Assists',
    'big_chances_created': 'Big Chances Created',
    'accurate_passes': 'Accurate Passes',
    'successful_dribbles': 'Successful Dribbles',
    'shots_on_target': 'Shots on Target',
    'clean_sheets': 'Clean Sheets',
    'saves': 'Saves',
    'rating': 'Rating',
  };

  final direct = custom[key];
  if (direct != null) {
    return direct;
  }

  final words = key
      .replaceAll('-', '_')
      .split('_')
      .where((word) => word.trim().isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
  return words.join(' ');
}

String compactNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(value.abs() >= 10 ? 1 : 2);
}
