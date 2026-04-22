import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/router.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/video_playback_position_store.dart';
import 'package:eri_sports/shared/widgets/secure_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
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
  VlcPlayerController? _vlcController;
  bool _isPreparing = false;
  String? _errorMessage;
  bool _usedCache = false;
  bool _wasDecrypted = false;
  bool _routeVisible = true;
  bool _shouldResumePlayback = false;
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  ModalRoute<dynamic>? _route;
  bool _isSavingPosition = false;

  bool get _useVlcPlayback => Platform.isAndroid && widget.item.isEncrypted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(_pauseAndDisposeController(controller));
    }

    final vlcController = _vlcController;
    _detachVlcController(vlcController);
    _vlcController = null;
    if (vlcController != null) {
      unawaited(_pauseAndDisposeVlcController(vlcController));
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

      if (_useVlcPlayback) {
        await _prepareVlcVideo(
          playableFile: playable.file,
          usedCache: playable.usedCache,
          wasDecrypted: playable.wasDecrypted,
        );
        return;
      }

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
      final previousVlcController = _vlcController;
      _detachVlcController(previousVlcController);

      setState(() {
        _controller = controller;
        _vlcController = null;
        _usedCache = playable.usedCache;
        _wasDecrypted = playable.wasDecrypted;
        _isPreparing = false;
      });
      if (previousController != null) {
        unawaited(_pauseAndDisposeController(previousController));
      }
      if (previousVlcController != null) {
        unawaited(_pauseAndDisposeVlcController(previousVlcController));
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

  Future<void> _prepareVlcVideo({
    required File playableFile,
    required bool usedCache,
    required bool wasDecrypted,
  }) async {
    final controller = VlcPlayerController.file(
      playableFile,
      autoInitialize: true,
      autoPlay: false,
      allowBackgroundPlayback: false,
      hwAcc: HwAcc.auto,
      options: VlcPlayerOptions(),
    );
    controller.addListener(_handleVlcControllerChanged);

    late final VoidCallback onInit;
    onInit = () {
      controller.removeOnInitListener(onInit);
      unawaited(_handleVlcInitialized(controller));
    };
    controller.addOnInitListener(onInit);

    if (!mounted) {
      _detachVlcController(controller);
      await controller.dispose();
      return;
    }

    final previousController = _controller;
    final previousVlcController = _vlcController;
    _detachVlcController(previousVlcController);

    setState(() {
      _controller = null;
      _vlcController = controller;
      _usedCache = usedCache;
      _wasDecrypted = wasDecrypted;
      _isPreparing = false;
    });

    if (previousController != null) {
      unawaited(_pauseAndDisposeController(previousController));
    }
    if (previousVlcController != null) {
      unawaited(_pauseAndDisposeVlcController(previousVlcController));
    }

    _shouldResumePlayback = true;
  }

  Future<void> _handleVlcInitialized(VlcPlayerController controller) async {
    try {
      await controller.setLooping(true);
      final savedPosition = _playbackPositionStore.readPosition(widget.item);
      final totalDuration = controller.value.duration;
      if (savedPosition != null &&
          savedPosition > Duration.zero &&
          (totalDuration <= Duration.zero || savedPosition < totalDuration)) {
        await controller.seekTo(savedPosition);
      }
      if (!mounted || _vlcController != controller) {
        _detachVlcController(controller);
        await controller.dispose();
        return;
      }
      await _syncPlaybackWithVisibility();
    } catch (error) {
      if (!mounted || _vlcController != controller) {
        _detachVlcController(controller);
        await controller.dispose();
        return;
      }
      setState(() {
        _errorMessage = '$error';
      });
    }
  }

  void _handleVlcControllerChanged() {
    final controller = _vlcController;
    if (!mounted || controller == null) {
      return;
    }
    if (controller.value.hasError) {
      setState(() {
        _errorMessage = controller.value.errorDescription;
      });
      return;
    }
    setState(() {});
  }

  void _detachVlcController(VlcPlayerController? controller) {
    controller?.removeListener(_handleVlcControllerChanged);
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
    if (_useVlcPlayback) {
      return _buildVlcVideoBody(context);
    }

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
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
              const SizedBox(height: 8),
              Row(
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
                    child: Text(
                      _wasDecrypted
                          ? 'Decrypted and cached'
                          : (_usedCache
                              ? 'Playing cached decrypted media'
                              : 'Playing local media'),
                      style: Theme.of(context).textTheme.labelLarge,
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

  Widget _buildVlcVideoBody(BuildContext context) {
    final controller = _vlcController;

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

    if (controller == null) {
      return const Center(child: Text('Unable to initialize media playback.'));
    }

    final value = controller.value;
    final duration = value.duration;
    final position = value.position > duration ? duration : value.position;
    final maxMilliseconds =
        duration > Duration.zero ? duration.inMilliseconds.toDouble() : 1.0;
    final sliderValue =
        duration > Duration.zero
            ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
            : 0.0;
    final aspectRatio = value.aspectRatio > 0 ? value.aspectRatio : (16 / 9);

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VlcPlayer(
                controller: controller,
                aspectRatio: aspectRatio,
                placeholder: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: sliderValue,
                max: maxMilliseconds,
                onChanged: duration > Duration.zero
                    ? (nextValue) {
                        unawaited(
                          controller.seekTo(
                            Duration(milliseconds: nextValue.round()),
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      _shouldResumePlayback = !value.isPlaying;
                      await _syncPlaybackWithVisibility();
                    },
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _wasDecrypted
                          ? 'Decrypted and cached with VLC codec fallback'
                          : (_usedCache
                              ? 'Playing cached decrypted media with VLC codec fallback'
                              : 'Playing local media with VLC codec fallback'),
                      style: Theme.of(context).textTheme.labelLarge,
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
    if (_useVlcPlayback) {
      await _syncVlcPlaybackWithVisibility();
      return;
    }

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

  Future<void> _syncVlcPlaybackWithVisibility() async {
    final controller = _vlcController;
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
      await _persistVlcPlaybackPosition(controller);
    } else {
      await _persistVlcPlaybackPosition(controller);
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

  Future<void> _pauseAndDisposeVlcController(
    VlcPlayerController controller,
  ) async {
    if (controller.value.isInitialized && controller.value.isPlaying) {
      await controller.pause();
    }
    await _persistVlcPlaybackPosition(controller);
    await controller.dispose();
  }

  Future<void> _persistCurrentPosition() async {
    if (_useVlcPlayback) {
      final controller = _vlcController;
      if (controller == null) {
        return;
      }
      await _persistVlcPlaybackPosition(controller);
      return;
    }

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

  Future<void> _persistVlcPlaybackPosition(VlcPlayerController controller) async {
    if (_isSavingPosition || !controller.value.isInitialized) {
      return;
    }

    _isSavingPosition = true;
    try {
      final position = await controller.getPosition();
      await _playbackPositionStore.writePosition(
        widget.item,
        position,
        duration:
            controller.value.duration > Duration.zero
                ? controller.value.duration
                : null,
      );
    } finally {
      _isSavingPosition = false;
    }
  }
}
