import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeFeedState {
  const HomeFeedState({
    required this.live,
    required this.upcoming,
    required this.recent,
  });

  final List<HomeMatchView> live;
  final List<HomeMatchView> upcoming;
  final List<HomeMatchView> recent;
}

final homeFeedProvider = FutureProvider<HomeFeedState>((ref) async {
  final services = ref.read(appServicesProvider);
  final now = DateTime.now().toUtc();
  final matches = await services.database.readHomeFeedMatches(nowUtc: now);

  final live = <HomeMatchView>[];
  final upcoming = <HomeMatchView>[];
  final recent = <HomeMatchView>[];

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
  }

  return HomeFeedState(
    live: live,
    upcoming: upcoming,
    recent: recent,
  );
});

bool _isLiveStatus(String status) {
  const liveTokens = {
    'live',
    'inplay',
    'in_play',
    'playing',
    'ht',
  };
  return liveTokens.contains(status);
}