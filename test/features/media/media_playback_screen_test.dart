import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/router.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/media_playback_screen.dart';
import 'package:eri_sports/features/media/presentation/video_playback_position_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pauses and disposes video playback when leaving the player', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_media_playback_pause_',
    );
    final originalPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    final routeObserver = RouteObserver<ModalRoute<void>>();
    final item = _buildVideoItem(tempDir, 'goal.mp4');

    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await _clearPathProviderMock();
      await services.database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    await _installPathProviderMock(tempDir);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          appRouteObserverProvider.overrideWithValue(routeObserver),
        ],
        child: MaterialApp(
          navigatorObservers: [routeObserver],
          home: _PlaybackLaunchHarness(item: item),
        ),
      ),
    );

    await tester.tap(find.text('Open playback'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () =>
          find.byType(MediaPlaybackScreen).evaluate().isNotEmpty &&
          fakePlatform.playCalls.isNotEmpty,
    );

    expect(find.byType(MediaPlaybackScreen), findsOneWidget);
    expect(fakePlatform.playCalls, hasLength(1));

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () =>
          find.text('Open playback').evaluate().isNotEmpty &&
          fakePlatform.pauseCalls.isNotEmpty,
    );

    expect(find.text('Open playback'), findsOneWidget);
    expect(fakePlatform.pauseCalls, isNotEmpty);
  });

  testWidgets('restores saved playback position when reopening a video', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_media_playback_resume_',
    );
    final originalPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    final routeObserver = RouteObserver<ModalRoute<void>>();
    final item = _buildVideoItem(tempDir, 'briefing.mp4');
    final store = VideoPlaybackPositionStore(cacheStore: services.cacheStore);

    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await _clearPathProviderMock();
      await services.database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    await _installPathProviderMock(tempDir);
    await store.writePosition(
      item,
      const Duration(seconds: 38),
      duration: const Duration(minutes: 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          appRouteObserverProvider.overrideWithValue(routeObserver),
        ],
        child: MaterialApp(
          navigatorObservers: [routeObserver],
          home: MediaPlaybackScreen(item: item),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntil(
      tester,
      () =>
          fakePlatform.seekCalls.contains(const Duration(seconds: 38)) &&
          fakePlatform.playCalls.isNotEmpty,
    );

    expect(fakePlatform.seekCalls, contains(const Duration(seconds: 38)));
    expect(fakePlatform.playCalls, hasLength(1));
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

class _PlaybackLaunchHarness extends StatelessWidget {
  const _PlaybackLaunchHarness({required this.item});

  final DaylySportMediaItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaPlaybackScreen(item: item),
              ),
            );
          },
          child: const Text('Open playback'),
        ),
      ),
    );
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 1;
  final Map<int, StreamController<VideoEvent>> _eventControllers =
      <int, StreamController<VideoEvent>>{};
  final Map<int, Duration> _positions = <int, Duration>{};
  final List<int> playCalls = <int>[];
  final List<int> pauseCalls = <int>[];
  final List<int> disposeCalls = <int>[];
  final List<Duration> seekCalls = <Duration>[];

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
              size: const Size(1920, 1080),
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
    disposeCalls.add(playerId);
    await _eventControllers.remove(playerId)?.close();
    _positions.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls.add(playerId);
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls.add(playerId);
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
    seekCalls.add(position);
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

DaylySportMediaItem _buildVideoItem(Directory tempDir, String fileName) {
  final file = File('${tempDir.path}${Platform.pathSeparator}$fileName')
    ..writeAsBytesSync(const <int>[1, 2, 3, 4]);
  return DaylySportMediaItem(
    file: file,
    relativePath: 'highlights/$fileName',
    section: DaylySportMediaSection.highlights,
    type: DaylySportMediaType.video,
    lastModified: DateTime.utc(2026, 4, 20, 12),
    sizeBytes: 4,
  );
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