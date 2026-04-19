import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:eri_sports/features/news/presentation/offline_news_providers.dart';
import 'package:eri_sports/features/news/presentation/offline_news_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('does not show the visible news image file name', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync('eri_news_screen_');
    addTearDown(() async {
      await _clearPathProviderMock();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    await _installPathProviderMock(tempDir);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    addTearDown(() => services.database.close());

    final rootDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}daylySport',
    )..createSync(recursive: true);
    final newsDir = Directory('${rootDir.path}${Platform.pathSeparator}news')
      ..createSync(recursive: true);
    final sourceImage = File(
      '${newsDir.path}${Platform.pathSeparator}very_visible_name.png.esi',
    )..writeAsBytesSync(_singlePixelPngBytes);
    final snapshot = OfflineNewsGallerySnapshot(
      rootDirectory: rootDir,
      newsDirectory: newsDir,
      images: [
        OfflineNewsMediaItem(
          file: sourceImage,
          lastModified: DateTime.utc(2026, 4, 19, 8),
          sizeBytes: _singlePixelPngBytes.length,
        ),
      ],
      supportedFormats: const <String>['.esi'],
      skippedUnsupportedCount: 0,
      unreadableCount: 0,
      scannedAt: DateTime.utc(2026, 4, 19, 8),
      newsDirectoryExists: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          offlineNewsGalleryProvider.overrideWith(
            () => _TestOfflineNewsGalleryNotifier(snapshot),
          ),
        ],
        child: const MaterialApp(home: OfflineNewsScreen()),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      if (find.byType(PageView).evaluate().isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Offline News'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.textContaining('very_visible_name'), findsNothing);
    expect(find.textContaining('very_visible_name.png'), findsNothing);
  });
}

class _TestOfflineNewsGalleryNotifier
    extends AsyncNotifier<OfflineNewsGallerySnapshot> {
  _TestOfflineNewsGalleryNotifier(this.snapshot);

  final OfflineNewsGallerySnapshot snapshot;

  @override
  Future<OfflineNewsGallerySnapshot> build() async => snapshot;
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

const List<int> _singlePixelPngBytes = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
