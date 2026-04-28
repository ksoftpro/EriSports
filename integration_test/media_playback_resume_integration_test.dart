import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/media_playback_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reopens same video at the persisted position', (tester) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlayerPlatform(
      duration: const Duration(seconds: 100),
    );
    VideoPlayerPlatform.instance = fakePlatform;

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    final tempRoot = Directory.systemTemp.createTempSync(
      'eri_media_resume_integration_',
    );

    addTearDown(() async {
      VideoPlayerPlatform.instance = previousPlatform;
      await tester.pumpWidget(const SizedBox.shrink());
      await services.database.close();
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final item = _buildVideoItem(
      tempRoot: tempRoot,
      fileName: 'highlight_a.mp4',
      relativePath: 'highlights/highlight_a.mp4.esv',
      section: DaylySportMediaSection.highlights,
    );

    await tester.pumpWidget(_PlaybackHarness(services: services, item: item));
    await tester.pumpAndSettle();

    final firstPlayerId = fakePlatform.lastCreatedPlayerId;
    expect(firstPlayerId, isNotNull);

    fakePlatform.setPosition(
      firstPlayerId!,
      const Duration(seconds: 37),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    fakePlatform.clearSeekCalls();

    await tester.pumpWidget(_PlaybackHarness(services: services, item: item));
    await tester.pumpAndSettle();

    final secondPlayerId = fakePlatform.lastCreatedPlayerId;
    expect(secondPlayerId, isNotNull);
    expect(
      fakePlatform.seekCallsForPlayer(secondPlayerId!),
      contains(const Duration(seconds: 37)),
    );
  });

  testWidgets('does not resume when previous position was near completion', (
    tester,
  ) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlayerPlatform(
      duration: const Duration(seconds: 100),
    );
    VideoPlayerPlatform.instance = fakePlatform;

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    final tempRoot = Directory.systemTemp.createTempSync(
      'eri_media_resume_integration_',
    );

    addTearDown(() async {
      VideoPlayerPlatform.instance = previousPlatform;
      await tester.pumpWidget(const SizedBox.shrink());
      await services.database.close();
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final item = _buildVideoItem(
      tempRoot: tempRoot,
      fileName: 'updates_briefing.mp4',
      relativePath: 'updates/updates_briefing.mp4.esv',
      section: DaylySportMediaSection.updates,
    );

    await tester.pumpWidget(_PlaybackHarness(services: services, item: item));
    await tester.pumpAndSettle();

    final firstPlayerId = fakePlatform.lastCreatedPlayerId;
    expect(firstPlayerId, isNotNull);

    fakePlatform.setPosition(
      firstPlayerId!,
      const Duration(seconds: 96),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    fakePlatform.clearSeekCalls();

    await tester.pumpWidget(_PlaybackHarness(services: services, item: item));
    await tester.pumpAndSettle();

    final secondPlayerId = fakePlatform.lastCreatedPlayerId;
    expect(secondPlayerId, isNotNull);
    expect(fakePlatform.seekCallsForPlayer(secondPlayerId!), isEmpty);
  });

  testWidgets('shows playback file metadata for the current video', (tester) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlayerPlatform(
      duration: const Duration(seconds: 100),
    );
    VideoPlayerPlatform.instance = fakePlatform;

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);
    final tempRoot = Directory.systemTemp.createTempSync(
      'eri_media_metadata_integration_',
    );

    addTearDown(() async {
      VideoPlayerPlatform.instance = previousPlatform;
      await tester.pumpWidget(const SizedBox.shrink());
      await services.database.close();
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final item = _buildVideoItem(
      tempRoot: tempRoot,
      fileName: 'matchday_focus.mp4',
      relativePath: 'highlights/matchday_focus.mp4.esv',
      section: DaylySportMediaSection.highlights,
      lastModified: DateTime.utc(2026, 4, 28, 14, 30),
    );

    await tester.pumpWidget(_PlaybackHarness(services: services, item: item));
    await tester.pumpAndSettle();

    expect(find.text('matchday_focus.mp4'), findsWidgets);
    expect(
      find.text(
        DateFormat('MMM d, yyyy • h:mm a').format(item.lastModified.toLocal()),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps resume isolated between highlights and news videos',
    (tester) async {
      final previousPlatform = VideoPlayerPlatform.instance;
      final fakePlatform = _FakeVideoPlayerPlatform(
        duration: const Duration(seconds: 100),
      );
      VideoPlayerPlatform.instance = fakePlatform;

      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final services = await AppServices.create(sharedPreferences: preferences);
      final tempRoot = Directory.systemTemp.createTempSync(
        'eri_media_resume_integration_',
      );

      addTearDown(() async {
        VideoPlayerPlatform.instance = previousPlatform;
        await tester.pumpWidget(const SizedBox.shrink());
        await services.database.close();
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final highlightsItem = _buildVideoItem(
        tempRoot: tempRoot,
        fileName: 'highlight_isolation.mp4',
        relativePath: 'highlights/highlight_isolation.mp4.esv',
        section: DaylySportMediaSection.highlights,
      );
      final newsItem = _buildVideoItem(
        tempRoot: tempRoot,
        fileName: 'news_isolation.mp4',
        relativePath: 'video-news/news_isolation.mp4.esv',
        section: DaylySportMediaSection.news,
      );

      await tester.pumpWidget(
        _PlaybackHarness(services: services, item: highlightsItem),
      );
      await tester.pumpAndSettle();

      final highlightsFirstPlayerId = fakePlatform.lastCreatedPlayerId;
      expect(highlightsFirstPlayerId, isNotNull);

      fakePlatform.setPosition(
        highlightsFirstPlayerId!,
        const Duration(seconds: 42),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      fakePlatform.clearSeekCalls();

      await tester.pumpWidget(_PlaybackHarness(services: services, item: newsItem));
      await tester.pumpAndSettle();

      final newsPlayerId = fakePlatform.lastCreatedPlayerId;
      expect(newsPlayerId, isNotNull);
      expect(fakePlatform.seekCallsForPlayer(newsPlayerId!), isEmpty);

      fakePlatform.clearSeekCalls();

      await tester.pumpWidget(
        _PlaybackHarness(services: services, item: highlightsItem),
      );
      await tester.pumpAndSettle();

      final highlightsSecondPlayerId = fakePlatform.lastCreatedPlayerId;
      expect(highlightsSecondPlayerId, isNotNull);
      expect(
        fakePlatform.seekCallsForPlayer(highlightsSecondPlayerId!),
        contains(const Duration(seconds: 42)),
      );
    },
  );

  testWidgets(
    'keeps resume isolated between two highlights videos',
    (tester) async {
      final previousPlatform = VideoPlayerPlatform.instance;
      final fakePlatform = _FakeVideoPlayerPlatform(
        duration: const Duration(seconds: 100),
      );
      VideoPlayerPlatform.instance = fakePlatform;

      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final services = await AppServices.create(sharedPreferences: preferences);
      final tempRoot = Directory.systemTemp.createTempSync(
        'eri_media_resume_integration_',
      );

      addTearDown(() async {
        VideoPlayerPlatform.instance = previousPlatform;
        await tester.pumpWidget(const SizedBox.shrink());
        await services.database.close();
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final highlightsItemA = _buildVideoItem(
        tempRoot: tempRoot,
        fileName: 'highlight_a_isolation.mp4',
        relativePath: 'highlights/highlight_a_isolation.mp4.esv',
        section: DaylySportMediaSection.highlights,
      );
      final highlightsItemB = _buildVideoItem(
        tempRoot: tempRoot,
        fileName: 'highlight_b_isolation.mp4',
        relativePath: 'highlights/highlight_b_isolation.mp4.esv',
        section: DaylySportMediaSection.highlights,
      );

      await tester.pumpWidget(
        _PlaybackHarness(services: services, item: highlightsItemA),
      );
      await tester.pumpAndSettle();

      final highlightsFirstPlayerId = fakePlatform.lastCreatedPlayerId;
      expect(highlightsFirstPlayerId, isNotNull);

      fakePlatform.setPosition(
        highlightsFirstPlayerId!,
        const Duration(seconds: 28),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      fakePlatform.clearSeekCalls();

      await tester.pumpWidget(
        _PlaybackHarness(services: services, item: highlightsItemB),
      );
      await tester.pumpAndSettle();

      final highlightsBPlayerId = fakePlatform.lastCreatedPlayerId;
      expect(highlightsBPlayerId, isNotNull);
      expect(fakePlatform.seekCallsForPlayer(highlightsBPlayerId!), isEmpty);

      fakePlatform.clearSeekCalls();

      await tester.pumpWidget(
        _PlaybackHarness(services: services, item: highlightsItemA),
      );
      await tester.pumpAndSettle();

      final highlightsSecondPlayerId = fakePlatform.lastCreatedPlayerId;
      expect(highlightsSecondPlayerId, isNotNull);
      expect(
        fakePlatform.seekCallsForPlayer(highlightsSecondPlayerId!),
        contains(const Duration(seconds: 28)),
      );
    },
  );
}

class _PlaybackHarness extends StatelessWidget {
  const _PlaybackHarness({required this.services, required this.item});

  final AppServices services;
  final DaylySportMediaItem item;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: MaterialApp(home: MediaPlaybackScreen(item: item)),
    );
  }
}

DaylySportMediaItem _buildVideoItem({
  required Directory tempRoot,
  required String fileName,
  required String relativePath,
  required DaylySportMediaSection section,
  DateTime? lastModified,
}) {
  final file = File('${tempRoot.path}${Platform.pathSeparator}$fileName')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3, 4, 5]);
  return DaylySportMediaItem(
    file: file,
    relativePath: relativePath,
    section: section,
    type: DaylySportMediaType.video,
    lastModified: (lastModified ?? DateTime.now()).toUtc(),
    sizeBytes: file.lengthSync(),
  );
}

class _SeekCall {
  const _SeekCall({required this.playerId, required this.position});

  final int playerId;
  final Duration position;
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  _FakeVideoPlayerPlatform({required Duration duration}) : _duration = duration;

  final Duration _duration;
  final Map<int, StreamController<VideoEvent>> _eventControllers =
      <int, StreamController<VideoEvent>>{};
  final Map<int, Duration> _positions = <int, Duration>{};
  final List<_SeekCall> _seekCalls = <_SeekCall>[];
  int _nextPlayerId = 1;

  int? lastCreatedPlayerId;

  @override
  Future<void> init() async {
    for (final controller in _eventControllers.values) {
      await controller.close();
    }
    _eventControllers.clear();
    _positions.clear();
    _seekCalls.clear();
    _nextPlayerId = 1;
    lastCreatedPlayerId = null;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    lastCreatedPlayerId = playerId;
    _positions[playerId] = Duration.zero;

    final controller = StreamController<VideoEvent>.broadcast();
    _eventControllers[playerId] = controller;

    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: _duration,
            size: const Size(1920, 1080),
            rotationCorrection: 0,
          ),
        );
      }
    });

    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventControllers[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    _positions.remove(playerId);
    await _eventControllers.remove(playerId)?.close();
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
    _seekCalls.add(_SeekCall(playerId: playerId, position: position));
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  void setPosition(int playerId, Duration position) {
    _positions[playerId] = position;
  }

  List<Duration> seekCallsForPlayer(int playerId) {
    return _seekCalls
        .where((call) => call.playerId == playerId)
        .map((call) => call.position)
        .toList(growable: false);
  }

  void clearSeekCalls() {
    _seekCalls.clear();
  }
}
