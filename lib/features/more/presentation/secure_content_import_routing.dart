import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:path/path.dart' as p;

const Set<String> _knownSecureVideoDestinationRoots = <String>{
  'reels',
  'shorts',
  'short-videos',
  'short_videos',
  'highlights',
  'highlight',
  'video-news',
  'video_news',
  'news-videos',
  'news_videos',
  'updates',
  'update',
  'video',
  'videos',
};

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

bool secureContentDestinationRootRequired(SecureContentKind kind) {
  switch (kind) {
    case SecureContentKind.json:
    case SecureContentKind.image:
      return true;
    case SecureContentKind.video:
    case SecureContentKind.other:
      return false;
  }
}

String resolveSecureImportRelativeOutputPath({
  required String relativeOutputPath,
  required SecureContentKind kind,
  required String destinationRoot,
}) {
  final normalizedPath = _normalizeSecureImportPath(relativeOutputPath);
  final normalizedRoot = _normalizeSecureImportPath(destinationRoot);

  if (normalizedPath.isEmpty) {
    return normalizedRoot;
  }
  if (normalizedRoot.isEmpty) {
    return normalizedPath;
  }
  if (_pathStartsWithRoot(normalizedPath, normalizedRoot)) {
    return normalizedPath;
  }
  if (kind == SecureContentKind.video && _hasKnownVideoRoot(normalizedPath)) {
    return normalizedPath;
  }
  return p.join(normalizedRoot, normalizedPath).replaceAll('\\', '/');
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
    return resolveSecureImportRelativeOutputPath(
      relativeOutputPath: relativeOutputPath,
      kind: kind,
      destinationRoot: root,
    );
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

String _normalizeSecureImportPath(String rawPath) {
  final normalized = p.normalize(rawPath.trim().replaceAll('\\', '/'));
  return normalized
      .replaceAll('\\', '/')
      .split('/')
      .where(
        (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
      )
      .join('/');
}

bool _pathStartsWithRoot(String path, String root) {
  return path == root || path.startsWith('$root/');
}

bool _hasKnownVideoRoot(String path) {
  final slashIndex = path.indexOf('/');
  final firstSegment = slashIndex >= 0 ? path.substring(0, slashIndex) : path;
  return _knownSecureVideoDestinationRoots.contains(firstSegment);
}
