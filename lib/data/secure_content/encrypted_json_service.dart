import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/decrypted_file_cache_manager.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto_config.dart';
import 'package:eri_sports/data/secure_content/secure_content_isolate_tasks.dart';

class ResolvedPlainJsonFile {
  const ResolvedPlainJsonFile({
    required this.file,
    required this.usedCache,
    required this.wasDecrypted,
  });

  final File file;
  final bool usedCache;
  final bool wasDecrypted;
}

class EncryptedJsonService {
  EncryptedJsonService({
    required FileFingerprintCache fingerprintCache,
    String? keyBase64,
    Future<Directory> Function()? cacheRootProvider,
  }) : _masterKey = decodeSecureContentMasterKey(
         keyBase64 ?? configuredSecureContentKeyBase64(),
       ),
       _cacheManager = DecryptedFileCacheManager(
         namespace: 'json',
         cacheDirectoryName: 'eri_sports_json_cache',
         fingerprintCache: fingerprintCache,
         cacheRootProvider: cacheRootProvider,
       );

  final Uint8List _masterKey;
  final DecryptedFileCacheManager _cacheManager;
  final Map<String, _DecodedJsonCacheEntry> _decodedCache =
      <String, _DecodedJsonCacheEntry>{};

  Future<void> warmUpCache() async {
    await _cacheManager.warmUpCache();
  }

  Future<void> clearCache() async {
    _decodedCache.clear();
    await _cacheManager.clearCache();
  }

  Future<void> evictSourceFile(File sourceFile) async {
    final sourcePrefix = sourcePrefixForPath(sourceFile.path);
    _decodedCache.removeWhere((key, _) => key.startsWith('${sourcePrefix}_'));
    await _cacheManager.evictSourcePath(sourceFile.path);
  }

  Future<ResolvedPlainJsonFile> resolvePlaintextFile(File sourceFile) async {
    final normalizedPath = sourceFile.path;
    if (!isEncryptedJsonPath(normalizedPath)) {
      return Future.value(
        ResolvedPlainJsonFile(
          file: sourceFile,
          usedCache: false,
          wasDecrypted: false,
        ),
      );
    }

    final cached = await _cacheManager.resolve(
      sourceFile: sourceFile,
      outputExtensionResolver: (_) => Future<String>.value('.json'),
      materializeToPath: (sourcePath, destinationPath) {
        return runSecureFileDecryptInIsolate(
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          masterKey: _masterKey,
          overwrite: true,
        );
      },
    );

    return ResolvedPlainJsonFile(
      file: cached.file,
      usedCache: cached.usedCache,
      wasDecrypted: cached.wasDecrypted,
    );
  }

  Future<String> readTextFile(File sourceFile) async {
    final resolved = await resolvePlaintextFile(sourceFile);
    return resolved.file.readAsString();
  }

  Future<dynamic> readDecodedJson(File sourceFile) async {
    final sourceStat = await sourceFile.stat();
    final cacheKey = _decodedCacheKey(sourceFile.path, sourceStat);
    final cached = _decodedCache[cacheKey];
    if (cached != null) {
      return cached.decoded;
    }

    final raw = await readTextFile(sourceFile);
    final decoded = await runJsonDecodeInIsolate(raw);
    _decodedCache[cacheKey] = _DecodedJsonCacheEntry(decoded: decoded);
    return decoded;
  }

  String _decodedCacheKey(String sourcePath, FileStat sourceStat) {
    return cacheBasePrefixForStat(
      sourcePrefix: sourcePrefixForPath(sourcePath),
      sourceStat: sourceStat,
    );
  }
}

class _DecodedJsonCacheEntry {
  const _DecodedJsonCacheEntry({required this.decoded});

  final dynamic decoded;
}
