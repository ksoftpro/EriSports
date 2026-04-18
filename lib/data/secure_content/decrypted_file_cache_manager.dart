import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CachedDecryptedFile {
  const CachedDecryptedFile({
    required this.file,
    required this.usedCache,
    required this.wasDecrypted,
  });

  final File file;
  final bool usedCache;
  final bool wasDecrypted;
}

class DecryptedFileCacheManager {
  DecryptedFileCacheManager({
    required this.namespace,
    required this.cacheDirectoryName,
    this.fingerprintCache,
    this.maxConcurrentMaterializations,
    Future<Directory> Function()? cacheRootProvider,
  }) : _cacheRootProvider = cacheRootProvider;

  final String namespace;
  final String cacheDirectoryName;
  final FileFingerprintCache? fingerprintCache;
  final int? maxConcurrentMaterializations;
  final Future<Directory> Function()? _cacheRootProvider;

  final Map<String, Future<CachedDecryptedFile>> _inFlight =
      <String, Future<CachedDecryptedFile>>{};
  final Queue<Completer<void>> _materializationWaiters =
      Queue<Completer<void>>();

  Directory? _cacheDirectory;
  int _activeMaterializations = 0;

  Future<void> warmUpCache() async {
    final cacheDirectory = await _getOrCreateCacheDirectory();
    await _deletePartialCacheFiles(cacheDirectory);
  }

