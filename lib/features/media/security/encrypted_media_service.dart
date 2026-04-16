import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/decrypted_file_cache_manager.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_isolate_tasks.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:eri_sports/features/media/security/media_crypto_config.dart';

class ResolvedPlayableMedia {
  const ResolvedPlayableMedia({
    required this.file,
    required this.usedCache,
    required this.wasDecrypted,
  });

  final File file;
  final bool usedCache;
  final bool wasDecrypted;
}

class EncryptedMediaService {
  EncryptedMediaService({
    String? mediaKeyBase64,
    FileFingerprintCache? fingerprintCache,
    Future<Directory> Function()? cacheRootProvider,
  }) : _mediaKey = decodeMediaMasterKey(
         mediaKeyBase64 ?? configuredMediaKeyBase64(),
       ),
       _cacheManager = DecryptedFileCacheManager(
         namespace: 'media',
         cacheDirectoryName: 'eri_sports_media_cache',
         fingerprintCache: fingerprintCache,
         cacheRootProvider: cacheRootProvider,
       );

  final Uint8List _mediaKey;
  final DecryptedFileCacheManager _cacheManager;

  Future<void> warmUpCache() async {
    await _cacheManager.warmUpCache();
  }

  Future<void> prewarmPlayableFiles(
    Iterable<File> sourceFiles, {
    int maxItems = 6,
  }) async {
    if (maxItems <= 0) {
      return;
    }

    var warmed = 0;
    for (final file in sourceFiles) {
      if (warmed >= maxItems) {
        break;
      }
      final sourcePath = file.path;
      if (!isEncryptedMediaPath(sourcePath)) {
        continue;
      }

      warmed += 1;
      try {
        await resolvePlayableFile(file);
      } catch (_) {
        // Keep prewarm best-effort so UI playback flow remains resilient.
      }
    }
  }

  Future<void> prewarmPlayableFile(File sourceFile) async {
    if (!isEncryptedMediaPath(sourceFile.path)) {
      return;
    }
    try {
      await resolvePlayableFile(sourceFile);
    } catch (_) {
      // Keep prewarm best-effort so UI playback flow remains resilient.
    }
  }

  Future<ResolvedPlayableMedia> resolvePlayableFile(File sourceFile) {
    final normalizedPath = sourceFile.path;

    if (!isEncryptedMediaPath(normalizedPath)) {
      return Future.value(
        ResolvedPlayableMedia(
          file: sourceFile,
          usedCache: false,
          wasDecrypted: false,
        ),
      );
    }

    return _cacheManager.resolve(
      sourceFile: sourceFile,
      outputExtensionResolver: readMediaFileOriginalExtensionInIsolate,
      materializeToPath: (sourcePath, destinationPath) {
        return runMediaFileDecryptInIsolate(
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          masterKey: _mediaKey,
          overwrite: true,
        );
      },
    ).then((cached) {
      return ResolvedPlayableMedia(
        file: cached.file,
        usedCache: cached.usedCache,
        wasDecrypted: cached.wasDecrypted,
      );
    });
  }

  Future<void> clearCache() async {
    await _cacheManager.clearCache();
  }
}
