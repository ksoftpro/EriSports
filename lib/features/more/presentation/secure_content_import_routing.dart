import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:path/path.dart' as p;

enum SecureContentImportDestinationSlot { json, image, video, reels }

enum SecureVideoImportCategory { video, reels }

extension SecureContentImportDestinationSlotX
    on SecureContentImportDestinationSlot {
  String get label {
    switch (this) {
      case SecureContentImportDestinationSlot.json:
        return 'JSON';
      case SecureContentImportDestinationSlot.image:
        return 'Image';
      case SecureContentImportDestinationSlot.video:
        return 'Video';
      case SecureContentImportDestinationSlot.reels:
        return 'Reels';
    }
  }
}

extension SecureVideoImportCategoryX on SecureVideoImportCategory {
  String get label {
    switch (this) {
      case SecureVideoImportCategory.video:
        return 'Video';
      case SecureVideoImportCategory.reels:
        return 'Reels';
    }
  }

  SecureContentImportDestinationSlot get slot {
    switch (this) {
      case SecureVideoImportCategory.video:
        return SecureContentImportDestinationSlot.video;
      case SecureVideoImportCategory.reels:
        return SecureContentImportDestinationSlot.reels;
    }
  }
}

class SecureContentImportRoutingEntry {
  const SecureContentImportRoutingEntry({
    required this.kind,
    this.videoCategory = SecureVideoImportCategory.video,
  });

  final SecureContentKind kind;
  final SecureVideoImportCategory videoCategory;
}

class SecureContentDestinationRoots {
  const SecureContentDestinationRoots({
    required this.json,
    required this.image,
    required this.video,
    required this.reels,
  });

  final String json;
  final String image;
  final String video;
  final String reels;

  SecureContentImportDestinationSlot slotFor({
    required SecureContentKind kind,
    SecureVideoImportCategory videoCategory = SecureVideoImportCategory.video,
  }) {
    switch (kind) {
      case SecureContentKind.json:
        return SecureContentImportDestinationSlot.json;
      case SecureContentKind.image:
        return SecureContentImportDestinationSlot.image;
      case SecureContentKind.video:
        return videoCategory.slot;
      case SecureContentKind.other:
        return SecureContentImportDestinationSlot.video;
    }
  }

  String rootFor({
    required SecureContentKind kind,
    SecureVideoImportCategory videoCategory = SecureVideoImportCategory.video,
  }) {
    switch (slotFor(kind: kind, videoCategory: videoCategory)) {
      case SecureContentImportDestinationSlot.json:
        return json;
      case SecureContentImportDestinationSlot.image:
        return image;
      case SecureContentImportDestinationSlot.video:
        return video;
      case SecureContentImportDestinationSlot.reels:
        return reels;
    }
  }

  String buildOutputPath({
    required SecureContentKind kind,
    required String relativeOutputPath,
    SecureVideoImportCategory videoCategory = SecureVideoImportCategory.video,
  }) {
    final root = rootFor(kind: kind, videoCategory: videoCategory);
    if (root.isEmpty) {
      return relativeOutputPath.replaceAll('\\', '/');
    }
    return p.join(root, relativeOutputPath).replaceAll('\\', '/');
  }

  List<SecureContentImportDestinationSlot> missingSlotsFor(
    Iterable<SecureContentImportRoutingEntry> entries,
  ) {
    final missing = <SecureContentImportDestinationSlot>{};
    for (final entry in entries) {
      final root = rootFor(
        kind: entry.kind,
        videoCategory: entry.videoCategory,
      );
      if (root.trim().isEmpty) {
        missing.add(
          slotFor(kind: entry.kind, videoCategory: entry.videoCategory),
        );
      }
    }
    return missing.toList(growable: false);
  }
}
