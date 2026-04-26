import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:eri_sports/features/video/presentation/video_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('builds dynamic tabs from available video categories', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_video_screen_dynamic_tabs_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final highlightFile = File(
      '${tempDir.path}${Platform.pathSeparator}highlight_clip.mp4',
    )..writeAsBytesSync(const <int>[1, 2, 3]);
    final transferFile = File(
      '${tempDir.path}${Platform.pathSeparator}transfer_clip.mp4',
    )..writeAsBytesSync(const <int>[4, 5, 6]);

    final snapshot = DaylySportMediaSnapshot(
      rootDirectory: tempDir,
      scannedAt: DateTime.utc(2026, 4, 23, 10),
      sections: {
        DaylySportMediaSection.reels: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.reels,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
        DaylySportMediaSection.highlights: DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.highlights,
          items: [
            DaylySportMediaItem(
              file: highlightFile,
              relativePath: 'highlights/highlight_clip.mp4',
              section: DaylySportMediaSection.highlights,
              type: DaylySportMediaType.video,
              lastModified: DateTime.utc(2026, 4, 23, 9),
              sizeBytes: 3,
              categoryKey: 'highlights',
              categoryLabel: 'Highlights',
            ),
            DaylySportMediaItem(
              file: transferFile,
              relativePath: 'transfers/transfer_clip.mp4',
              section: DaylySportMediaSection.highlights,
              type: DaylySportMediaType.video,
              lastModified: DateTime.utc(2026, 4, 23, 8),
              sizeBytes: 3,
              categoryKey: 'transfers',
              categoryLabel: 'Transfers',
            ),
          ],
          existingDirectories: <String>[tempDir.path],
          scannedDirectories: <String>[tempDir.path],
        ),
        DaylySportMediaSection.news: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.news,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
        DaylySportMediaSection.updates: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.updates,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
      },
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'video_list_layout_mode_v1': 'details',
    });
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);

    addTearDown(() async {
      await services.database.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          sharedPreferencesProvider.overrideWithValue(preferences),
          offlineContentBadgeCountsProvider.overrideWithValue(
            const OfflineContentBadgeCounts.zero(),
          ),
          offlineSeenItemIdsProvider.overrideWithValue(<String>{}),
          offlineContentDeletionProgressProvider.overrideWithValue(null),
          daylySportMediaSnapshotProvider.overrideWith(
            () => _TestDaylySportMediaSnapshotNotifier(snapshot),
          ),
        ],
        child: const MaterialApp(home: VideoScreen()),
      ),
    );
    await _pumpUntil(tester, () => find.text('Transfers').evaluate().isNotEmpty);
    await _pumpUntil(
      tester,
      () => find.text('highlight_clip.mp4').evaluate().isNotEmpty,
    );

    expect(find.text('Highlights'), findsWidgets);
    expect(find.text('Transfers'), findsOneWidget);
    expect(find.text('highlight_clip.mp4'), findsOneWidget);
    expect(find.text('transfer_clip.mp4'), findsNothing);

    await tester.tap(find.text('Transfers').first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('transfer_clip.mp4'), findsOneWidget);
    expect(find.text('highlight_clip.mp4'), findsNothing);
  });

  testWidgets('reduces a dynamic tab badge count when a video becomes seen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_video_screen_seen_count_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final highlightFile = File(
      '${tempDir.path}${Platform.pathSeparator}highlight_clip.mp4',
    )..writeAsBytesSync(const <int>[1, 2, 3]);
    final transferFile = File(
      '${tempDir.path}${Platform.pathSeparator}transfer_clip.mp4',
    )..writeAsBytesSync(const <int>[4, 5, 6]);

    final highlightItem = DaylySportMediaItem(
      file: highlightFile,
      relativePath: 'highlights/highlight_clip.mp4',
      section: DaylySportMediaSection.highlights,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 23, 9),
      sizeBytes: 3,
      categoryKey: 'highlights',
      categoryLabel: 'Highlights',
    );
    final transferItem = DaylySportMediaItem(
      file: transferFile,
      relativePath: 'transfers/transfer_clip.mp4',
      section: DaylySportMediaSection.highlights,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 23, 8),
      sizeBytes: 3,
      categoryKey: 'transfers',
      categoryLabel: 'Transfers',
    );

    final snapshot = DaylySportMediaSnapshot(
      rootDirectory: tempDir,
      scannedAt: DateTime.utc(2026, 4, 23, 10),
      sections: {
        DaylySportMediaSection.reels: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.reels,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
        DaylySportMediaSection.highlights: DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.highlights,
          items: [highlightItem, transferItem],
          existingDirectories: <String>[tempDir.path],
          scannedDirectories: <String>[tempDir.path],
        ),
        DaylySportMediaSection.news: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.news,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
        DaylySportMediaSection.updates: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.updates,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
      },
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'video_list_layout_mode_v1': 'details',
    });
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        sharedPreferencesProvider.overrideWithValue(preferences),
        daylySportMediaSnapshotProvider.overrideWith(
          () => _TestDaylySportMediaSnapshotNotifier(snapshot),
        ),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await services.database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VideoScreen()),
      ),
    );
    await _pumpUntil(tester, () => find.text('Transfers').evaluate().isNotEmpty);

    expect(find.text('1'), findsNWidgets(2));

    await container
        .read(offlineContentRefreshControllerProvider.notifier)
        .markMediaItemSeen(transferItem);
    await tester.pump();

    expect(find.text('Transfers'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('blocks unverified dynamic-category videos from opening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_video_screen_unverified_dynamic_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final transferFile = File(
      '${tempDir.path}${Platform.pathSeparator}transfer_clip.mp4',
    )..writeAsBytesSync(const <int>[4, 5, 6]);
    final transferItem = DaylySportMediaItem(
      file: transferFile,
      relativePath: 'transfers/transfer_clip.mp4',
      section: DaylySportMediaSection.highlights,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 23, 8),
      sizeBytes: 3,
      categoryKey: 'transfers',
      categoryLabel: 'Transfers',
    );

    final snapshot = DaylySportMediaSnapshot(
      rootDirectory: tempDir,
      scannedAt: DateTime.utc(2026, 4, 23, 10),
      sections: {
        DaylySportMediaSection.reels: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.reels,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
        DaylySportMediaSection.highlights: DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.highlights,
          items: [transferItem],
          existingDirectories: <String>[tempDir.path],
          scannedDirectories: <String>[tempDir.path],
        ),
        DaylySportMediaSection.news: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.news,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
        DaylySportMediaSection.updates: const DaylySportMediaSectionSnapshot(
          section: DaylySportMediaSection.updates,
          items: <DaylySportMediaItem>[],
          existingDirectories: <String>[],
          scannedDirectories: <String>[],
        ),
      },
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'video_list_layout_mode_v1': 'details',
    });
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);

    addTearDown(() async {
      await services.database.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          sharedPreferencesProvider.overrideWithValue(preferences),
          offlineContentBadgeCountsProvider.overrideWithValue(
            const OfflineContentBadgeCounts.zero(),
          ),
          offlineSeenItemIdsProvider.overrideWithValue(<String>{}),
          offlineActiveVerifiedItemIdsProvider.overrideWithValue(<String>{}),
          offlineContentDeletionProgressProvider.overrideWithValue(null),
          daylySportMediaSnapshotProvider.overrideWith(
            () => _TestDaylySportMediaSnapshotNotifier(snapshot),
          ),
        ],
        child: const MaterialApp(home: VideoScreen()),
      ),
    );
    await _pumpUntil(tester, () => find.text('Transfers').evaluate().isNotEmpty);
    await _pumpUntil(
      tester,
      () => find.text('transfer_clip.mp4').evaluate().isNotEmpty,
    );

    expect(find.text('Transfers'), findsWidgets);
    expect(find.text('Pending verification'), findsOneWidget);

    await tester.tap(find.text('transfer_clip.mp4').first.hitTestable());
    await tester.pump();

    expect(
      find.text('This content is pending official verification.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration step = const Duration(milliseconds: 50),
  int maxTicks = 60,
}) async {
  for (var tick = 0; tick < maxTicks; tick++) {
    if (predicate()) {
      return;
    }
    await tester.pump(step);
  }
  expect(predicate(), isTrue);
}

class _TestDaylySportMediaSnapshotNotifier
    extends DaylySportMediaSnapshotNotifier {
  _TestDaylySportMediaSnapshotNotifier(this.snapshot);

  final DaylySportMediaSnapshot snapshot;

  @override
  Future<DaylySportMediaSnapshot> build() async => snapshot;
}