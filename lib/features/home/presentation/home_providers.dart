import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/features/bookmarks/presentation/bookmarks_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeFeedState {
  const HomeFeedState({
    required this.live,
    required this.upcoming,
    required this.recent,
    required this.all,
    required this.followed,
    required this.competitionNamesById,
  });

  final List<HomeMatchView> live;
  final List<HomeMatchView> upcoming;
  final List<HomeMatchView> recent;
  final List<HomeMatchView> all;
  final List<HomeMatchView> followed;
  final Map<String, String> competitionNamesById;
}

final homeFeedProvider = FutureProvider<HomeFeedState>((ref) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.matches));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  final services = ref.read(appServicesProvider);
  final following = ref.watch(followingSelectionProvider);
  final now = DateTime.now().toUtc();
  final matches = await services.database.readHomeFeedMatches(nowUtc: now);
  final competitionMap = await services.database.readCompetitionMapByIds(
    matches
        .map((item) => item.match.competitionId)
        .toSet()
        .toList(growable: false),
  );

  final live = <HomeMatchView>[];
  final upcoming = <HomeMatchView>[];
  final recent = <HomeMatchView>[];
  final followed = <HomeMatchView>[];

  for (final item in matches) {
    final status = item.match.status.toLowerCase();
    if (_isLiveStatus(status)) {
      live.add(item);
      continue;
    }

    if (item.match.kickoffUtc.isAfter(now)) {
      upcoming.add(item);
    } else {
      recent.add(item);
    }

    final isFollowedTeam =
        following.teamIds.contains(item.match.homeTeamId) ||
        following.teamIds.contains(item.match.awayTeamId);
    if (isFollowedTeam) {
      followed.add(item);
    }
  }

  followed.sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

  return HomeFeedState(
    live: live,
    upcoming: upcoming,
    recent: recent,
    all: matches,
    followed: followed,
    competitionNamesById: {
      for (final entry in competitionMap.entries) entry.key: entry.value.name,
    },
  );
});

bool _isLiveStatus(String status) {
  const liveTokens = {'live', 'inplay', 'in_play', 'playing', 'ht'};
  return liveTokens.contains(status);
}
