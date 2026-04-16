import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DaylySportMediaRepository', () {
    late Directory tempDir;
    late Directory daylySportDir;
    late Uint8List masterKey;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('eri_media_repo_test_');
      daylySportDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}daylySport',
      )..createSync(recursive: true);
      masterKey = Uint8List.fromList(
        List<int>.generate(32, (index) => (index * 17) % 256),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads only encrypted media items for reels and highlights', () async {
      final reelsDir = Directory(
        '${daylySportDir.path}${Platform.pathSeparator}reels',
      )..createSync(recursive: true);
      final highlightsDir = Directory(
        '${daylySportDir.path}${Platform.pathSeparator}highlights',
      )..createSync(recursive: true);

      File('${reelsDir.path}${Platform.pathSeparator}legacy.mp4')
          .writeAsBytesSync(List<int>.generate(256, (index) => index % 251));
      File('${highlightsDir.path}${Platform.pathSeparator}legacy.png')
          .writeAsBytesSync(<int>[137, 80, 78, 71, 1, 2, 3, 4]);

      final sourceVideo = File(
        '${tempDir.path}${Platform.pathSeparator}clip.mp4',
      )..writeAsBytesSync(List<int>.generate(2048, (index) => index % 241));
      final sourceImage = File(
        '${tempDir.path}${Platform.pathSeparator}highlight.png',
      )..writeAsBytesSync(<int>[137, 80, 78, 71, 5, 6, 7, 8, 9]);

      encryptMediaFileSync(
        sourcePath: sourceVideo.path,
        destinationPath: '${reelsDir.path}${Platform.pathSeparator}clip.mp4.esv',
        masterKey: masterKey,
      );
      encryptSecureFileSync(
        sourcePath: sourceImage.path,
        destinationPath:
            '${highlightsDir.path}${Platform.pathSeparator}highlight.png.esi',
        masterKey: masterKey,
        contentType: SecureContentType.image,
      );

      final repository = DaylySportMediaRepository(
        daylySportLocator: _TestDaylySportLocator(daylySportDir),
      );

      final snapshot = await repository.loadSnapshot();
      final reels = snapshot.section(DaylySportMediaSection.reels).items;
      final highlights = snapshot.section(DaylySportMediaSection.highlights).items;

      expect(reels, hasLength(1));
      expect(reels.single.file.path, endsWith('.esv'));
      expect(reels.single.isEncrypted, isTrue);
      expect(highlights, hasLength(1));
      expect(highlights.single.file.path, endsWith('.esi'));
      expect(highlights.single.isEncrypted, isTrue);
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