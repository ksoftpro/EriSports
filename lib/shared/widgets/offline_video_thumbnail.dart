import 'dart:io';

import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/video_thumbnail_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineVideoThumbnail extends ConsumerStatefulWidget {
  const OfflineVideoThumbnail({
    required this.item,
    this.fit = BoxFit.cover,
    this.showPlayBadge = true,
    this.borderRadius,
    this.maxDimension = 480,
    super.key,
  });

  final DaylySportMediaItem item;
  final BoxFit fit;
  final bool showPlayBadge;
  final BorderRadius? borderRadius;
  final int maxDimension;

  @override
  ConsumerState<OfflineVideoThumbnail> createState() =>
      _OfflineVideoThumbnailState();
}

class _OfflineVideoThumbnailState extends ConsumerState<OfflineVideoThumbnail> {
  late Future<File?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _resolve();
  }

  @override
  void didUpdateWidget(covariant OfflineVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.file.path != widget.item.file.path ||
        oldWidget.item.lastModified != widget.item.lastModified ||
        oldWidget.item.sizeBytes != widget.item.sizeBytes ||
        oldWidget.maxDimension != widget.maxDimension) {
      _thumbnailFuture = _resolve();
    }
  }

  Future<File?> _resolve() {
    return ref
        .read(videoThumbnailServiceProvider)
        .resolveThumbnail(widget.item, maxDimension: widget.maxDimension);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius;
    final child = FutureBuilder<File?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(file, fit: widget.fit),
              if (widget.showPlayBadge) const _PlayBadge(),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const _VideoThumbnailFallback(),
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
              if (widget.showPlayBadge) const _PlayBadge(),
            ],
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            const _VideoThumbnailFallback(),
            if (widget.showPlayBadge) const _PlayBadge(),
          ],
        );
      },
    );

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}

class _VideoThumbnailFallback extends StatelessWidget {
  const _VideoThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF243145), Color(0xFF121923)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
