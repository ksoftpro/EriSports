import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineContentRefreshController', () {
    late SharedPreferences preferences;
    late AppServices services;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('eri_offline_content_');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();
      services = await AppServices.create(sharedPreferences: preferences);
    });

    tearDown(() async {
      await services.database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('hydrates badge counts from persisted inventory and seen ids', () {
      final unseenReelId = _mediaId(
        relativePath: 'reels/opening_clip.mp4.esv',
        modifiedAtUtc: DateTime.utc(2026, 4, 17, 9),
        sizeBytes: 128,
      );
      final seenVideoNewsId = _mediaId(
        relativePath: 'video-news/headline.mp4.esv',
        modifiedAtUtc: DateTime.utc(2026, 4, 17, 10),
        sizeBytes: 256,
      );
      final unseenNewsId = _newsId(
        path:
            '${tempDir.path}${Platform.pathSeparator}daylySport${Platform.pathSeparator}news${Platform.pathSeparator}headline.png.esi',
        modifiedAtUtc: DateTime.utc(2026, 4, 17, 11),
        sizeBytes: 64,
      );

      services.cacheStore
          .writeJsonObjectList('offline_content_v1', 'media_inventory', [
            OfflineContentItemRecord(
              id: unseenReelId,
              relativePath: 'reels/opening_clip.mp4.esv',
              kind: OfflineContentKind.reel,
              discoveredAtUtc: DateTime.utc(2026, 4, 17, 9),
              modifiedAtUtc: DateTime.utc(2026, 4, 17, 9),
              sizeBytes: 128,
            ).toJson(),
            OfflineContentItemRecord(
              id: seenVideoNewsId,
              relativePath: 'video-news/headline.mp4.esv',
              kind: OfflineContentKind.videoNews,
              discoveredAtUtc: DateTime.utc(2026, 4, 17, 10),
              modifiedAtUtc: DateTime.utc(2026, 4, 17, 10),
              sizeBytes: 256,
            ).toJson(),
          ]);
      services.cacheStore
          .writeJsonObjectList('offline_content_v1', 'news_inventory', [
            OfflineContentItemRecord(
              id: unseenNewsId,
              relativePath: 'news/headline.png.esi',
              kind: OfflineContentKind.newsImage,
              discoveredAtUtc: DateTime.utc(2026, 4, 17, 11),
              modifiedAtUtc: DateTime.utc(2026, 4, 17, 11),
              sizeBytes: 64,
            ).toJson(),
          ]);
      services.cacheStore.writePathList('offline_content_v1', 'seen_items', [
        seenVideoNewsId,
      ]);

      final container = ProviderContainer(
        overrides: [appServicesProvider.overrideWithValue(services)],
      );
      addTearDown(container.dispose);

      final state = container.read(offlineContentRefreshControllerProvider);

      expect(state.badges.reels, 1);
      expect(state.badges.videoTotal, 0);
      expect(state.badges.videoHighlights, 0);
      expect(state.badges.videoNews, 0);
      expect(state.badges.videoUpdates, 0);
      expect(state.badges.newsImages, 1);
      expect(state.badges.hasAny, isTrue);
    });

    test(
      'persists seen items and keeps badge counts cleared after rebuild',
      () async {
        final reelPath = '${tempDir.path}${Platform.pathSeparator}goal.mp4.esv';
        final newsPath =
            '${tempDir.path}${Platform.pathSeparator}headline.png.esi';
        final modifiedAtUtc = DateTime.utc(2026, 4, 17, 12);

        final reelItem = DaylySportMediaItem(
          file: File(reelPath),
          relativePath: 'reels/goal.mp4.esv',
          section: DaylySportMediaSection.reels,
          type: DaylySportMediaType.video,
          lastModified: modifiedAtUtc,
          sizeBytes: 400,
        );
        final newsItem = OfflineNewsMediaItem(
          file: File(newsPath),
          lastModified: modifiedAtUtc,
          sizeBytes: 80,
        );

        services.cacheStore
            .writeJsonObjectList('offline_content_v1', 'media_inventory', [
              OfflineContentItemRecord(
                id: _mediaId(
                  relativePath: reelItem.relativePath,
                  modifiedAtUtc: reelItem.lastModified,
                  sizeBytes: reelItem.sizeBytes,
                ),
                relativePath: reelItem.relativePath,
                kind: OfflineContentKind.reel,
                discoveredAtUtc: modifiedAtUtc,
                modifiedAtUtc: modifiedAtUtc,
                sizeBytes: reelItem.sizeBytes,
              ).toJson(),
            ]);
        services.cacheStore
            .writeJsonObjectList('offline_content_v1', 'news_inventory', [
              OfflineContentItemRecord(
                id: _newsId(
                  path: newsItem.file.path,
                  modifiedAtUtc: newsItem.lastModified,
                  sizeBytes: newsItem.sizeBytes,
                ),
                relativePath: newsItem.file.path,
                kind: OfflineContentKind.newsImage,
                discoveredAtUtc: modifiedAtUtc,
                modifiedAtUtc: modifiedAtUtc,
                sizeBytes: newsItem.sizeBytes,
              ).toJson(),
            ]);

        final container = ProviderContainer(
          overrides: [appServicesProvider.overrideWithValue(services)],
        );
        addTearDown(container.dispose);

        expect(
          container.read(offlineContentBadgeCountsProvider),
          isA<OfflineContentBadgeCounts>()
              .having((value) => value.reels, 'reels', 1)
              .having((value) => value.newsImages, 'newsImages', 1),
        );

        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .markMediaItemSeen(reelItem);
        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .markNewsItemSeen(newsItem);

        expect(
          container.read(offlineContentBadgeCountsProvider).hasAny,
          isFalse,
        );
        expect(
          services.cacheStore.readPathList('offline_content_v1', 'seen_items'),
          containsAll([
            _mediaId(
              relativePath: reelItem.relativePath,
              modifiedAtUtc: reelItem.lastModified,
              sizeBytes: reelItem.sizeBytes,
            ),
            _newsId(
              path: newsItem.file.path,
              modifiedAtUtc: newsItem.lastModified,
              sizeBytes: newsItem.sizeBytes,
            ),
          ]),
        );

        container.dispose();

        final rebuiltContainer = ProviderContainer(
          overrides: [appServicesProvider.overrideWithValue(services)],
        );
        addTearDown(rebuiltContainer.dispose);

        final rebuiltBadges = rebuiltContainer.read(
          offlineContentBadgeCountsProvider,
        );
        expect(rebuiltBadges.reels, 0);
        expect(rebuiltBadges.videoTotal, 0);
        expect(rebuiltBadges.newsImages, 0);
        expect(rebuiltBadges.hasAny, isFalse);
      },
    );
  });
}

String _mediaId({
  required String relativePath,
  required DateTime modifiedAtUtc,
  required int sizeBytes,
}) {
  return 'media|$relativePath|${modifiedAtUtc.toUtc().millisecondsSinceEpoch}|$sizeBytes';
}

String _newsId({
  required String path,
  required DateTime modifiedAtUtc,
  required int sizeBytes,
}) {
  return 'news|$path|${modifiedAtUtc.toUtc().millisecondsSinceEpoch}|$sizeBytes';
}
