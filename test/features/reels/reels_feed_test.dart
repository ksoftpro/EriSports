import 'dart:io';

import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/reels/presentation/reels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('activates the first reel on open and switches active reel on swipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync('eri_reels_feed_test_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final firstFile = File('${tempDir.path}${Platform.pathSeparator}first.mp4.esv')
      ..writeAsBytesSync(const <int>[1, 2, 3]);
    final secondFile = File('${tempDir.path}${Platform.pathSeparator}second.mp4.esv')
      ..writeAsBytesSync(const <int>[4, 5, 6]);

    final items = <DaylySportMediaItem>[
      DaylySportMediaItem(
        file: firstFile,
        relativePath: 'reels/first.mp4.esv',
        section: DaylySportMediaSection.reels,
        type: DaylySportMediaType.video,
        lastModified: DateTime.utc(2026, 4, 16, 12),
        sizeBytes: 3,
      ),
      DaylySportMediaItem(
        file: secondFile,
        relativePath: 'reels/second.mp4.esv',
        section: DaylySportMediaSection.reels,
        type: DaylySportMediaType.video,
        lastModified: DateTime.utc(2026, 4, 16, 12, 1),
        sizeBytes: 3,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ReelsFeed(
          items: items,
          itemBuilder: (context, item, isActive) {
            return ColoredBox(
              color: isActive ? Colors.green : Colors.blueGrey,
              child: Center(
                child: Text(
                  '${item.fileName}:${isActive ? 'active' : 'inactive'}',
                  textDirection: TextDirection.ltr,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('first.mp4:active'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, -700), 1200);
    await tester.pumpAndSettle();

    expect(find.text('first.mp4:active'), findsNothing);
    expect(find.text('second.mp4:active'), findsOneWidget);
  });
}