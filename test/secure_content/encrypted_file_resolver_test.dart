import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encrypted file resolver', () {
    test('strips encrypted suffixes back to logical filenames', () {
      expect(
        logicalSecureContentFileName(r'D:\daylySport\fixtures_full_data.json.esj'),
        'fixtures_full_data.json',
      );
      expect(
        logicalSecureContentFileName(r'D:\daylySport\news\headline.png.esi'),
        'headline.png',
      );
      expect(
        logicalSecureContentFileName(r'D:\daylySport\reels\clip.mp4.esv'),
        'clip.mp4',
      );
    });

    test('recognizes supported encrypted content types', () {
      expect(isSupportedSecureJsonPath('table.json'), isTrue);
      expect(isSupportedSecureJsonPath('table.json.esj'), isTrue);
      expect(isSupportedSecureImagePath('headline.jpg'), isTrue);
      expect(isSupportedSecureImagePath('headline.jpg.esi'), isTrue);
      expect(isSupportedSecureVideoPath('goal.mp4'), isTrue);
      expect(isSupportedSecureVideoPath('goal.mp4.esv'), isTrue);
      expect(secureContentKindForPath('goal.mp4.esv'), SecureContentKind.video);
      expect(secureContentKindForPath('headline.jpg.esi'), SecureContentKind.image);
      expect(secureContentKindForPath('table.json.esj'), SecureContentKind.json);
    });

    test('builds preferred candidate paths for logical json files', () {
      expect(
        candidateSecureJsonPaths(r'D:\daylySport\standings.json'),
        <String>[
          r'D:\daylySport\standings.json',
          r'D:\daylySport\standings.json.esj',
        ],
      );
    });
  });
}