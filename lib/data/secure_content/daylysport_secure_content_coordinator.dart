import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_image_service.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto_config.dart';
import 'package:eri_sports/data/secure_content/secure_content_isolate_tasks.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:eri_sports/features/media/security/media_crypto_config.dart';
import 'package:path/path.dart' as p;

class SecureContentEncryptionRequest {
  const SecureContentEncryptionRequest({
    required this.sourcePath,
    required this.relativeOutputPath,
  });

  final String sourcePath;
  final String relativeOutputPath;
}

class SecureContentEncryptionFailure {
  const SecureContentEncryptionFailure({
    required this.sourcePath,
    required this.message,
  });

  final String sourcePath;
  final String message;
}

class SecureContentEncryptionBatchResult {
  const SecureContentEncryptionBatchResult({
    required this.requestedCount,
    required this.encryptedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.encryptedJsonCount,
    required this.encryptedImageCount,
    required this.encryptedVideoCount,
    required this.outputPaths,
    required this.failures,
    required this.manifestPath,
  });

  final int requestedCount;
  final int encryptedCount;
  final int skippedCount;
  final int failedCount;
  final int encryptedJsonCount;
  final int encryptedImageCount;
  final int encryptedVideoCount;
  final List<String> outputPaths;
  final List<SecureContentEncryptionFailure> failures;
  final String? manifestPath;

  bool get importedJson => encryptedJsonCount > 0;
}

class DaylysportSecureContentCoordinator {
  DaylysportSecureContentCoordinator({
    required this.daylySportLocator,
    required this.fileResolver,
    required this.encryptedJsonService,
    required this.encryptedImageService,
    required this.encryptedMediaService,
    String? secureContentKeyBase64,
    String? mediaKeyBase64,
  }) : _secureContentKey = decodeSecureContentMasterKey(
         secureContentKeyBase64 ?? configuredSecureContentKeyBase64(),
       ),
       _mediaKey = decodeMediaMasterKey(
         mediaKeyBase64 ?? configuredMediaKeyBase64(),
       );

  final DaylySportLocator daylySportLocator;

  final EncryptedFileResolver fileResolver;
  final EncryptedJsonService encryptedJsonService;
  final EncryptedImageService encryptedImageService;
  final EncryptedMediaService encryptedMediaService;
  final Uint8List _secureContentKey;
  final Uint8List _mediaKey;

  Future<void> warmUp() async {
    await Future.wait<void>([
      encryptedJsonService.warmUpCache(),
      encryptedImageService.warmUpCache(),
      encryptedMediaService.warmUpCache(),
    ]);
  }

  Future<void> clearCaches() async {
    await Future.wait<void>([
      encryptedJsonService.clearCache(),
      encryptedImageService.clearCache(),
      encryptedMediaService.clearCache(),
    ]);
  }

  Future<String> readJsonText(File sourceFile) {
    return encryptedJsonService.readTextFile(sourceFile);
  }

  Future<dynamic> readDecodedJson(File sourceFile) {
    return encryptedJsonService.readDecodedJson(sourceFile);
  }

  Future<ResolvedPlainJsonFile> resolveJsonFile(File sourceFile) {
    return encryptedJsonService.resolvePlaintextFile(sourceFile);
  }

  Future<ResolvedSecureImage> resolveImageFile(File sourceFile) {
    return encryptedImageService.resolveImageFile(sourceFile);
  }

  Future<ResolvedPlayableMedia> resolvePlayableMedia(File sourceFile) {
    return encryptedMediaService.resolvePlayableFile(sourceFile);
  }

