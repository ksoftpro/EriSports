import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:eri_sports/features/news/presentation/offline_news_providers.dart';
import 'package:flutter/services.dart';
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
      await _installPathProviderMock(tempDir);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();
      services = await AppServices.create(sharedPreferences: preferences);
      await services.daylySportLocator.setCustomDirectoryPath(
        '${tempDir.path}${Platform.pathSeparator}daylySport',
      );
    });

    tearDown(() async {
      await _clearPathProviderMock();
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

    test(
      'keeps existing content verified, blocks newly discovered content by default, and allows later verification',
      () async {
        final daylySportDir =
            await services.daylySportLocator.getOrCreateDaylySportDirectory();
        final reelsDir = Directory(
          '${daylySportDir.path}${Platform.pathSeparator}reels',
        )..createSync(recursive: true);

        final existingFile = File(
          '${reelsDir.path}${Platform.pathSeparator}existing.mp4.esv',
        )..writeAsBytesSync(const <int>[1, 2, 3, 4]);
        final existingModifiedAt = DateTime.utc(2026, 4, 24, 9);
        existingFile.setLastModifiedSync(existingModifiedAt);

        final container = ProviderContainer(
          overrides: [appServicesProvider.overrideWithValue(services)],
        );
        addTearDown(container.dispose);

        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .refreshOnStartup();

        final firstSnapshot = await container.read(
          daylySportMediaSnapshotProvider.future,
        );
        final existingItem =
            firstSnapshot.section(DaylySportMediaSection.reels).videoItems.single;
        final existingId = offlineContentMediaItemId(existingItem);

        expect(
          container.read(offlineActiveVerifiedItemIdsProvider),
          contains(existingId),
        );

        final newFile = File(
          '${reelsDir.path}${Platform.pathSeparator}new_drop.mp4.esv',
        )..writeAsBytesSync(const <int>[5, 6, 7, 8, 9]);
        final newModifiedAt = DateTime.utc(2026, 4, 24, 10);
        newFile.setLastModifiedSync(newModifiedAt);
        final newItem = DaylySportMediaItem(
          file: newFile,
          relativePath: 'reels/new_drop.mp4.esv',
          section: DaylySportMediaSection.reels,
          type: DaylySportMediaType.video,
          lastModified: newModifiedAt,
          sizeBytes: 5,
        );
        final newItemId = _mediaId(
          relativePath: newItem.relativePath,
          modifiedAtUtc: newItem.lastModified,
          sizeBytes: newItem.sizeBytes,
        );

        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .refreshOnStartup();

        final verifiedIdsAfterRefresh = container.read(
          offlineActiveVerifiedItemIdsProvider,
        );
        expect(verifiedIdsAfterRefresh, isNotNull);
        expect(verifiedIdsAfterRefresh, contains(existingId));
        expect(verifiedIdsAfterRefresh, isNot(contains(newItemId)));

        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .setMediaItemVerified(newItem, verified: true);

        expect(
          container.read(offlineActiveVerifiedItemIdsProvider),
          contains(newItemId),
        );
      },
    );

    test(
      'single delete removes reel source, cached file, seen state, and refreshes badges',
      () async {
        final daylySportDir =
            await services.daylySportLocator.getOrCreateDaylySportDirectory();
        final sourceDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}source_single_delete',
        )..createSync(recursive: true);

        final plainVideo = File(
          '${sourceDir.path}${Platform.pathSeparator}goal.mp4',
        )..writeAsBytesSync(List<int>.generate(1024, (index) => index % 251));
        final encryptedVideo = File(
          '${daylySportDir.path}${Platform.pathSeparator}reels${Platform.pathSeparator}goal.mp4.esv',
        )..parent.createSync(recursive: true);
        encryptMediaFileSync(
          sourcePath: plainVideo.path,
          destinationPath: encryptedVideo.path,
          masterKey: services.secureContentCoordinator.mediaMasterKey,
        );

        final plainImage = File(
          '${sourceDir.path}${Platform.pathSeparator}headline.png',
        )..writeAsBytesSync(<int>[137, 80, 78, 71, 9, 8, 7, 6]);
        final encryptedImage = File(
          '${daylySportDir.path}${Platform.pathSeparator}news${Platform.pathSeparator}headline.png.esi',
        )..parent.createSync(recursive: true);
        encryptSecureFileSync(
          sourcePath: plainImage.path,
          destinationPath: encryptedImage.path,
          masterKey: services.secureContentCoordinator.secureContentMasterKey,
          contentType: SecureContentType.image,
        );

        final container = ProviderContainer(
          overrides: [appServicesProvider.overrideWithValue(services)],
        );
        addTearDown(container.dispose);

        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .refreshOnStartup();

        final mediaSnapshot = await container.read(
          daylySportMediaSnapshotProvider.future,
        );
        final newsSnapshot = await container.read(
          offlineNewsGalleryProvider.future,
        );
        final reel =
            mediaSnapshot
                .section(DaylySportMediaSection.reels)
                .videoItems
                .single;
        final newsImage = newsSnapshot.images.single;

        final resolvedVideo = await services.encryptedMediaService
            .resolvePlayableFile(reel.file);
        final resolvedImage = await services.encryptedImageService
            .resolveImageFile(newsImage.file);
        expect(resolvedVideo.file.existsSync(), isTrue);
        expect(resolvedImage.file.existsSync(), isTrue);

        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .markMediaItemSeen(reel);

        final result = await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .deleteItems(mediaItems: [reel]);

        expect(result.requestedCount, 1);
        expect(result.deletedCount, 1);
        expect(result.missingCount, 0);
        expect(result.failedCount, 0);
        expect(encryptedVideo.existsSync(), isFalse);
        expect(resolvedVideo.file.existsSync(), isFalse);
        expect(encryptedImage.existsSync(), isTrue);
        expect(resolvedImage.file.existsSync(), isTrue);
        expect(
          services.cacheStore.readPathList('offline_content_v1', 'seen_items'),
          isNot(contains(offlineContentMediaItemId(reel))),
        );

        final refreshedMedia = await container.read(
          daylySportMediaSnapshotProvider.future,
        );
        final refreshedNews = await container.read(
          offlineNewsGalleryProvider.future,
        );
        expect(
          refreshedMedia.section(DaylySportMediaSection.reels).videoItems,
          isEmpty,
        );
        expect(refreshedNews.images, hasLength(1));
        expect(
          container.read(offlineContentBadgeCountsProvider),
          isA<OfflineContentBadgeCounts>()
              .having((value) => value.reels, 'reels', 0)
              .having((value) => value.newsImages, 'newsImages', 1),
        );
      },
    );

    test(
      'bulk delete removes media and news items, clears caches, and tolerates missing files',
      () async {
        final daylySportDir =
            await services.daylySportLocator.getOrCreateDaylySportDirectory();
        final sourceDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}source_bulk_delete',
        )..createSync(recursive: true);

        final plainHighlight = File(
          '${sourceDir.path}${Platform.pathSeparator}highlight.mp4',
        )..writeAsBytesSync(
          List<int>.generate(1536, (index) => (index * 3) % 253),
        );
        final highlightFile = File(
          '${daylySportDir.path}${Platform.pathSeparator}highlights${Platform.pathSeparator}highlight.mp4.esv',
        )..parent.createSync(recursive: true);
        encryptMediaFileSync(
          sourcePath: plainHighlight.path,
          destinationPath: highlightFile.path,
          masterKey: services.secureContentCoordinator.mediaMasterKey,
        );

        final plainUpdate = File(
          '${sourceDir.path}${Platform.pathSeparator}update.mp4',
        )..writeAsBytesSync(
          List<int>.generate(2048, (index) => (index * 5) % 251),
        );
        final updateFile = File(
          '${daylySportDir.path}${Platform.pathSeparator}updates${Platform.pathSeparator}update.mp4.esv',
        )..parent.createSync(recursive: true);
        encryptMediaFileSync(
          sourcePath: plainUpdate.path,
          destinationPath: updateFile.path,
          masterKey: services.secureContentCoordinator.mediaMasterKey,
        );

        final plainImage = File(
          '${sourceDir.path}${Platform.pathSeparator}gallery.png',
        )..writeAsBytesSync(<int>[137, 80, 78, 71, 1, 3, 5, 7, 9]);
        final newsFile = File(
          '${daylySportDir.path}${Platform.pathSeparator}news${Platform.pathSeparator}gallery.png.esi',
        )..parent.createSync(recursive: true);
        encryptSecureFileSync(
          sourcePath: plainImage.path,
          destinationPath: newsFile.path,
          masterKey: services.secureContentCoordinator.secureContentMasterKey,
          contentType: SecureContentType.image,
        );

        final container = ProviderContainer(
          overrides: [appServicesProvider.overrideWithValue(services)],
        );
        addTearDown(container.dispose);

        await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .refreshOnStartup();

        final mediaSnapshot = await container.read(
          daylySportMediaSnapshotProvider.future,
        );
        final newsSnapshot = await container.read(
          offlineNewsGalleryProvider.future,
        );
        final highlight =
            mediaSnapshot
                .section(DaylySportMediaSection.highlights)
                .videoItems
                .single;
        final update =
            mediaSnapshot
                .section(DaylySportMediaSection.updates)
                .videoItems
                .single;
        final newsImage = newsSnapshot.images.single;

        final resolvedHighlight = await services.encryptedMediaService
            .resolvePlayableFile(highlight.file);
        final resolvedUpdate = await services.encryptedMediaService
            .resolvePlayableFile(update.file);
        final resolvedNews = await services.encryptedImageService
            .resolveImageFile(newsImage.file);

        await newsImage.file.delete();
        expect(newsImage.file.existsSync(), isFalse);

        final result = await container
            .read(offlineContentRefreshControllerProvider.notifier)
            .deleteItems(
              mediaItems: [highlight, update],
              newsItems: [newsImage],
            );

        expect(result.requestedCount, 3);
        expect(result.deletedCount, 2);
        expect(result.missingCount, 1);
        expect(result.failedCount, 0);
        expect(highlight.file.existsSync(), isFalse);
        expect(update.file.existsSync(), isFalse);
        expect(resolvedHighlight.file.existsSync(), isFalse);
        expect(resolvedUpdate.file.existsSync(), isFalse);
        expect(resolvedNews.file.existsSync(), isFalse);

        final refreshedMedia = await container.read(
          daylySportMediaSnapshotProvider.future,
        );
        final refreshedNews = await container.read(
          offlineNewsGalleryProvider.future,
        );
        expect(
          refreshedMedia.section(DaylySportMediaSection.highlights).videoItems,
          isEmpty,
        );
        expect(
          refreshedMedia.section(DaylySportMediaSection.updates).videoItems,
          isEmpty,
        );
        expect(refreshedNews.images, isEmpty);
        expect(
          container.read(offlineContentBadgeCountsProvider).hasAny,
          isFalse,
        );
      },
    );

    test('publishes per-item deletion progress during bulk delete', () async {
      final daylySportDir =
          await services.daylySportLocator.getOrCreateDaylySportDirectory();
      final sourceDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}source_progress_delete',
      )..createSync(recursive: true);

      final plainReel = File(
        '${sourceDir.path}${Platform.pathSeparator}reel.mp4',
      )..writeAsBytesSync(List<int>.generate(1200, (index) => index % 251));
      final encryptedReel = File(
        '${daylySportDir.path}${Platform.pathSeparator}reels${Platform.pathSeparator}reel.mp4.esv',
      )..parent.createSync(recursive: true);
      encryptMediaFileSync(
        sourcePath: plainReel.path,
        destinationPath: encryptedReel.path,
        masterKey: services.secureContentCoordinator.mediaMasterKey,
      );

      final plainVideo = File(
        '${sourceDir.path}${Platform.pathSeparator}video.mp4',
      )..writeAsBytesSync(
        List<int>.generate(1400, (index) => (index * 7) % 253),
      );
      final encryptedVideo = File(
        '${daylySportDir.path}${Platform.pathSeparator}highlights${Platform.pathSeparator}video.mp4.esv',
      )..parent.createSync(recursive: true);
      encryptMediaFileSync(
        sourcePath: plainVideo.path,
        destinationPath: encryptedVideo.path,
        masterKey: services.secureContentCoordinator.mediaMasterKey,
      );

      final plainImage = File(
        '${sourceDir.path}${Platform.pathSeparator}headline.png',
      )..writeAsBytesSync(<int>[137, 80, 78, 71, 1, 2, 3, 4, 5, 6]);
      final encryptedImage = File(
        '${daylySportDir.path}${Platform.pathSeparator}news${Platform.pathSeparator}headline.png.esi',
      )..parent.createSync(recursive: true);
      encryptSecureFileSync(
        sourcePath: plainImage.path,
        destinationPath: encryptedImage.path,
        masterKey: services.secureContentCoordinator.secureContentMasterKey,
        contentType: SecureContentType.image,
      );

      final container = ProviderContainer(
        overrides: [appServicesProvider.overrideWithValue(services)],
      );
      addTearDown(container.dispose);

      final progressSnapshots = <OfflineContentDeletionProgress>[];
      final sub = container.listen<OfflineContentRefreshState>(
        offlineContentRefreshControllerProvider,
        (_, next) {
          final progress = next.deletionProgress;
          if (progress != null) {
            progressSnapshots.add(progress);
          }
        },
        fireImmediately: false,
      );
      addTearDown(sub.close);

      await container
          .read(offlineContentRefreshControllerProvider.notifier)
          .refreshOnStartup();

      final mediaSnapshot = await container.read(
        daylySportMediaSnapshotProvider.future,
      );
      final newsSnapshot = await container.read(
        offlineNewsGalleryProvider.future,
      );
      final reel =
          mediaSnapshot.section(DaylySportMediaSection.reels).videoItems.single;
      final video =
          mediaSnapshot
              .section(DaylySportMediaSection.highlights)
              .videoItems
              .single;
      final newsImage = newsSnapshot.images.single;

      final result = await container
          .read(offlineContentRefreshControllerProvider.notifier)
          .deleteItems(mediaItems: [reel, video], newsItems: [newsImage]);

      expect(result.requestedCount, 3);
      expect(progressSnapshots, isNotEmpty);
      expect(progressSnapshots.first.totalCount, 3);
      expect(progressSnapshots.first.currentIndex, 1);
      expect(progressSnapshots.first.progressPercent, greaterThan(0));
      expect(
        progressSnapshots.map((snapshot) => snapshot.currentIndex),
        containsAll(<int>[1, 2, 3]),
      );
      expect(progressSnapshots.last.completedCount, 3);
      expect(container.read(offlineContentDeletionProgressProvider), isNull);
    });
  });
}

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Future<void> _installPathProviderMock(Directory tempRoot) {
  final tempPath = tempRoot.path;
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        switch (call.method) {
          case 'getTemporaryDirectory':
          case 'getApplicationDocumentsDirectory':
          case 'getApplicationSupportDirectory':
          case 'getLibraryDirectory':
          case 'getDownloadsDirectory':
          case 'getExternalStorageDirectory':
            return tempPath;
          case 'getExternalCacheDirectories':
          case 'getExternalStorageDirectories':
            return <String>[tempPath];
        }
        return tempPath;
      });
  return Future<void>.value();
}

Future<void> _clearPathProviderMock() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, null);
  return Future<void>.value();
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
