import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/media/data/video_resume_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late DaylySportCacheStore cacheStore;
  late VideoResumeService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    preferences = await SharedPreferences.getInstance();
    cacheStore = DaylySportCacheStore(sharedPreferences: preferences);
    service = VideoResumeService(cacheStore: cacheStore);
  });

  test('save and restore resume for the same video key', () async {
    await service.savePosition(
      videoKey: 'videos/highlights/goal_1.esv',
      position: const Duration(seconds: 47),
      totalDuration: const Duration(minutes: 3),
    );

    final restored = await service.readPosition(
      videoKey: 'videos/highlights/goal_1.esv',
      totalDuration: const Duration(minutes: 3),
    );

    expect(restored, const Duration(seconds: 47));
  });

  test('resume does not leak between different videos', () async {
    await service.savePosition(
      videoKey: 'videos/news/headline_1.esv',
      position: const Duration(seconds: 22),
      totalDuration: const Duration(minutes: 2),
    );

    final unrelated = await service.readPosition(
      videoKey: 'videos/updates/injury_2.esv',
      totalDuration: const Duration(minutes: 2),
    );

    expect(unrelated, isNull);
  });

  test('near-complete playback clears persisted resume', () async {
    await service.savePosition(
      videoKey: 'videos/updates/briefing.esv',
      position: const Duration(seconds: 96),
      totalDuration: const Duration(seconds: 100),
    );

    final restored = await service.readPosition(
      videoKey: 'videos/updates/briefing.esv',
      totalDuration: const Duration(seconds: 100),
    );

    expect(restored, isNull);
  });

  test('saved resume survives service recreation', () async {
    await service.savePosition(
      videoKey: 'videos/news/headline_3.esv',
      position: const Duration(seconds: 33),
      totalDuration: const Duration(minutes: 2),
    );

    final reloadedService = VideoResumeService(cacheStore: cacheStore);
    final restored = await reloadedService.readPosition(
      videoKey: 'videos/news/headline_3.esv',
      totalDuration: const Duration(minutes: 2),
    );

    expect(restored, const Duration(seconds: 33));
  });

  test('normalizes video keys across case and path separators', () async {
    await service.savePosition(
      videoKey: 'Highlights\\Goal_1.ESV',
      position: const Duration(seconds: 29),
      totalDuration: const Duration(minutes: 2),
    );

    final restored = await service.readPosition(
      videoKey: 'highlights/goal_1.esv',
      totalDuration: const Duration(minutes: 2),
    );

    expect(restored, const Duration(seconds: 29));
  });
}
