import 'dart:io';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:path/path.dart' as p;

const Set<String> _supportedImageExtensions = {kEncryptedImageExtension};

const Set<String> _supportedVideoExtensions = {kEncryptedMediaExtension};

enum DaylySportMediaSection { reels, highlights, news, updates }

enum DaylySportMediaType { image, video }

const Map<DaylySportMediaSection, List<String>> _sectionDirectories = {
  DaylySportMediaSection.reels: [
    'reels',
    'shorts',
    'short_videos',
    'short-videos',
    'videos',
    'video',
  ],
  DaylySportMediaSection.highlights: ['highlights', 'highlight'],
  DaylySportMediaSection.news: [
    'video-news',
    'video_news',
    'news-videos',
    'news_videos',
    'video/news',
    'videos/news',
  ],
  DaylySportMediaSection.updates: ['updates', 'update'],
};

const Map<DaylySportMediaSection, List<String>> _sectionKeywords = {
  DaylySportMediaSection.reels: ['reel', 'short', 'clip'],
  DaylySportMediaSection.highlights: ['highlight', 'goal'],
  DaylySportMediaSection.news: ['news', 'headline'],
  DaylySportMediaSection.updates: ['update', 'bulletin', 'injury', 'transfer'],
};

class DaylySportMediaItem {
  const DaylySportMediaItem({
    required this.file,
    required this.relativePath,
    required this.section,
    required this.type,
    required this.lastModified,
    required this.sizeBytes,
  });

  final File file;
  final String relativePath;
  final DaylySportMediaSection section;
  final DaylySportMediaType type;
  final DateTime lastModified;
  final int sizeBytes;

  String get fileName => logicalSecureContentFileName(file.path);

  bool get isVideo => type == DaylySportMediaType.video;

  bool get isEncrypted => isEncryptedSecureContentPath(file.path);
}

class DaylySportMediaSectionSnapshot {
  const DaylySportMediaSectionSnapshot({
    required this.section,
    required this.items,
    required this.existingDirectories,
    required this.scannedDirectories,
  });

  final DaylySportMediaSection section;
  final List<DaylySportMediaItem> items;
  final List<String> existingDirectories;
  final List<String> scannedDirectories;

  bool get hasItems => items.isNotEmpty;

  List<DaylySportMediaItem> get videoItems =>
      items.where((item) => item.isVideo).toList(growable: false);

  bool get hasVideoItems => items.any((item) => item.isVideo);

  bool get hasSectionDirectory => existingDirectories.isNotEmpty;
}

class DaylySportMediaSnapshot {
  const DaylySportMediaSnapshot({
    required this.rootDirectory,
    required this.scannedAt,
    required this.sections,
  });

  final Directory rootDirectory;
  final DateTime scannedAt;
  final Map<DaylySportMediaSection, DaylySportMediaSectionSnapshot> sections;

  DaylySportMediaSectionSnapshot section(DaylySportMediaSection section) {
    return sections[section]!;
  }
}

class DaylySportMediaRepository {
  DaylySportMediaRepository({required DaylySportLocator daylySportLocator})
    : _daylySportLocator = daylySportLocator;

  final DaylySportLocator _daylySportLocator;

  DaylySportMediaSnapshot? _cachedSnapshot;
  DateTime? _cachedRootModifiedUtc;

  Future<DaylySportMediaSnapshot> loadSnapshot({
    bool forceRefresh = false,
  }) async {
    final rootDirectory = await _daylySportLocator.getOrCreateDaylySportDirectory();

    if (!forceRefresh && _cachedSnapshot != null) {
      final currentRootModifiedUtc = await _readDirectoryModifiedUtc(rootDirectory);
      if (currentRootModifiedUtc != null &&
          currentRootModifiedUtc == _cachedRootModifiedUtc) {
        return _cachedSnapshot!;
      }
    }

    final snapshot = await _scanRoot(rootDirectory);
    _cachedSnapshot = snapshot;
    _cachedRootModifiedUtc = await _readDirectoryModifiedUtc(rootDirectory);
    return snapshot;
  }

