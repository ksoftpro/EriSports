import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:eri_sports/features/media/security/media_crypto_config.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  }) : _fingerprintCache = fingerprintCache,
       _mediaKey = decodeMediaMasterKey(
         mediaKeyBase64 ?? configuredMediaKeyBase64(),
       );

  final Map<String, Future<ResolvedPlayableMedia>> _inFlight =
      <String, Future<ResolvedPlayableMedia>>{};
  final FileFingerprintCache? _fingerprintCache;
  final List<int> _mediaKey;
  Directory? _cacheDirectory;

  Future<void> warmUpCache() async {
    final cacheDirectory = await _getOrCreateCacheDirectory();
    await _deletePartialCacheFiles(cacheDirectory);
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

    return _inFlight
        .putIfAbsent(normalizedPath, () async {
          final sourceStat = await sourceFile.stat();
          final cacheDirectory = await _getOrCreateCacheDirectory();
          final sourcePrefix = _sourcePrefixForPath(normalizedPath);
          final cacheBasePrefix = _cacheBasePrefix(sourcePrefix, sourceStat);

          final cachedEntry = _fingerprintCache?.read('media', normalizedPath);
          if (cachedEntry != null &&
              cachedEntry.matches(normalizedPath, sourceStat)) {
            final cachedFile = File(cachedEntry.cachePath);
            if (await cachedFile.exists()) {
              return ResolvedPlayableMedia(
                file: cachedFile,
                usedCache: true,
                wasDecrypted: false,
              );
            }
          }

          final cachedByPrefix = await _findCachedByBasePrefix(
            cacheDirectory,
            cacheBasePrefix,
          );
          if (cachedByPrefix != null) {
            await _fingerprintCache?.write(
              'media',
              CachedFileFingerprintEntry(
                sourcePath: normalizedPath,
                sizeBytes: sourceStat.size,
                modifiedAtEpochMs:
                    sourceStat.modified.toUtc().millisecondsSinceEpoch,
                cachePath: cachedByPrefix.path,
              ),
            );
            return ResolvedPlayableMedia(
              file: cachedByPrefix,
              usedCache: true,
              wasDecrypted: false,
            );
          }

          final header = await Isolate.run(
            () => readEncryptedMediaHeaderFromPath(normalizedPath),
          );

          final cacheName = '$cacheBasePrefix${header.originalExtension}';
          final cacheFile = File(p.join(cacheDirectory.path, cacheName));

          if (await cacheFile.exists()) {
            await _fingerprintCache?.write(
              'media',
              CachedFileFingerprintEntry(
                sourcePath: normalizedPath,
                sizeBytes: sourceStat.size,
                modifiedAtEpochMs:
                    sourceStat.modified.toUtc().millisecondsSinceEpoch,
                cachePath: cacheFile.path,
              ),
            );
            return ResolvedPlayableMedia(
              file: cacheFile,
              usedCache: true,
              wasDecrypted: false,
            );
          }

          await _deleteStaleCacheFiles(cacheDirectory, sourcePrefix);

          final tempOutput = File('${cacheFile.path}.part');
          if (await tempOutput.exists()) {
            await tempOutput.delete();
          }

          await Isolate.run(
            () => decryptMediaFileSync(
              sourcePath: normalizedPath,
              destinationPath: tempOutput.path,
              masterKey: _keyBytes(),
              overwrite: true,
            ),
          );

          if (await cacheFile.exists()) {
            await cacheFile.delete();
          }
          await tempOutput.rename(cacheFile.path);

          await _fingerprintCache?.write(
            'media',
            CachedFileFingerprintEntry(
              sourcePath: normalizedPath,
              sizeBytes: sourceStat.size,
              modifiedAtEpochMs:
                  sourceStat.modified.toUtc().millisecondsSinceEpoch,
              cachePath: cacheFile.path,
            ),
          );

          return ResolvedPlayableMedia(
            file: cacheFile,
            usedCache: false,
            wasDecrypted: true,
          );
        })
        .whenComplete(() {
          _inFlight.remove(normalizedPath);
        });
  }

  Future<void> clearCache() async {
    final cacheDirectory = await _getOrCreateCacheDirectory();
    if (!await cacheDirectory.exists()) {
      await _fingerprintCache?.clearNamespace('media');
      return;
    }

    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is File) {
        await entity.delete();
      }
    }

    await _fingerprintCache?.clearNamespace('media');
  }

  Future<Directory> _getOrCreateCacheDirectory() async {
    if (_cacheDirectory != null) {
      return _cacheDirectory!;
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final dir = Directory(
      p.join(temporaryDirectory.path, 'eri_sports_media_cache'),
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _cacheDirectory = dir;
    return dir;
  }

  Future<File?> _findCachedByBasePrefix(
    Directory cacheDirectory,
    String cacheBasePrefix,
  ) async {
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final name = p.basename(entity.path);
      if (name.startsWith(cacheBasePrefix) && !name.endsWith('.part')) {
        return entity;
      }
    }
    return null;
  }

  Future<void> _deletePartialCacheFiles(Directory cacheDirectory) async {
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      if (entity.path.toLowerCase().endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  Future<void> _deleteStaleCacheFiles(
    Directory cacheDirectory,
    String sourcePrefix,
  ) async {
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final name = p.basename(entity.path);
      if (name.startsWith('${sourcePrefix}_') ||
          name.startsWith('$sourcePrefix.')) {
        await entity.delete();
      }
    }
  }

  String _sourcePrefixForPath(String sourcePath) {
    final digest = sha256.convert(utf8.encode(sourcePath.toLowerCase()));
    return digest.toString().substring(0, 16);
  }

  String _cacheBasePrefix(String sourcePrefix, FileStat sourceStat) {
    return '${sourcePrefix}_${sourceStat.size}_${sourceStat.modified.millisecondsSinceEpoch}';
  }

  Uint8List _keyBytes() {
    return Uint8List.fromList(_mediaKey);
  }
}
