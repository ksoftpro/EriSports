import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailService {
  VideoThumbnailService({required this.services});

  final AppServices services;
  final Map<String, Future<File?>> _inflight = <String, Future<File?>>{};
  Future<Directory>? _cacheDirectoryFuture;

  Future<File?> resolveThumbnail(
    DaylySportMediaItem item, {
    int maxDimension = 480,
    int quality = 70,
  }) {
    if (!item.isVideo) {
      return Future<File?>.value(null);
    }

    final cacheKey = _cacheKeyFor(item, maxDimension: maxDimension);
    final pending = _inflight[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future = _resolveInternal(
      item,
      cacheKey: cacheKey,
      maxDimension: maxDimension,
      quality: quality,
    );
    _inflight[cacheKey] = future;
    return future.whenComplete(() {
      _inflight.remove(cacheKey);
    });
  }

  Future<File?> _resolveInternal(
    DaylySportMediaItem item, {
    required String cacheKey,
    required int maxDimension,
    required int quality,
  }) async {
    final cacheDir = await _getCacheDirectory();
    final thumbnailFile = File(p.join(cacheDir.path, '$cacheKey.jpg'));
    if (await thumbnailFile.exists()) {
      return thumbnailFile;
    }

    try {
      final playable = await services.encryptedMediaService.resolvePlayableFile(
        item.file,
      );
      final bytes = await VideoThumbnail.thumbnailData(
        video: playable.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxDimension,
        quality: quality,
        timeMs: 350,
      );
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      await thumbnailFile.parent.create(recursive: true);
      await thumbnailFile.writeAsBytes(bytes, flush: true);
      return thumbnailFile;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _getCacheDirectory() {
    final existing = _cacheDirectoryFuture;
    if (existing != null) {
      return existing;
    }

    final future = _createCacheDirectory();
    _cacheDirectoryFuture = future;
    return future;
  }

  Future<Directory> _createCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'eri_sports_video_thumbnails'));
    await dir.create(recursive: true);
    return dir;
  }

  String _cacheKeyFor(DaylySportMediaItem item, {required int maxDimension}) {
    final digest = sha1.convert(
      Uint8List.fromList(
        '$maxDimension|${item.file.path}|${item.lastModified.toUtc().millisecondsSinceEpoch}|${item.sizeBytes}'
            .codeUnits,
      ),
    );
    return digest.toString();
  }
}

final videoThumbnailServiceProvider = Provider<VideoThumbnailService>((ref) {
  final services = ref.read(appServicesProvider);
  return VideoThumbnailService(services: services);
});
