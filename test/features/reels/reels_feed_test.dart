import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'dart:io';

import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/reels/presentation/reels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'activates the first reel on open and switches active reel on swipe',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final tempDir = Directory.systemTemp.createTempSync(
        'eri_reels_feed_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final firstFile = File(
        '${tempDir.path}${Platform.pathSeparator}first.mp4.esv',
      )..writeAsBytesSync(const <int>[1, 2, 3]);
      final secondFile = File(
        '${tempDir.path}${Platform.pathSeparator}second.mp4.esv',
      )..writeAsBytesSync(const <int>[4, 5, 6]);

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
            isScreenActive: true,
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
    },
  );

  testWidgets(
    'disables active reel state when the feed is hidden and restores it when visible again',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final tempDir = Directory.systemTemp.createTempSync(
        'eri_reels_feed_hidden_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final file = File('${tempDir.path}${Platform.pathSeparator}first.mp4.esv')
        ..writeAsBytesSync(const <int>[1, 2, 3]);

      final items = <DaylySportMediaItem>[
        DaylySportMediaItem(
          file: file,
          relativePath: 'reels/first.mp4.esv',
          section: DaylySportMediaSection.reels,
          type: DaylySportMediaType.video,
          lastModified: DateTime.utc(2026, 4, 16, 12),
          sizeBytes: 3,
        ),
      ];

      Widget buildFeed({required bool isScreenActive}) {
        return MaterialApp(
          home: ReelsFeed(
            key: const ValueKey<String>('reels-feed'),
            items: items,
            isScreenActive: isScreenActive,
            itemBuilder: (context, item, isActive) {
              return Center(
                child: Text(
                  '${item.fileName}:${isActive ? 'active' : 'inactive'}',
                  textDirection: TextDirection.ltr,
                ),
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildFeed(isScreenActive: true));
      await tester.pumpAndSettle();
      expect(find.text('first.mp4:active'), findsOneWidget);

      await tester.pumpWidget(buildFeed(isScreenActive: false));
      await tester.pumpAndSettle();
      expect(find.text('first.mp4:inactive'), findsOneWidget);

      await tester.pumpWidget(buildFeed(isScreenActive: true));
      await tester.pumpAndSettle();
      expect(find.text('first.mp4:active'), findsOneWidget);
    },
  );

  testWidgets('uses an external page controller for reel navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_reels_feed_external_controller_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final firstFile = File(
      '${tempDir.path}${Platform.pathSeparator}first.mp4.esv',
    )..writeAsBytesSync(const <int>[1, 2, 3]);
    final secondFile = File(
      '${tempDir.path}${Platform.pathSeparator}second.mp4.esv',
    )..writeAsBytesSync(const <int>[4, 5, 6]);

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
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReelsFeed(
          items: items,
          pageController: controller,
          isScreenActive: true,
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

    controller.animateToPage(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    await tester.pumpAndSettle();

    expect(find.text('second.mp4:active'), findsOneWidget);
  });

  testWidgets(
    'renders the reels list as an overlay and keeps overlay taps working',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final tempDir = Directory.systemTemp.createTempSync(
        'eri_reels_overlay_stage_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final firstFile = File(
        '${tempDir.path}${Platform.pathSeparator}first.mp4.esv',
      )..writeAsBytesSync(const <int>[1, 2, 3]);
      final secondFile = File(
        '${tempDir.path}${Platform.pathSeparator}second.mp4.esv',
      )..writeAsBytesSync(const <int>[4, 5, 6]);

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

      final pageController = PageController();
      final scrollController = ScrollController();
      addTearDown(pageController.dispose);
      addTearDown(scrollController.dispose);

      int? selectedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReelsPlaybackStage(
              items: items,
              activeIndex: 0,
              pageController: pageController,
              overlayController: scrollController,
              seenItemIds: const <String>{},
              isScreenActive: true,
              onActiveIndexChanged: (_) {},
              onSelectReel: (index) {
                selectedIndex = index;
              },
              feedItemBuilder: (context, item, isActive) {
                return ColoredBox(
                  color: isActive ? Colors.black : Colors.blueGrey,
                  child: Center(
                    child: Text(
                      item.fileName,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                );
              },
              overlayThumbnailBuilder: (context, item, isActive) {
                return ColoredBox(
                  color: isActive ? Colors.orange : Colors.grey,
                  child: Center(
                    child: Text(
                      item.fileName,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReelsPlaybackStage), findsOneWidget);
      expect(find.byType(Stack), findsWidgets);
      expect(find.byKey(const ValueKey<String>('reels-overlay-rail')), findsOneWidget);

      final overlayPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('reels-overlay-rail')),
          matching: find.byType(Positioned),
        ).first,
      );
      expect(overlayPositioned.right, isNotNull);
      expect(overlayPositioned.top, isNotNull);
      expect(overlayPositioned.bottom, isNotNull);

      await tester.tap(find.byKey(const ValueKey<String>('reels-overlay-item-1')));
      await tester.pumpAndSettle();

      expect(selectedIndex, 1);
    },
  );

  testWidgets('overlay rail decorations stay borderless', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_reels_overlay_borderless_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}${Platform.pathSeparator}first.mp4.esv')
      ..writeAsBytesSync(const <int>[1, 2, 3]);

    final items = <DaylySportMediaItem>[
      DaylySportMediaItem(
        file: file,
        relativePath: 'reels/first.mp4.esv',
        section: DaylySportMediaSection.reels,
        type: DaylySportMediaType.video,
        lastModified: DateTime.utc(2026, 4, 16, 12),
        sizeBytes: 3,
      ),
    ];

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 92,
            child: ReelsOverlayRail(
              items: items,
              activeIndex: 0,
              controller: controller,
              seenItemIds: const <String>{},
              onSelect: (_) {},
              thumbnailBuilder: (context, item, isActive) {
                return const ColoredBox(color: Colors.black);
              },
            ),
          ),
        ),
      ),
    );
      await tester.pumpAndSettle();

    final decorations = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(ReelsOverlayRail),
        matching: find.byType(DecoratedBox),
      ),
    );

    for (final decoratedBox in decorations) {
      final decoration = decoratedBox.decoration;
      if (decoration is BoxDecoration) {
        expect(decoration.border, isNull);
      }
    }
  });

  testWidgets('shows New badge only for unseen overlay reel items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_reels_overlay_new_badge_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final firstFile = File(
      '${tempDir.path}${Platform.pathSeparator}first.mp4.esv',
    )..writeAsBytesSync(const <int>[1, 2, 3]);
    final secondFile = File(
      '${tempDir.path}${Platform.pathSeparator}second.mp4.esv',
    )..writeAsBytesSync(const <int>[4, 5, 6]);

    final firstItem = DaylySportMediaItem(
      file: firstFile,
      relativePath: 'reels/first.mp4.esv',
      section: DaylySportMediaSection.reels,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 16, 12),
      sizeBytes: 3,
    );
    final secondItem = DaylySportMediaItem(
      file: secondFile,
      relativePath: 'reels/second.mp4.esv',
      section: DaylySportMediaSection.reels,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 16, 12, 1),
      sizeBytes: 3,
    );
    final seenItemIds = <String>{offlineContentMediaItemId(firstItem)};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 92,
            child: ReelsOverlayRail(
              items: [firstItem, secondItem],
              activeIndex: 0,
              controller: controller,
              seenItemIds: seenItemIds,
              onSelect: (_) {},
              thumbnailBuilder: (context, item, isActive) {
                return const ColoredBox(color: Colors.black);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOneWidget);
  });

  testWidgets(
    'marks reels inactive when another route is pushed over the screen and restores on pop',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final tempDir = Directory.systemTemp.createTempSync(
        'eri_reels_screen_route_overlay_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final file = File('${tempDir.path}${Platform.pathSeparator}first.mp4')
        ..writeAsBytesSync(const <int>[1, 2, 3]);
      final items = <DaylySportMediaItem>[
        DaylySportMediaItem(
          file: file,
          relativePath: 'reels/first.mp4',
          section: DaylySportMediaSection.reels,
          type: DaylySportMediaType.video,
          lastModified: DateTime.utc(2026, 4, 16, 12),
          sizeBytes: 3,
        ),
      ];
      final routeObserver = RouteObserver<ModalRoute<void>>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routeObserver],
          home: _RouteAwareReelsHarness(
            items: items,
            routeObserver: routeObserver,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('first.mp4:active'), findsOneWidget);

      Navigator.of(
        tester.element(find.byType(_RouteAwareReelsHarness)),
      ).push(MaterialPageRoute<void>(builder: (_) => const _SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Theme settings'), findsOneWidget);
      expect(
        find.text('first.mp4:inactive', skipOffstage: false),
        findsOneWidget,
      );

      Navigator.of(tester.element(find.text('Theme settings'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('first.mp4:active'), findsOneWidget);
    },
  );
}

class _RouteAwareReelsHarness extends StatefulWidget {
  const _RouteAwareReelsHarness({
    required this.items,
    required this.routeObserver,
  });

  final List<DaylySportMediaItem> items;
  final RouteObserver<ModalRoute<void>> routeObserver;

  @override
  State<_RouteAwareReelsHarness> createState() =>
      _RouteAwareReelsHarnessState();
}

class _RouteAwareReelsHarnessState extends State<_RouteAwareReelsHarness>
    with RouteAware {
  ModalRoute<dynamic>? _route;
  bool _isScreenActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _route) {
      return;
    }

    if (_route is PageRoute<dynamic>) {
      widget.routeObserver.unsubscribe(this);
    }

    _route = route;
    if (route is PageRoute<dynamic>) {
      widget.routeObserver.subscribe(this, route);
      _isScreenActive = route.isCurrent;
    } else {
      _isScreenActive = true;
    }
  }

  @override
  void dispose() {
    if (_route is PageRoute<dynamic>) {
      widget.routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!mounted || !_isScreenActive) {
      return;
    }
    setState(() {
      _isScreenActive = false;
    });
  }

  @override
  void didPopNext() {
    if (!mounted || _isScreenActive) {
      return;
    }
    setState(() {
      _isScreenActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReelsFeed(
      items: widget.items,
      isScreenActive: _isScreenActive,
      itemBuilder: (context, item, isActive) {
        return Center(
          child: Text(
            '${item.fileName}:${isActive ? 'active' : 'inactive'}',
            textDirection: TextDirection.ltr,
          ),
        );
      },
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Theme settings')));
  }
}
