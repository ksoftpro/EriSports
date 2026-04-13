import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class MediaPlaybackScreen extends ConsumerStatefulWidget {
  const MediaPlaybackScreen({required this.item, super.key});

  final DaylySportMediaItem item;

  @override
  ConsumerState<MediaPlaybackScreen> createState() => _MediaPlaybackScreenState();
}

class _MediaPlaybackScreenState extends ConsumerState<MediaPlaybackScreen> {
  VideoPlayerController? _controller;
  bool _isPreparing = false;
  String? _errorMessage;
  bool _usedCache = false;
  bool _wasDecrypted = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _prepareVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller?.dispose();
        _controller = controller;
        _usedCache = playable.usedCache;
        _wasDecrypted = playable.wasDecrypted;
        _isPreparing = false;
      });
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
      appBar: AppBar(
        title: Text(widget.item.fileName),
      ),
      body: SafeArea(
        child: widget.item.isVideo ? _buildVideoBody(context) : _buildImageBody(),
      ),
    );
  }

  Widget _buildImageBody() {
    return Center(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Image.file(widget.item.file, fit: BoxFit.contain),
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
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
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
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      if (mounted) {
                        setState(() {});
                      }
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
}
