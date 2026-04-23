import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/features/more/presentation/secure_content_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSecureImportRelativeOutputPath', () {
    test('keeps existing reel-rooted paths without duplicating the destination', () {
      final resolved = resolveSecureImportRelativeOutputPath(
        relativeOutputPath: 'reels/premier_league/goal.mp4',
        kind: SecureContentKind.video,
        destinationRoot: 'reels',
      );

      expect(resolved, 'reels/premier_league/goal.mp4');
    });

    test('keeps existing dynamic video roots even when a different destination is selected', () {
      final resolved = resolveSecureImportRelativeOutputPath(
        relativeOutputPath: 'highlights/transfers/clip.mp4',
        kind: SecureContentKind.video,
        destinationRoot: 'reels',
      );

      expect(resolved, 'highlights/transfers/clip.mp4');
    });

    test('prefixes unrooted reel category folders when a reel destination is provided', () {
      final resolved = resolveSecureImportRelativeOutputPath(
        relativeOutputPath: 'premier_league/goal.mp4',
        kind: SecureContentKind.video,
        destinationRoot: 'reels',
      );

      expect(resolved, 'reels/premier_league/goal.mp4');
    });

    test('preserves unrooted dynamic video categories when destination is empty', () {
      final resolved = resolveSecureImportRelativeOutputPath(
        relativeOutputPath: 'transfers/clip.mp4',
        kind: SecureContentKind.video,
        destinationRoot: '',
      );

      expect(resolved, 'transfers/clip.mp4');
    });

    test('avoids duplicate non-video destination prefixes too', () {
      final resolved = resolveSecureImportRelativeOutputPath(
        relativeOutputPath: 'news/badge.png',
        kind: SecureContentKind.image,
        destinationRoot: 'news',
      );

      expect(resolved, 'news/badge.png');
    });
  });

  group('secureContentDestinationRootRequired', () {
    test('does not require a destination root for video imports', () {
      expect(
        secureContentDestinationRootRequired(SecureContentKind.video),
        isFalse,
      );
    });

    test('still requires destination roots for json and images', () {
      expect(
        secureContentDestinationRootRequired(SecureContentKind.json),
        isTrue,
      );
      expect(
        secureContentDestinationRootRequired(SecureContentKind.image),
        isTrue,
      );
    });
  });
}