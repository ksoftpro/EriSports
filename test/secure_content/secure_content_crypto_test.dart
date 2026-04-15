import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('secure content crypto', () {
    late Directory tempDir;
    final masterKey = Uint8List.fromList(
      List<int>.generate(32, (index) => index),
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('eri_secure_content_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('encrypts and decrypts json payloads', () {
      final sourceFile = File('${tempDir.path}${Platform.pathSeparator}payload.json');
      sourceFile.writeAsStringSync(jsonEncode({'league': 'Premier League'}));

      final encryptedFile = File('${sourceFile.path}.esj');
      final decryptedFile = File('${tempDir.path}${Platform.pathSeparator}payload.out.json');

      final encryptionResult = encryptSecureFileSync(
        sourcePath: sourceFile.path,
        destinationPath: encryptedFile.path,
        masterKey: masterKey,
        contentType: SecureContentType.json,
      );

      final header = readEncryptedSecureContentHeaderFromPath(encryptedFile.path);

      expect(encryptionResult.sourceBytes, greaterThan(0));
      expect(header.contentType, SecureContentType.json);
      expect(header.originalExtension, '.json');

      decryptSecureFileSync(
        sourcePath: encryptedFile.path,
        destinationPath: decryptedFile.path,
        masterKey: masterKey,
      );

      expect(decryptedFile.readAsStringSync(), sourceFile.readAsStringSync());
    });

    test('encrypts and decrypts image-like binary payloads', () {
      final sourceFile = File('${tempDir.path}${Platform.pathSeparator}image.png');
      sourceFile.writeAsBytesSync(<int>[137, 80, 78, 71, 0, 1, 2, 3, 4, 5]);

      final encryptedFile = File('${sourceFile.path}.esi');
      final decryptedFile = File('${tempDir.path}${Platform.pathSeparator}image.out.png');

      final encryptionResult = encryptSecureFileSync(
        sourcePath: sourceFile.path,
        destinationPath: encryptedFile.path,
        masterKey: masterKey,
        contentType: SecureContentType.image,
      );

      final header = readEncryptedSecureContentHeaderFromPath(encryptedFile.path);

      expect(encryptionResult.outputBytes, greaterThan(encryptionResult.sourceBytes));
      expect(header.contentType, SecureContentType.image);
      expect(header.originalExtension, '.png');

      decryptSecureFileSync(
        sourcePath: encryptedFile.path,
        destinationPath: decryptedFile.path,
        masterKey: masterKey,
      );

      expect(decryptedFile.readAsBytesSync(), sourceFile.readAsBytesSync());
    });
  });
}