import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/video_playback_position_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists and restores playback position per video item', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final cacheStore = DaylySportCacheStore(sharedPreferences: prefs);
    final store = VideoPlaybackPositionStore(cacheStore: cacheStore);
    final item = DaylySportMediaItem(
      file: File('goal.mp4.esv'),
      relativePath: 'highlights/goal.mp4.esv',
      section: DaylySportMediaSection.highlights,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 19, 8),
      sizeBytes: 12,
    );

    await store.writePosition(
      item,
      const Duration(seconds: 38),
      duration: const Duration(minutes: 2),
    );

    expect(store.readPosition(item), const Duration(seconds: 38));
  });

  test('clears saved position when playback is effectively complete', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final cacheStore = DaylySportCacheStore(sharedPreferences: prefs);
    final store = VideoPlaybackPositionStore(cacheStore: cacheStore);
    final item = DaylySportMediaItem(
      file: File('briefing.mp4.esv'),
      relativePath: 'updates/briefing.mp4.esv',
      section: DaylySportMediaSection.updates,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 19, 9),
      sizeBytes: 12,
    );

    await store.writePosition(
      item,
      const Duration(minutes: 1, seconds: 58),
      duration: const Duration(minutes: 2),
    );

    expect(store.readPosition(item), isNull);
  });
}