  Future<DaylySportMediaSnapshot> _scanRoot(Directory rootDirectory) async {
    final collected = <DaylySportMediaSection, List<DaylySportMediaItem>>{
      for (final section in DaylySportMediaSection.values)
        section: <DaylySportMediaItem>[],
    };

    await for (final entity in rootDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final extension = p.extension(entity.path).toLowerCase();
      final mediaType = _mediaTypeForExtension(extension);
      if (mediaType == null) {
        continue;
      }

      final relativePath = logicalSecureContentRelativePath(
        entity.path,
        fromDirectory: rootDirectory.path,
      );
      final section = _classifySection(relativePath, mediaType);
      if (section == null) {
        continue;
      }

      try {
        final stat = await entity.stat();
        collected[section]!.add(
          DaylySportMediaItem(
            file: entity,
            relativePath: relativePath,
            section: section,
            type: mediaType,
            lastModified: stat.modified.toUtc(),
            sizeBytes: stat.size,
          ),
        );
      } catch (_) {
        // Skip unreadable files while keeping scan resilient.
      }
    }

    for (final list in collected.values) {
      list.sort((a, b) {
        final modified = b.lastModified.compareTo(a.lastModified);
        if (modified != 0) {
          return modified;
        }
        return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
      });
    }

    final sections = <DaylySportMediaSection, DaylySportMediaSectionSnapshot>{};
    for (final section in DaylySportMediaSection.values) {
      final aliases = _sectionDirectories[section] ?? const <String>[];
      final scannedDirectories = aliases
          .map((alias) => p.join(rootDirectory.path, alias))
          .toList(growable: false);

      final existingDirectories = <String>[];
      for (final path in scannedDirectories) {
        try {
          if (await Directory(path).exists()) {
            existingDirectories.add(path);
          }
        } catch (_) {
          // Ignore invalid directory states.
        }
      }

      sections[section] = DaylySportMediaSectionSnapshot(
        section: section,
        items: collected[section] ?? const <DaylySportMediaItem>[],
        existingDirectories: existingDirectories,
        scannedDirectories: scannedDirectories,
      );
    }

    return DaylySportMediaSnapshot(
      rootDirectory: rootDirectory,
      scannedAt: DateTime.now().toUtc(),
      sections: sections,
    );
  }

  DaylySportMediaType? _mediaTypeForExtension(String extension) {
    if (_supportedImageExtensions.contains(extension)) {
      return DaylySportMediaType.image;
    }
    if (_supportedVideoExtensions.contains(extension)) {
      return DaylySportMediaType.video;
    }
    return null;
  }

  DaylySportMediaSection? _classifySection(
    String relativePath,
    DaylySportMediaType mediaType,
  ) {
    final normalized = relativePath.replaceAll('\\', '/').toLowerCase();
    final fileName = p.basename(normalized);

    for (final section in DaylySportMediaSection.values) {
      if (_matchesSectionByDirectory(normalized, section)) {
        return section;
      }
    }

    for (final section in DaylySportMediaSection.values) {
      if (_matchesSectionByKeyword(fileName, section, mediaType)) {
        return section;
      }
    }

    return null;
  }

  bool _matchesSectionByDirectory(String normalizedPath, DaylySportMediaSection section) {
    final aliases = _sectionDirectories[section] ?? const <String>[];
    for (final alias in aliases) {
      if (normalizedPath.startsWith('$alias/') ||
          normalizedPath.contains('/$alias/')) {
        return true;
      }
    }
    return false;
  }

  bool _matchesSectionByKeyword(
    String fileName,
    DaylySportMediaSection section,
    DaylySportMediaType mediaType,
  ) {
    if (mediaType != DaylySportMediaType.video) {
      return false;
    }
    final keywords = _sectionKeywords[section] ?? const <String>[];
    for (final keyword in keywords) {
      if (fileName.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  Future<DateTime?> _readDirectoryModifiedUtc(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return null;
      }
      return (await directory.stat()).modified.toUtc();
    } catch (_) {
      return null;
    }
  }
}