  Future<SecureContentEncryptionBatchResult> encryptImportedFiles({
    required Iterable<SecureContentEncryptionRequest> requests,
    bool overwrite = true,
  }) async {
    final rootDirectory = await daylySportLocator.getOrCreateDaylySportDirectory();
    final normalizedRequests = requests.toList(growable: false);
    final failures = <SecureContentEncryptionFailure>[];
    final outputPaths = <String>[];
    final manifestEntries = <Map<String, dynamic>>[];
    var encryptedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    var encryptedJsonCount = 0;
    var encryptedImageCount = 0;
    var encryptedVideoCount = 0;

    for (final request in normalizedRequests) {
      final sourcePath = request.sourcePath.trim();
      if (sourcePath.isEmpty) {
        skippedCount += 1;
        continue;
      }

      SecureContentDescriptor descriptor;
      try {
        descriptor = fileResolver.describePath(sourcePath);
      } catch (error) {
        failedCount += 1;
        failures.add(
          SecureContentEncryptionFailure(
            sourcePath: sourcePath,
            message: '$error',
          ),
        );
        continue;
      }

      if (descriptor.isEncrypted || descriptor.kind == SecureContentKind.other) {
        skippedCount += 1;
        continue;
      }

      final normalizedRelativeOutputPath = _normalizeRelativeOutputPath(
        request.relativeOutputPath,
        descriptor.logicalFileName,
      );
      final destinationPath = p.join(
        rootDirectory.path,
        _encryptedRelativePathFor(normalizedRelativeOutputPath, descriptor.kind),
      );

      try {
        await Directory(p.dirname(destinationPath)).create(recursive: true);
        switch (descriptor.kind) {
          case SecureContentKind.json:
            await runSecureFileEncryptInIsolate(
              sourcePath: sourcePath,
              destinationPath: destinationPath,
              masterKey: _secureContentKey,
              contentType: SecureContentType.json,
              overwrite: overwrite,
            );
            encryptedJsonCount += 1;
          case SecureContentKind.image:
            await runSecureFileEncryptInIsolate(
              sourcePath: sourcePath,
              destinationPath: destinationPath,
              masterKey: _secureContentKey,
              contentType: SecureContentType.image,
              overwrite: overwrite,
            );
            encryptedImageCount += 1;
          case SecureContentKind.video:
            await runMediaFileEncryptInIsolate(
              sourcePath: sourcePath,
              destinationPath: destinationPath,
              masterKey: _mediaKey,
              overwrite: overwrite,
            );
            encryptedVideoCount += 1;
          case SecureContentKind.other:
            skippedCount += 1;
            continue;
        }

        encryptedCount += 1;
        outputPaths.add(destinationPath);
        final destinationFile = File(destinationPath);
        manifestEntries.add({
          'sourcePath': sourcePath,
          'encryptedPath': destinationPath,
          'encryptedRelativePath': p.relative(destinationPath, from: rootDirectory.path),
          'logicalPath': normalizedRelativeOutputPath,
          'contentKind': descriptor.kind.name,
          'sourceBytes': await File(sourcePath).length(),
          'encryptedBytes': await destinationFile.length(),
          'encryptedAtUtc': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (error) {
        failedCount += 1;
        failures.add(
          SecureContentEncryptionFailure(
            sourcePath: sourcePath,
            message: '$error',
          ),
        );
      }
    }

    final manifestPath = await _writeImportManifest(
      rootDirectory: rootDirectory,
      entries: manifestEntries,
    );

    return SecureContentEncryptionBatchResult(
      requestedCount: normalizedRequests.length,
      encryptedCount: encryptedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      encryptedJsonCount: encryptedJsonCount,
      encryptedImageCount: encryptedImageCount,
      encryptedVideoCount: encryptedVideoCount,
      outputPaths: outputPaths,
      failures: failures,
      manifestPath: manifestPath,
    );
  }

  Future<String?> _writeImportManifest({
    required Directory rootDirectory,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (entries.isEmpty) {
      return null;
    }

    final manifestDirectory = Directory(
      p.join(rootDirectory.path, 'manifest', 'secure_imports'),
    );
    await manifestDirectory.create(recursive: true);
    final timestamp = DateTime.now().toUtc();
    final file = File(
      p.join(
        manifestDirectory.path,
        'secure_content_import_${timestamp.millisecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'createdAtUtc': timestamp.toIso8601String(),
        'entryCount': entries.length,
        'entries': entries,
      }),
    );
    return file.path;
  }

  String _normalizeRelativeOutputPath(String rawPath, String fallbackFileName) {
    final trimmed = rawPath.trim();
    final candidate = trimmed.isEmpty ? fallbackFileName : trimmed;
    final normalized = p.normalize(candidate.replaceAll('\\', '/'));
    final sanitized = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '.' && segment != '..')
        .join('/');
    return sanitized.isEmpty ? fallbackFileName : sanitized;
  }

  String _encryptedRelativePathFor(String logicalRelativePath, SecureContentKind kind) {
    switch (kind) {
      case SecureContentKind.json:
        return '$logicalRelativePath$kEncryptedJsonExtension';
      case SecureContentKind.image:
        return '$logicalRelativePath$kEncryptedImageExtension';
      case SecureContentKind.video:
        return '$logicalRelativePath$kEncryptedMediaExtension';
      case SecureContentKind.other:
        return logicalRelativePath;
    }
  }
}