  Future<void> clearCache() async {
    final cacheDirectory = await _getOrCreateCacheDirectory();
    if (await cacheDirectory.exists()) {
      await for (final entity in cacheDirectory.list(followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
    await fingerprintCache?.clearNamespace(namespace);
  }

  Future<void> evictSourcePath(String sourcePath) async {
    final inFlight = _inFlight[sourcePath];
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // Ignore failed in-flight work; eviction still needs to run.
      }
    }

    final cacheDirectory = await _getOrCreateCacheDirectory();
    await _deleteCacheFilesForSourcePrefix(
      cacheDirectory,
      sourcePrefixForPath(sourcePath),
    );
    await fingerprintCache?.remove(namespace, sourcePath);
  }

  Future<CachedDecryptedFile> resolve({
    required File sourceFile,
    required Future<String> Function(String sourcePath) outputExtensionResolver,
    required Future<void> Function(String sourcePath, String destinationPath)
    materializeToPath,
    bool enableBasePrefixLookup = true,
  }) {
    final normalizedPath = sourceFile.path;
    return _inFlight
        .putIfAbsent(normalizedPath, () async {
          final sourceStat = await sourceFile.stat();
          final cacheDirectory = await _getOrCreateCacheDirectory();
          final sourcePrefix = sourcePrefixForPath(normalizedPath);
          final cacheBasePrefix = cacheBasePrefixForStat(
            sourcePrefix: sourcePrefix,
            sourceStat: sourceStat,
          );

          final cachedEntry = fingerprintCache?.read(namespace, normalizedPath);
          if (cachedEntry != null &&
              cachedEntry.matches(normalizedPath, sourceStat)) {
            final cachedFile = File(cachedEntry.cachePath);
            if (await cachedFile.exists()) {
              return CachedDecryptedFile(
                file: cachedFile,
                usedCache: true,
                wasDecrypted: false,
              );
            }
          }

          if (enableBasePrefixLookup) {
            final cachedByPrefix = await _findCachedByBasePrefix(
              cacheDirectory,
              cacheBasePrefix,
            );
            if (cachedByPrefix != null) {
              await fingerprintCache?.write(
                namespace,
                CachedFileFingerprintEntry(
                  sourcePath: normalizedPath,
                  sizeBytes: sourceStat.size,
                  modifiedAtEpochMs:
                      sourceStat.modified.toUtc().millisecondsSinceEpoch,
                  cachePath: cachedByPrefix.path,
                ),
              );
              return CachedDecryptedFile(
                file: cachedByPrefix,
                usedCache: true,
                wasDecrypted: false,
              );
            }
          }

          final outputExtension = _normalizeExtension(
            await outputExtensionResolver(normalizedPath),
          );
          final cacheFile = File(
            p.join(cacheDirectory.path, '$cacheBasePrefix$outputExtension'),
          );

          if (await cacheFile.exists()) {
            await fingerprintCache?.write(
              namespace,
              CachedFileFingerprintEntry(
                sourcePath: normalizedPath,
                sizeBytes: sourceStat.size,
                modifiedAtEpochMs:
                    sourceStat.modified.toUtc().millisecondsSinceEpoch,
                cachePath: cacheFile.path,
              ),
            );
            return CachedDecryptedFile(
              file: cacheFile,
              usedCache: true,
              wasDecrypted: false,
            );
          }

          await _runWithMaterializationPermit(() async {
            await _deleteStaleCacheFiles(cacheDirectory, sourcePrefix);
            if (cachedEntry != null &&
                cachedEntry.cachePath != cacheFile.path) {
              final staleFile = File(cachedEntry.cachePath);
              if (await staleFile.exists()) {
                await staleFile.delete();
              }
            }

            final tempOutput = File('${cacheFile.path}.part');
            if (await tempOutput.exists()) {
              await tempOutput.delete();
            }

            try {
              await materializeToPath(normalizedPath, tempOutput.path);

              if (await cacheFile.exists()) {
                await cacheFile.delete();
              }
              await tempOutput.rename(cacheFile.path);
            } catch (_) {
              if (await tempOutput.exists()) {
                await tempOutput.delete();
              }
              rethrow;
            }
          });

          await fingerprintCache?.write(
            namespace,
            CachedFileFingerprintEntry(
              sourcePath: normalizedPath,
              sizeBytes: sourceStat.size,
              modifiedAtEpochMs:
                  sourceStat.modified.toUtc().millisecondsSinceEpoch,
              cachePath: cacheFile.path,
            ),
          );

          return CachedDecryptedFile(
            file: cacheFile,
            usedCache: false,
            wasDecrypted: true,
          );
        })
        .whenComplete(() {
          _inFlight.remove(normalizedPath);
        });
  }

  Future<Directory> _getOrCreateCacheDirectory() async {
    if (_cacheDirectory != null) {
      return _cacheDirectory!;
    }

    final rootDirectory =
        _cacheRootProvider != null
            ? await _cacheRootProvider()
            : await getTemporaryDirectory();
    final dir = Directory(p.join(rootDirectory.path, cacheDirectoryName));
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
      if (entity is File && entity.path.toLowerCase().endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  Future<void> _deleteStaleCacheFiles(
    Directory cacheDirectory,
    String sourcePrefix,
  ) async {
    await _deleteCacheFilesForSourcePrefix(cacheDirectory, sourcePrefix);
  }

  Future<void> _deleteCacheFilesForSourcePrefix(
    Directory cacheDirectory,
    String sourcePrefix,
  ) async {
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final name = p.basename(entity.path);
      if (name.startsWith('${sourcePrefix}_')) {
        await entity.delete();
      }
    }
  }

  Future<T> _runWithMaterializationPermit<T>(
    Future<T> Function() action,
  ) async {
    final maxConcurrent = maxConcurrentMaterializations;
    if (maxConcurrent == null || maxConcurrent <= 0) {
      return action();
    }

    await _acquireMaterializationPermit(maxConcurrent);
    try {
      return await action();
    } finally {
      _releaseMaterializationPermit();
    }
  }

  Future<void> _acquireMaterializationPermit(int maxConcurrent) async {
    if (_activeMaterializations < maxConcurrent) {
      _activeMaterializations += 1;
      return;
    }

    final waiter = Completer<void>();
    _materializationWaiters.addLast(waiter);
    await waiter.future;
  }

  void _releaseMaterializationPermit() {
    if (_materializationWaiters.isNotEmpty) {
      _materializationWaiters.removeFirst().complete();
      return;
    }

    if (_activeMaterializations > 0) {
      _activeMaterializations -= 1;
    }
  }
}

String sourcePrefixForPath(String sourcePath) {
  return sha256
      .convert(utf8.encode(sourcePath.toLowerCase()))
      .toString()
      .substring(0, 16);
}

String cacheBasePrefixForStat({
  required String sourcePrefix,
  required FileStat sourceStat,
}) {
  return '${sourcePrefix}_${sourceStat.size}_${sourceStat.modified.toUtc().millisecondsSinceEpoch}';
}

String _normalizeExtension(String extensionOrPath) {
  final lower = extensionOrPath.trim().toLowerCase();
  if (lower.isEmpty) {
    return '.bin';
  }
  if (lower.startsWith('.')) {
    return lower;
  }
  final dotIndex = lower.lastIndexOf('.');
  if (dotIndex >= 0 && dotIndex < lower.length - 1) {
    return lower.substring(dotIndex);
  }
  return '.$lower';
}
