import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/secure_content/encrypted_image_service.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('encrypted content services', () {
    late Directory tempDir;
    late Directory cacheRoot;
    late Uint8List masterKey;
    late String keyBase64;
    late FileFingerprintCache fingerprintCache;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync(
        'eri_secure_content_services_',
      );
      cacheRoot = Directory('${tempDir.path}${Platform.pathSeparator}cache');
      await cacheRoot.create(recursive: true);
      masterKey = Uint8List.fromList(
        List<int>.generate(32, (index) => (index * 7) % 256),
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

    test('json service decrypts once and reuses cached output', () async {
      final sourceFile = File('${tempDir.path}${Platform.pathSeparator}table.json');
      await sourceFile.writeAsString(
        jsonEncode({
          'competition': 'Premier League',
          'round': 32,
        }),
      );
      final encryptedFile = File('${sourceFile.path}.esj');

      encryptSecureFileSync(
        sourcePath: sourceFile.path,
        destinationPath: encryptedFile.path,
        masterKey: masterKey,
        contentType: SecureContentType.json,
      );

      final service = EncryptedJsonService(
        fingerprintCache: fingerprintCache,
        keyBase64: keyBase64,
        cacheRootProvider: () async => cacheRoot,
      );

      final first = await service.resolvePlaintextFile(encryptedFile);
      expect(first.wasDecrypted, isTrue);
      expect(first.usedCache, isFalse);
      expect(await first.file.readAsString(), await sourceFile.readAsString());

      final second = await service.resolvePlaintextFile(encryptedFile);
      expect(second.wasDecrypted, isFalse);
      expect(second.usedCache, isTrue);
      expect(second.file.path, first.file.path);

      final decoded = await service.readDecodedJson(encryptedFile);
      expect(decoded, isA<Map>());
      expect((decoded as Map)['competition'], 'Premier League');
    });

    test('image service invalidates cache when encrypted source changes', () async {
      final plainFile = File('${tempDir.path}${Platform.pathSeparator}headline.png');
      await plainFile.writeAsBytes(<int>[137, 80, 78, 71, 0, 1, 2, 3]);
      final encryptedFile = File('${plainFile.path}.esi');

      encryptSecureFileSync(
        sourcePath: plainFile.path,
        destinationPath: encryptedFile.path,
        masterKey: masterKey,
        contentType: SecureContentType.image,
      );

      final service = EncryptedImageService(
        fingerprintCache: fingerprintCache,
        keyBase64: keyBase64,
        cacheRootProvider: () async => cacheRoot,
      );

      final first = await service.resolveImageFile(encryptedFile);
      expect(first.wasDecrypted, isTrue);
      final firstPath = first.file.path;
      expect(await first.file.readAsBytes(), await plainFile.readAsBytes());

      await plainFile.writeAsBytes(<int>[137, 80, 78, 71, 9, 8, 7, 6, 5, 4, 3]);
      encryptSecureFileSync(
        sourcePath: plainFile.path,
        destinationPath: encryptedFile.path,
        masterKey: masterKey,
        contentType: SecureContentType.image,
        overwrite: true,
      );

      final second = await service.resolveImageFile(encryptedFile);
      expect(second.wasDecrypted, isTrue);
      expect(second.file.path, isNot(firstPath));
      expect(await second.file.readAsBytes(), await plainFile.readAsBytes());
    });

    test('media service decrypts once and reuses cached playable output', () async {
      final plainFile = File('${tempDir.path}${Platform.pathSeparator}goal.mp4');
      await plainFile.writeAsBytes(
        List<int>.generate(2048, (index) => index % 251),
      );
      final encryptedFile = File('${plainFile.path}.esv');

      encryptMediaFileSync(
        sourcePath: plainFile.path,
        destinationPath: encryptedFile.path,
        masterKey: masterKey,
      );

      final service = EncryptedMediaService(
        fingerprintCache: fingerprintCache,
        mediaKeyBase64: keyBase64,
        cacheRootProvider: () async => cacheRoot,
      );

      final first = await service.resolvePlayableFile(encryptedFile);
      expect(first.wasDecrypted, isTrue);
      expect(first.usedCache, isFalse);
      expect(await first.file.readAsBytes(), await plainFile.readAsBytes());

      final second = await service.resolvePlayableFile(encryptedFile);
      expect(second.wasDecrypted, isFalse);
      expect(second.usedCache, isTrue);
      expect(second.file.path, first.file.path);
    });
  });
}