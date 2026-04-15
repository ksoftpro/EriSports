import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto_config.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ResolvedSecureImage {
  const ResolvedSecureImage({
    required this.file,
    required this.usedCache,
    required this.wasDecrypted,
  });

  final File file;
  final bool usedCache;
  final bool wasDecrypted;
}

class EncryptedImageService {
  EncryptedImageService({
    required FileFingerprintCache fingerprintCache,
    String? keyBase64,
  }) : _fingerprintCache = fingerprintCache,
       _masterKey = decodeSecureContentMasterKey(
         keyBase64 ?? configuredSecureContentKeyBase64(),
       );

  final FileFingerprintCache _fingerprintCache;
  final Uint8List _masterKey;
  final Map<String, Future<ResolvedSecureImage>> _inFlight =
      <String, Future<ResolvedSecureImage>>{};
  Directory? _cacheDirectory;

  Future<void> warmUpCache() async {
    final cacheDirectory = await _getOrCreateCacheDirectory();
    await _deletePartialCacheFiles(cacheDirectory);
  }

  Future<ResolvedSecureImage> resolveImageFile(File sourceFile) {
    final normalizedPath = sourceFile.path;
    if (!isEncryptedImagePath(normalizedPath)) {
      return Future.value(
        ResolvedSecureImage(
          file: sourceFile,
          usedCache: false,
          wasDecrypted: false,
        ),
      );
    }

    return _inFlight.putIfAbsent(normalizedPath, () async {
      final sourceStat = await sourceFile.stat();
      final cacheDirectory = await _getOrCreateCacheDirectory();
      final cachedEntry = _fingerprintCache.read('image', normalizedPath);
      if (cachedEntry != null && cachedEntry.matches(normalizedPath, sourceStat)) {
        final cachedFile = File(cachedEntry.cachePath);
        if (await cachedFile.exists()) {
          return ResolvedSecureImage(
            file: cachedFile,
            usedCache: true,
            wasDecrypted: false,
          );
        }
      }

      final header = await Isolate.run(
        () => readEncryptedSecureContentHeaderFromPath(normalizedPath),
      );
      final sourcePrefix = _sourcePrefixForPath(normalizedPath);
      final cacheBasePrefix = _cacheBasePrefix(sourcePrefix, sourceStat);
      final cacheFile = File(
        p.join(cacheDirectory.path, '$cacheBasePrefix${header.originalExtension}'),
      );

      if (await cacheFile.exists()) {
        await _fingerprintCache.write(
          'image',
          CachedFileFingerprintEntry(
            sourcePath: normalizedPath,
            sizeBytes: sourceStat.size,
            modifiedAtEpochMs:
                sourceStat.modified.toUtc().millisecondsSinceEpoch,
            cachePath: cacheFile.path,
          ),
        );
        return ResolvedSecureImage(
          file: cacheFile,
          usedCache: true,
          wasDecrypted: false,
        );
      }

      await _deleteStaleCacheFiles(cacheDirectory, sourcePrefix);
      if (cachedEntry != null && cachedEntry.cachePath != cacheFile.path) {
        final staleFile = File(cachedEntry.cachePath);
        if (await staleFile.exists()) {
          await staleFile.delete();
        }
      }

      final tempOutput = File('${cacheFile.path}.part');
      if (await tempOutput.exists()) {
        await tempOutput.delete();
      }

      await Isolate.run(
        () => decryptSecureFileSync(
          sourcePath: normalizedPath,
          destinationPath: tempOutput.path,
          masterKey: _masterKey,
          overwrite: true,
        ),
      );

      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      await tempOutput.rename(cacheFile.path);

      await _fingerprintCache.write(
        'image',
        CachedFileFingerprintEntry(
          sourcePath: normalizedPath,
          sizeBytes: sourceStat.size,
          modifiedAtEpochMs: sourceStat.modified.toUtc().millisecondsSinceEpoch,
          cachePath: cacheFile.path,
        ),
      );

      return ResolvedSecureImage(
        file: cacheFile,
        usedCache: false,
        wasDecrypted: true,
      );
    }).whenComplete(() {
      _inFlight.remove(normalizedPath);
    });
  }

  Future<Directory> _getOrCreateCacheDirectory() async {
    if (_cacheDirectory != null) {
      return _cacheDirectory!;
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final dir = Directory(p.join(temporaryDirectory.path, 'eri_sports_image_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDirectory = dir;
    return dir;
  }

  Future<void> _deletePartialCacheFiles(Directory cacheDirectory) async {
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.part')) {
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
      if (name.startsWith('${sourcePrefix}_') && !name.endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  String _sourcePrefixForPath(String sourcePath) {
    return sha256.convert(sourcePath.toLowerCase().codeUnits).toString().substring(0, 16);
  }

  String _cacheBasePrefix(String sourcePrefix, FileStat sourceStat) {
    return '${sourcePrefix}_${sourceStat.size}_${sourceStat.modified.toUtc().millisecondsSinceEpoch}';
  }
}
