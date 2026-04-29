import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _reelsPlaybackSessionScope = 'reels_playback_session_v1';
const _reelsPlaybackSessionKey = 'active_reel';

String reelPlaybackItemKey(DaylySportMediaItem item) {
  final normalizedRelativePath =
      item.relativePath.trim().replaceAll('\\', '/').toLowerCase();
  if (normalizedRelativePath.isNotEmpty) {
    return '${item.section.name}::$normalizedRelativePath';
  }

  final normalizedFilePath = item.file.path.trim().replaceAll('\\', '/').toLowerCase();
  return '${item.section.name}::$normalizedFilePath';
}

class ReelsPlaybackSessionStore {
  ReelsPlaybackSessionStore({required this.cacheStore});

  final DaylySportCacheStore cacheStore;

  String? readActiveReelKey() {
    final state = cacheStore.readJsonObject(
      _reelsPlaybackSessionScope,
      _reelsPlaybackSessionKey,
    );
    final activeReelKey = state?['activeReelKey'];
    if (activeReelKey is! String || activeReelKey.trim().isEmpty) {
      return null;
    }
    return activeReelKey;
  }

  Future<void> writeActiveReelKey(String? activeReelKey) {
    if (activeReelKey == null || activeReelKey.trim().isEmpty) {
      return cacheStore.writeJsonObject(
        _reelsPlaybackSessionScope,
        _reelsPlaybackSessionKey,
        null,
      );
    }

    return cacheStore.writeJsonObject(
      _reelsPlaybackSessionScope,
      _reelsPlaybackSessionKey,
      <String, dynamic>{'activeReelKey': activeReelKey},
    );
  }
}

final reelsPlaybackSessionStoreProvider = Provider<ReelsPlaybackSessionStore>((
  ref,
) {
  return ReelsPlaybackSessionStore(
    cacheStore: ref.read(appServicesProvider).cacheStore,
  );
});
