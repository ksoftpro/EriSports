import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/router.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/shared/widgets/secure_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  VideoPlayerController? _controller;
  bool _isPreparing = false;
  String? _errorMessage;
  bool _usedCache = false;
  bool _wasDecrypted = false;
  bool _routeVisible = true;
  bool _shouldResumePlayback = false;
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  ModalRoute<dynamic>? _route;

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

    final observer = ref.read(appRouteObserverProvider);
    if (_route is PageRoute<dynamic>) {
      observer.unsubscribe(this);
    }

    _route = route;
    if (route is PageRoute<dynamic>) {
      observer.subscribe(this, route);
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
      ref.read(appRouteObserverProvider).unsubscribe(this);
    }
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
      final services = ref.read(appServicesProvider);
      final playable = await services.encryptedMediaService.resolvePlayableFile(
        widget.item.file,
      );

      final controller = VideoPlayerController.file(File(playable.file.path));
      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previousController = _controller;
      setState(() {
        _controller = controller;
        _usedCache = playable.usedCache;
        _wasDecrypted = playable.wasDecrypted;
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

  void _handleRouteVisibilityChanged(bool isVisible) {
    _routeVisible = isVisible;
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
    await controller.dispose();
  }
}
