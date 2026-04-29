import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/media/presentation/video_playback_position_store.dart';
import 'package:eri_sports/app/navigation/router.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/shared/widgets/secure_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class MediaPlaybackScreen extends ConsumerStatefulWidget {
  const MediaPlaybackScreen({required this.item, super.key});

  final DaylySportMediaItem item;

  @override
  ConsumerState<MediaPlaybackScreen> createState() =>
      _MediaPlaybackScreenState();
}

class _MediaPlaybackScreenState extends ConsumerState<MediaPlaybackScreen>
    with WidgetsBindingObserver, RouteAware {
  late final AppServices _services = ref.read(appServicesProvider);
  late final VideoPlaybackPositionStore _playbackPositionStore = ref.read(
    videoPlaybackPositionStoreProvider,
  );
  late final RouteObserver<ModalRoute<void>> _routeObserver = ref.read(
    appRouteObserverProvider,
  );

  VideoPlayerController? _controller;
  bool _isPreparing = false;
  String? _errorMessage;
  bool _routeVisible = true;
  bool _shouldResumePlayback = false;
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  ModalRoute<dynamic>? _route;
  bool _isSavingPosition = false;
  bool _orientationConfigured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enablePlaybackOrientations());
    if (widget.item.isVideo) {
      _prepareVideo();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _route) {
      return;
    }

    if (_route is PageRoute<dynamic>) {
      _routeObserver.unsubscribe(this);
    }

    _route = route;
    if (route is PageRoute<dynamic>) {
      _routeObserver.subscribe(this, route);
      _routeVisible = route.isCurrent;
    } else {
      _routeVisible = true;
    }

    unawaited(_syncPlaybackWithVisibility());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_route is PageRoute<dynamic>) {
      _routeObserver.unsubscribe(this);
    }
    unawaited(_restoreDefaultOrientations());
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(_pauseAndDisposeController(controller));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state != AppLifecycleState.resumed) {
      unawaited(_persistCurrentPosition());
    }
    unawaited(_syncPlaybackWithVisibility());
  }

  @override
  void didPush() => _handleRouteVisibilityChanged(true);

  @override
  void didPopNext() => _handleRouteVisibilityChanged(true);

  @override
  void didPushNext() => _handleRouteVisibilityChanged(false);

  @override
  void didPop() => _handleRouteVisibilityChanged(false);

  Future<void> _prepareVideo() async {
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      final playable = await _services.encryptedMediaService.resolvePlayableFile(
        widget.item.file,
      );

      final controller = VideoPlayerController.file(File(playable.file.path));
      await controller.initialize();
      await controller.setLooping(true);

      final savedPosition = _playbackPositionStore.readPosition(widget.item);
      if (savedPosition != null &&
          savedPosition > Duration.zero &&
          savedPosition < controller.value.duration) {
        await controller.seekTo(savedPosition);
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previousController = _controller;
      setState(() {
        _controller = controller;
        _isPreparing = false;
      });
      if (previousController != null) {
        unawaited(_pauseAndDisposeController(previousController));
      }

      _shouldResumePlayback = true;
      await _syncPlaybackWithVisibility();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
        _isPreparing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.fileName)),
      body: SafeArea(
        child:
            widget.item.isVideo ? _buildVideoBody(context) : _buildImageBody(),
      ),
    );
  }

  Widget _buildImageBody() {
    return Center(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: SecureFileImage(
          sourceFile: widget.item.file,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildVideoBody(BuildContext context) {
    final controller = _controller;

    if (_isPreparing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('Unable to initialize media playback.'));
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 3),
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () async {
                      _shouldResumePlayback = !controller.value.isPlaying;
                      await _syncPlaybackWithVisibility();
                    },
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _metadataTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _metadataSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleRouteVisibilityChanged(bool isVisible) {
    _routeVisible = isVisible;
    if (!isVisible) {
      unawaited(_persistCurrentPosition());
    }
    unawaited(_syncPlaybackWithVisibility());
  }

  Future<void> _syncPlaybackWithVisibility() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final shouldBePlaying =
        _shouldResumePlayback &&
        _routeVisible &&
        _lifecycleState == AppLifecycleState.resumed;
    if (shouldBePlaying) {
      if (!controller.value.isPlaying) {
        await controller.play();
      }
    } else if (controller.value.isPlaying) {
      await controller.pause();
      await _persistPlaybackPosition(controller);
    } else {
      await _persistPlaybackPosition(controller);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pauseAndDisposeController(
    VideoPlayerController controller,
  ) async {
    if (controller.value.isInitialized && controller.value.isPlaying) {
      await controller.pause();
    }
    await _persistPlaybackPosition(controller);
    await controller.dispose();
  }

  Future<void> _persistCurrentPosition() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await _persistPlaybackPosition(controller);
  }

  Future<void> _persistPlaybackPosition(VideoPlayerController controller) async {
    if (_isSavingPosition || !controller.value.isInitialized) {
      return;
    }

    _isSavingPosition = true;
    try {
      await _playbackPositionStore.writePosition(
        widget.item,
        controller.value.position,
        duration: controller.value.duration,
      );
    } finally {
      _isSavingPosition = false;
    }
  }

  Future<void> _enablePlaybackOrientations() async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _orientationConfigured = true;
  }

  Future<void> _restoreDefaultOrientations() async {
    if (!_orientationConfigured) {
      return;
    }
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    _orientationConfigured = false;
  }

  String get _metadataTitle {
    final fileName = widget.item.fileName.trim();
    return fileName.isEmpty ? 'Offline video' : fileName;
  }

  String get _metadataSubtitle {
    return DateFormat('MMM d, yyyy • h:mm a').format(
      widget.item.lastModified.toLocal(),
    );
  }
}
