import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecureFileImage extends ConsumerStatefulWidget {
  const SecureFileImage({
    required this.sourceFile,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.gaplessPlayback = false,
    this.errorBuilder,
    this.loadingWidget,
    super.key,
  });

  final File sourceFile;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Widget? loadingWidget;

  @override
  ConsumerState<SecureFileImage> createState() => _SecureFileImageState();
}

class _SecureFileImageState extends ConsumerState<SecureFileImage> {
  late Future<File> _resolvedFileFuture;

  @override
  void initState() {
    super.initState();
    _resolvedFileFuture = _resolveFile();
  }

  @override
  void didUpdateWidget(covariant SecureFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceFile.path != widget.sourceFile.path) {
      _resolvedFileFuture = _resolveFile();
    }
  }

  Future<File> _resolveFile() async {
    final services = ref.read(appServicesProvider);
    final resolved = await services.secureContentCoordinator.resolveImageFile(
      widget.sourceFile,
    );
    return resolved.file;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _resolvedFileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.file(
            snapshot.requireData,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            alignment: widget.alignment,
            filterQuality: widget.filterQuality,
            gaplessPlayback: widget.gaplessPlayback,
            errorBuilder: widget.errorBuilder,
          );
        }

        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(
              context,
              snapshot.error!,
              snapshot.stackTrace,
            );
          }
          return const Center(child: Icon(Icons.broken_image_outlined));
        }

        return widget.loadingWidget ??
            const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }
}