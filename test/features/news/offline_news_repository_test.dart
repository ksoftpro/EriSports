import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineNewsRepository', () {
    late Directory tempDir;
    late Directory daylySportDir;
    late Uint8List masterKey;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('eri_news_repo_test_');
      daylySportDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}daylySport',
      )..createSync(recursive: true);
      masterKey = Uint8List.fromList(
        List<int>.generate(32, (index) => (index * 5) % 256),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads encrypted news images and ignores legacy plain images', () async {
      final newsDir = Directory(
        '${daylySportDir.path}${Platform.pathSeparator}news',
      )..createSync(recursive: true);

      final plainImage = File(
        '${newsDir.path}${Platform.pathSeparator}legacy.png',
      )..writeAsBytesSync(<int>[137, 80, 78, 71, 1, 2, 3, 4]);

      final sourceDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}source',
      )..createSync(recursive: true);
      final sourceImage = File(
        '${sourceDir.path}${Platform.pathSeparator}headline.png',
      )..writeAsBytesSync(<int>[137, 80, 78, 71, 5, 6, 7, 8, 9, 10]);
      final encryptedImage = File(
        '${newsDir.path}${Platform.pathSeparator}headline.png.esi',
      );

      encryptSecureFileSync(
        sourcePath: sourceImage.path,
        destinationPath: encryptedImage.path,
        masterKey: masterKey,
        contentType: SecureContentType.image,
      );

      final repository = OfflineNewsRepository(
        daylySportLocator: _TestDaylySportLocator(daylySportDir),
      );

      final snapshot = await repository.loadGallery();

      expect(snapshot.newsDirectoryExists, isTrue);
      expect(snapshot.hasImages, isTrue);
      expect(snapshot.images, hasLength(1));
      expect(snapshot.images.single.file.path, encryptedImage.path);
      expect(snapshot.images.single.fileName, 'headline.png');
      expect(snapshot.supportedFormats, <String>['.esi']);
      expect(snapshot.skippedUnsupportedCount, 1);
      expect(snapshot.unreadableCount, 0);
      expect(plainImage.existsSync(), isTrue);
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