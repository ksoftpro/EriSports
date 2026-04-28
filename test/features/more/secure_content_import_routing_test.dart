import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/features/more/presentation/secure_content_import_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureContentDestinationRoots', () {
    const roots = SecureContentDestinationRoots(
      json: 'json',
      image: 'news',
      video: 'highlights',
      reels: 'reels',
    );

    test('routes regular videos and reels to separate roots', () {
      expect(
        roots.buildOutputPath(
          kind: SecureContentKind.video,
          relativeOutputPath: 'matchday/goal.mp4',
          videoCategory: SecureVideoImportCategory.video,
        ),
        'highlights/matchday/goal.mp4',
      );
      expect(
        roots.buildOutputPath(
          kind: SecureContentKind.video,
          relativeOutputPath: 'matchday/goal.mp4',
          videoCategory: SecureVideoImportCategory.reels,
        ),
        'reels/matchday/goal.mp4',
      );
    });

    test('reports missing slots separately for video and reels', () {
      const incompleteRoots = SecureContentDestinationRoots(
        json: 'json',
        image: 'news',
        video: '',
        reels: 'reels',
      );

      final missing = incompleteRoots
          .missingSlotsFor(const <SecureContentImportRoutingEntry>[
            SecureContentImportRoutingEntry(
              kind: SecureContentKind.video,
              videoCategory: SecureVideoImportCategory.video,
            ),
            SecureContentImportRoutingEntry(
              kind: SecureContentKind.video,
              videoCategory: SecureVideoImportCategory.reels,
            ),
          ]);

      expect(missing, contains(SecureContentImportDestinationSlot.video));
      expect(
        missing,
        isNot(contains(SecureContentImportDestinationSlot.reels)),
      );
    });
  });
}
