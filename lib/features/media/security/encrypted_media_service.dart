import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
  EncryptedMediaService({String? mediaKeyBase64})
    : _mediaKey = decodeMediaMasterKey(
        mediaKeyBase64 ?? configuredMediaKeyBase64(),
      );

  final Map<String, Future<ResolvedPlayableMedia>> _inFlight =
      <String, Future<ResolvedPlayableMedia>>{};
  final List<int> _mediaKey;
  Directory? _cacheDirectory;

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

    return _inFlight.putIfAbsent(normalizedPath, () async {
      final sourceStat = await sourceFile.stat();
      final header = await Isolate.run(
        () => readEncryptedMediaHeaderFromPath(normalizedPath),
      );

      final cacheDirectory = await _getOrCreateCacheDirectory();
      final sourcePrefix = _sourcePrefixForPath(normalizedPath);
      final cacheName =
          '${sourcePrefix}_${sourceStat.size}_${sourceStat.modified.millisecondsSinceEpoch}${header.originalExtension}';
      final cacheFile = File(p.join(cacheDirectory.path, cacheName));

      if (await cacheFile.exists()) {
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

      return ResolvedPlayableMedia(
        file: cacheFile,
        usedCache: false,
        wasDecrypted: true,
      );
    }).whenComplete(() {
      _inFlight.remove(normalizedPath);
    });
  }

  Future<void> clearCache() async {
    final cacheDirectory = await _getOrCreateCacheDirectory();
    if (!await cacheDirectory.exists()) {
      return;
    }

    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is File) {
        await entity.delete();
      }
    }
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

  Uint8List _keyBytes() {
    return Uint8List.fromList(_mediaKey);
  }
}
