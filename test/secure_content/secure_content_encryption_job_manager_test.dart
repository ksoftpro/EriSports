import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_image_service.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_encryption_job_manager.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SecureContentEncryptionJobManager', () {
    late Directory tempDir;
    late Directory daylySportDir;
    late Uint8List masterKey;
    late String keyBase64;
    late FileFingerprintCache fingerprintCache;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('eri_secure_job_test_');
      daylySportDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}daylySport',
      )..createSync(recursive: true);
      masterKey = Uint8List.fromList(
        List<int>.generate(32, (index) => (index * 13) % 256),
      );
      keyBase64 = base64Encode(masterKey);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      fingerprintCache = FileFingerprintCache(
        cacheStore: DaylySportCacheStore(sharedPreferences: preferences),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('streams progress snapshots while encrypting a batch', () async {
      final sourceDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}source',
      )..createSync(recursive: true);
      final jsonFile = File(
        '${sourceDir.path}${Platform.pathSeparator}table.json',
      )..writeAsStringSync(jsonEncode({'league': 'Premier League'}));
      final imageFile = File(
        '${sourceDir.path}${Platform.pathSeparator}badge.png',
      )..writeAsBytesSync(<int>[137, 80, 78, 71, 1, 2, 3, 4, 5, 6, 7, 8]);
      final videoFile = File(
        '${sourceDir.path}${Platform.pathSeparator}goal.mp4',
      )..writeAsBytesSync(
        List<int>.generate(8 * 1024 * 1024, (index) => index % 251),
      );

      final coordinator = DaylysportSecureContentCoordinator(
        daylySportLocator: _TestDaylySportLocator(daylySportDir),
        fileResolver: const EncryptedFileResolver(),
        encryptedJsonService: EncryptedJsonService(
          fingerprintCache: fingerprintCache,
          keyBase64: keyBase64,
          cacheRootProvider: () async => tempDir,
        ),
        encryptedImageService: EncryptedImageService(
          fingerprintCache: fingerprintCache,
          keyBase64: keyBase64,
          cacheRootProvider: () async => tempDir,
        ),
        encryptedMediaService: EncryptedMediaService(
          fingerprintCache: fingerprintCache,
          mediaKeyBase64: keyBase64,
          cacheRootProvider: () async => tempDir,
        ),
        secureContentKeyBase64: keyBase64,
        mediaKeyBase64: keyBase64,
      );
      final manager = SecureContentEncryptionJobManager(
        coordinator: coordinator,
        maxConcurrentWorkers: 2,
      );
      final snapshots = <SecureContentEncryptionJobSnapshot>[];
      final subscription = manager.stream.listen(snapshots.add);

      try {
        final result = await manager.startBatch(
          requests: [
            SecureContentEncryptionRequest(
              requestId: 'json',
              sourcePath: jsonFile.path,
              relativeOutputPath: 'imports/table.json',
            ),
            SecureContentEncryptionRequest(
              requestId: 'image',
              sourcePath: imageFile.path,
              relativeOutputPath: 'news/badge.png',
            ),
            SecureContentEncryptionRequest(
              requestId: 'video',
              sourcePath: videoFile.path,
              relativeOutputPath: 'reels/goal.mp4',
            ),
          ],
        );

        expect(result.encryptedCount, 3);
        expect(result.failedCount, 0);
        expect(result.skippedCount, 0);
        expect(result.manifestPath, isNotNull);
        expect(File(result.manifestPath!).existsSync(), isTrue);
        expect(
          File(
            '${daylySportDir.path}${Platform.pathSeparator}imports${Platform.pathSeparator}table.json.esj',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '${daylySportDir.path}${Platform.pathSeparator}news${Platform.pathSeparator}badge.png.esi',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '${daylySportDir.path}${Platform.pathSeparator}reels${Platform.pathSeparator}goal.mp4.esv',
          ).existsSync(),
          isTrue,
        );

        expect(snapshots, isNotEmpty);
        expect(snapshots.length, greaterThan(2));
        expect(
          snapshots.any(
            (snapshot) => snapshot.items.any(
              (item) =>
                  item.stage == SecureContentEncryptionItemStage.encrypting ||
                  item.stage == SecureContentEncryptionItemStage.writingOutput,
            ),
          ),
          isTrue,
        );

        final finalSnapshot = snapshots.last;
        expect(finalSnapshot.isFinished, isTrue);
        expect(finalSnapshot.isRunning, isFalse);
        expect(finalSnapshot.completedFiles, 3);
        expect(finalSnapshot.failedFiles, 0);
        expect(finalSnapshot.skippedFiles, 0);
        expect(finalSnapshot.percentComplete, 1);
      } finally {
        await subscription.cancel();
        manager.dispose();
      }
    });
  });
}

class _TestDaylySportLocator extends DaylySportLocator {
  _TestDaylySportLocator(this.directory);

  final Directory directory;

  @override
  Future<Directory> getOrCreateDaylySportDirectory() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}