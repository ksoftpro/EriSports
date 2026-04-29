import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/reels/presentation/reels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerPlatform originalVideoPlayerPlatform;

  setUp(() {
    originalVideoPlayerPlatform = VideoPlayerPlatform.instance;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalVideoPlayerPlatform;
  });

  testWidgets(
    'keeps reel metadata above the slider and allows smooth seeking',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final services = await AppServices.create(sharedPreferences: preferences);

      final tempDir = Directory.systemTemp.createTempSync(
        'eri_reels_slider_interaction_',
      );
      addTearDown(() async {
        await services.database.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final file = File('${tempDir.path}${Platform.pathSeparator}slider_test.mp4')
        ..writeAsBytesSync(const <int>[1, 2, 3, 4]);
      final item = DaylySportMediaItem(
        file: file,
        relativePath: 'reels/slider_test.mp4',
        section: DaylySportMediaSection.reels,
        type: DaylySportMediaType.video,
        lastModified: DateTime.utc(2026, 4, 29, 12),
        sizeBytes: 4,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appServicesProvider.overrideWithValue(services)],
          child: MaterialApp(
            home: Scaffold(body: ReelsFeed(items: [item], isScreenActive: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(
        const ValueKey<String>('reel-progress-slider'),
      );
      final metadataFinder = find.byKey(
        const ValueKey<String>('reel-metadata-overlay'),
      );
      final currentTimeFinder = find.byKey(
        const ValueKey<String>('reel-progress-current-time'),
      );
      final totalTimeFinder = find.byKey(
        const ValueKey<String>('reel-progress-total-time'),
      );

      expect(sliderFinder.hitTestable(), findsOneWidget);
      expect(metadataFinder, findsOneWidget);
      expect(totalTimeFinder, findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);

      final metadataRect = tester.getRect(metadataFinder);
      final sliderRect = tester.getRect(sliderFinder);
      expect(metadataRect.bottom, lessThan(sliderRect.top));

      final initialSlider = tester.widget<Slider>(sliderFinder);
      expect(initialSlider.value, 0);

      await tester.drag(sliderFinder.hitTestable(), const Offset(140, 0));
      await tester.pumpAndSettle();

      final updatedSlider = tester.widget<Slider>(sliderFinder);
      expect(updatedSlider.value, greaterThan(initialSlider.value));
      expect(tester.widget<Text>(currentTimeFinder).data, isNot('00:00'));
      expect(tester.widget<Text>(totalTimeFinder).data, '02:00');
    },
  );
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  _FakeVideoPlayerPlatform();

  int _nextPlayerId = 1;
  final Map<int, StreamController<VideoEvent>> _eventControllers =
      <int, StreamController<VideoEvent>>{};
  final Map<int, Duration> _positions = <int, Duration>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    _positions[playerId] = Duration.zero;
    late final StreamController<VideoEvent> controller;
    controller = StreamController<VideoEvent>.broadcast(
      onListen: () {
        scheduleMicrotask(() {
          if (controller.isClosed) {
            return;
          }
          controller.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: const Duration(minutes: 2),
              size: const Size(1080, 1920),
            ),
          );
          controller.add(
            VideoEvent(
              eventType: VideoEventType.isPlayingStateUpdate,
              isPlaying: false,
            ),
          );
        });
      },
    );
    _eventControllers[playerId] = controller;
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventControllers[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _eventControllers.remove(playerId)?.close();
    _positions.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  @override
  Widget buildView(int playerId) {
    return const SizedBox.expand();
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> setWebOptions(int playerId, VideoPlayerWebOptions options) async {}
}