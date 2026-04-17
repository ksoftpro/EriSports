import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/decrypted_file_cache_manager.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto_config.dart';
import 'package:eri_sports/data/secure_content/secure_content_isolate_tasks.dart';

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
    int maxConcurrentDecryptions = 1,
    Future<Directory> Function()? cacheRootProvider,
  }) : _masterKey = decodeSecureContentMasterKey(
         keyBase64 ?? configuredSecureContentKeyBase64(),
       ),
       _cacheManager = DecryptedFileCacheManager(
         namespace: 'image',
         cacheDirectoryName: 'eri_sports_image_cache',
         fingerprintCache: fingerprintCache,
         maxConcurrentMaterializations: maxConcurrentDecryptions,
         cacheRootProvider: cacheRootProvider,
       );

  final Uint8List _masterKey;
  final DecryptedFileCacheManager _cacheManager;

  Future<void> warmUpCache() async {
    await _cacheManager.warmUpCache();
  }

  Future<void> clearCache() async {
    await _cacheManager.clearCache();
  }

  Future<ResolvedSecureImage> resolveImageFile(File sourceFile) async {
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

    final cached = await _cacheManager.resolve(
      sourceFile: sourceFile,
      outputExtensionResolver: readSecureFileOriginalExtensionInIsolate,
      materializeToPath: (sourcePath, destinationPath) {
        return runSecureFileDecryptInIsolate(
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          masterKey: _masterKey,
          overwrite: true,
        );
      },
    );

    return ResolvedSecureImage(
      file: cached.file,
      usedCache: cached.usedCache,
      wasDecrypted: cached.wasDecrypted,
    );
  }
}
