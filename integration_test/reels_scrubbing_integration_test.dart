import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/app_shell.dart';
import 'package:eri_sports/app/navigation/router.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:eri_sports/features/reels/presentation/reels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reels player supports visible progress scrubbing', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync(
      'eri_reels_scrubbing_integration_',
    );
    final originalPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    final snapshot = _buildPlainVideoSnapshot(tempDir);

    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await services.database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          appRouteObserverProvider.overrideWithValue(
            RouteObserver<ModalRoute<void>>(),
          ),
          currentShellBranchIndexProvider.overrideWith((ref) => 3),
          appLifecycleStateProvider.overrideWith(
            (ref) => AppLifecycleState.resumed,
          ),
          daylySportMediaSnapshotProvider.overrideWith(
            () => _TestDaylySportMediaSnapshotNotifier(snapshot),
          ),
        ],
        child: const MaterialApp(
          home: ReelsScreen(enableEncryptedPrewarm: false),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntil(
      tester,
      () =>
          fakePlatform.playCalls.isNotEmpty &&
          find.byType(Slider).evaluate().isNotEmpty,
    );

    expect(find.byType(Slider), findsOneWidget);
    fakePlatform.seekCalls.clear();

    await tester.drag(find.byType(Slider), const Offset(180, 0));
    await _pumpUntil(tester, () => fakePlatform.seekCalls.isNotEmpty);

    expect(fakePlatform.seekCalls, isNotEmpty);
    expect(fakePlatform.seekCalls.last, greaterThan(Duration.zero));
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

DaylySportMediaSnapshot _buildPlainVideoSnapshot(Directory tempDir) {
  final file = File('${tempDir.path}${Platform.pathSeparator}resume.mp4')
    ..writeAsBytesSync(const <int>[1, 2, 3, 4]);
  final item = DaylySportMediaItem(
    file: file,
    relativePath: 'reels/resume.mp4',
    section: DaylySportMediaSection.reels,
    type: DaylySportMediaType.video,
    lastModified: DateTime.utc(2026, 4, 20, 10),
    sizeBytes: 4,
  );

  return DaylySportMediaSnapshot(
    rootDirectory: tempDir,
    scannedAt: DateTime.utc(2026, 4, 20, 10),
    sections: {
      DaylySportMediaSection.reels: DaylySportMediaSectionSnapshot(
        section: DaylySportMediaSection.reels,
        items: [item],
        existingDirectories: <String>[tempDir.path],
        scannedDirectories: <String>[tempDir.path],
      ),
      DaylySportMediaSection.highlights: const DaylySportMediaSectionSnapshot(
        section: DaylySportMediaSection.highlights,
        items: <DaylySportMediaItem>[],
        existingDirectories: <String>[],
        scannedDirectories: <String>[],
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
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  _FakeVideoPlayerPlatform();

  int _nextPlayerId = 1;
  final Map<int, StreamController<VideoEvent>> _eventControllers =
      <int, StreamController<VideoEvent>>{};
  final Map<int, Duration> _positions = <int, Duration>{};
  final List<int> playCalls = <int>[];
  final List<int> pauseCalls = <int>[];
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
