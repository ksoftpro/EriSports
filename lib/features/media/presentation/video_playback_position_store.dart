import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _videoPlaybackPositionScope = 'video_playback_positions_v1';
const _videoPlaybackPositionKey = 'positions';
const _maxStoredPlaybackPositions = 200;

class SavedVideoPlaybackPosition {
  const SavedVideoPlaybackPosition({
    required this.itemId,
    required this.positionMs,
    required this.updatedAtUtc,
  });

  final String itemId;
  final int positionMs;
  final DateTime updatedAtUtc;

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'positionMs': positionMs,
      'updatedAtEpochMs': updatedAtUtc.toUtc().millisecondsSinceEpoch,
    };
  }

  static SavedVideoPlaybackPosition? fromJson(Map<String, dynamic> json) {
    final itemId = json['itemId'];
    final positionMs = json['positionMs'];
    final updatedAtEpochMs = json['updatedAtEpochMs'];
    if (itemId is! String || positionMs is! int || updatedAtEpochMs is! int) {
      return null;
    }
    return SavedVideoPlaybackPosition(
      itemId: itemId,
      positionMs: positionMs,
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        updatedAtEpochMs,
        isUtc: true,
      ),
    );
  }
}

String videoPlaybackPositionItemId(DaylySportMediaItem item) {
  return '${item.relativePath}|${item.lastModified.toUtc().millisecondsSinceEpoch}|${item.sizeBytes}';
}

class VideoPlaybackPositionStore {
  VideoPlaybackPositionStore({required this.cacheStore});

  final DaylySportCacheStore cacheStore;

  Duration? readPosition(DaylySportMediaItem item) {
    final entry = _loadEntries()[videoPlaybackPositionItemId(item)];
    if (entry == null || entry.positionMs <= 0) {
      return null;
    }
    return Duration(milliseconds: entry.positionMs);
  }

  Future<void> writePosition(
    DaylySportMediaItem item,
    Duration position, {
    Duration? duration,
  }) async {
    final entries = _loadEntries();
    final itemId = videoPlaybackPositionItemId(item);
    if (_shouldClearPosition(position: position, duration: duration)) {
      entries.remove(itemId);
    } else {
      entries[itemId] = SavedVideoPlaybackPosition(
        itemId: itemId,
        positionMs: position.inMilliseconds,
        updatedAtUtc: DateTime.now().toUtc(),
      );
    }
    await _persistEntries(entries);
  }

  Future<void> clearPosition(DaylySportMediaItem item) async {
    final entries = _loadEntries();
    entries.remove(videoPlaybackPositionItemId(item));
    await _persistEntries(entries);
  }

  bool _shouldClearPosition({
    required Duration position,
    required Duration? duration,
  }) {
    if (position <= Duration.zero) {
      return true;
    }
    if (duration == null || duration <= Duration.zero) {
      return false;
    }
    return (duration - position) <= const Duration(seconds: 2);
  }

  Map<String, SavedVideoPlaybackPosition> _loadEntries() {
    final entries = cacheStore
        .readJsonObjectList(_videoPlaybackPositionScope, _videoPlaybackPositionKey)
        .map(SavedVideoPlaybackPosition.fromJson)
        .whereType<SavedVideoPlaybackPosition>();
    return {for (final entry in entries) entry.itemId: entry};
  }

  Future<void> _persistEntries(
    Map<String, SavedVideoPlaybackPosition> entries,
  ) {
    final trimmedEntries = entries.values.toList(growable: false)
      ..sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    final limited = trimmedEntries.take(_maxStoredPlaybackPositions).toList(
      growable: false,
    );
    return cacheStore.writeJsonObjectList(
      _videoPlaybackPositionScope,
      _videoPlaybackPositionKey,
      limited.map((entry) => entry.toJson()).toList(growable: false),
    );
  }
}

final videoPlaybackPositionStoreProvider = Provider<VideoPlaybackPositionStore>((
  ref,
) {
  return VideoPlaybackPositionStore(
    cacheStore: ref.read(appServicesProvider).cacheStore,
  );
});