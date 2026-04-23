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
    this.categoryKey,
    this.categoryLabel,
  });

  final File file;
  final String relativePath;
  final DaylySportMediaSection section;
  final DaylySportMediaType type;
  final DateTime lastModified;
  final int sizeBytes;
  final String? categoryKey;
  final String? categoryLabel;

  String get fileName => logicalSecureContentFileName(file.path);

  bool get isVideo => type == DaylySportMediaType.video;

  bool get isEncrypted => isEncryptedSecureContentPath(file.path);
}

class DaylySportMediaCategoryGroup {
  const DaylySportMediaCategoryGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<DaylySportMediaItem> items;

  bool get hasItems => items.isNotEmpty;
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

  List<DaylySportMediaItem> allVideoItems() {
    return [
      for (final section in DaylySportMediaSection.values)
        if (section != DaylySportMediaSection.reels)
          ...this.section(section).videoItems,
    ];
  }

  List<DaylySportMediaCategoryGroup> videoCategories() {
    return _groupItems(allVideoItems());
  }

  List<DaylySportMediaCategoryGroup> reelCategories() {
    return _groupItems(section(DaylySportMediaSection.reels).videoItems);
  }

  List<DaylySportMediaCategoryGroup> _groupItems(
    Iterable<DaylySportMediaItem> items,
  ) {
    final grouped = <String, _MutableCategoryGroup>{};
    for (final item in items) {
      final key =
          (item.categoryKey != null && item.categoryKey!.trim().isNotEmpty)
              ? item.categoryKey!
              : item.section.name;
      final label =
          (item.categoryLabel != null && item.categoryLabel!.trim().isNotEmpty)
              ? item.categoryLabel!
              : _defaultCategoryLabel(item.section);
      final bucket = grouped.putIfAbsent(
        key,
        () => _MutableCategoryGroup(key: key, label: label),
      );
      bucket.items.add(item);
    }

    return [
      for (final group in grouped.values)
        DaylySportMediaCategoryGroup(
          key: group.key,
          label: group.label,
          items: List<DaylySportMediaItem>.unmodifiable(group.items),
        ),
    ];
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
      final target = _classifyTarget(relativePath, mediaType);
      if (target == null) {
        continue;
      }

      try {
        final stat = await entity.stat();
        collected[target.section]!.add(
          DaylySportMediaItem(
            file: entity,
            relativePath: relativePath,
            section: target.section,
            type: mediaType,
            lastModified: stat.modified.toUtc(),
            sizeBytes: stat.size,
            categoryKey: target.categoryKey,
            categoryLabel: target.categoryLabel,
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

  _ClassifiedMediaTarget? _classifyTarget(
    String relativePath,
    DaylySportMediaType mediaType,
  ) {
    final normalized = relativePath.replaceAll('\\', '/').toLowerCase();
    final fileName = p.basename(normalized);

    if (mediaType != DaylySportMediaType.video) {
      final section = _classifyKnownSection(normalized, fileName, mediaType);
      if (section == null) {
        return null;
      }
      return _ClassifiedMediaTarget(section: section);
    }

    final reelAlias = _matchedDirectoryAlias(normalized, DaylySportMediaSection.reels);
    if (reelAlias != null ||
        _matchesSectionByKeyword(
          fileName,
          DaylySportMediaSection.reels,
          mediaType,
        )) {
      final reelCategory = _deriveReelCategory(normalized, reelAlias);
      return _ClassifiedMediaTarget(
        section: DaylySportMediaSection.reels,
        categoryKey: reelCategory.key,
        categoryLabel: reelCategory.label,
      );
    }

    final legacySection = _classifyKnownSection(normalized, fileName, mediaType);
    final videoCategory = _deriveVideoCategory(normalized, legacySection);
    return _ClassifiedMediaTarget(
      section: legacySection ?? DaylySportMediaSection.highlights,
      categoryKey: videoCategory.key,
      categoryLabel: videoCategory.label,
    );
  }

  DaylySportMediaSection? _classifyKnownSection(
    String normalizedPath,
    String fileName,
    DaylySportMediaType mediaType,
  ) {
    for (final section in DaylySportMediaSection.values) {
      if (_matchesSectionByDirectory(normalizedPath, section)) {
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

  String? _matchedDirectoryAlias(
    String normalizedPath,
    DaylySportMediaSection section,
  ) {
    final aliases = _sectionDirectories[section] ?? const <String>[];
    for (final alias in aliases) {
      if (normalizedPath.startsWith('$alias/') ||
          normalizedPath.contains('/$alias/')) {
        return alias;
      }
    }
    return null;
  }

  bool _matchesSectionByDirectory(String normalizedPath, DaylySportMediaSection section) {
    return _matchedDirectoryAlias(normalizedPath, section) != null;
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

  _MediaCategoryDescriptor _deriveReelCategory(
    String normalizedPath,
    String? matchedAlias,
  ) {
    final segments = normalizedPath.split('/');
    if (segments.length > 1 && matchedAlias != null) {
      final aliasSegments = matchedAlias.split('/');
      for (var index = 0; index < segments.length; index++) {
        final remaining = segments.length - index;
        if (remaining < aliasSegments.length + 1) {
          break;
        }
        final slice = segments.sublist(index, index + aliasSegments.length);
        if (_listEquals(slice, aliasSegments)) {
          final categoryIndex = index + aliasSegments.length;
          if (categoryIndex < segments.length - 1) {
            return _categoryFromSegment(segments[categoryIndex]);
          }
        }
      }
    }

    if (segments.length > 1) {
      return _categoryFromSegment(segments.first);
    }

    return const _MediaCategoryDescriptor(key: 'reels', label: 'Reels');
  }

  _MediaCategoryDescriptor _deriveVideoCategory(
    String normalizedPath,
    DaylySportMediaSection? legacySection,
  ) {
    if (legacySection != null && legacySection != DaylySportMediaSection.reels) {
      return _MediaCategoryDescriptor(
        key: legacySection.name,
        label: _defaultCategoryLabel(legacySection),
      );
    }

    final segments = normalizedPath.split('/');
    if (segments.length > 1) {
      return _categoryFromSegment(segments.first);
    }

    return const _MediaCategoryDescriptor(key: 'videos', label: 'Videos');
  }

  _MediaCategoryDescriptor _categoryFromSegment(String segment) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      return const _MediaCategoryDescriptor(key: 'videos', label: 'Videos');
    }

    final normalized = trimmed.replaceAll('_', ' ').replaceAll('-', ' ');
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final label =
        words.isEmpty
            ? 'Videos'
            : words
                .map(
                  (word) =>
                      word.length == 1
                          ? word.toUpperCase()
                          : '${word[0].toUpperCase()}${word.substring(1)}',
                )
                .join(' ');
    return _MediaCategoryDescriptor(key: trimmed.toLowerCase(), label: label);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}

String _defaultCategoryLabel(DaylySportMediaSection section) {
  switch (section) {
    case DaylySportMediaSection.reels:
      return 'Reels';
    case DaylySportMediaSection.highlights:
      return 'Highlights';
    case DaylySportMediaSection.news:
      return 'News';
    case DaylySportMediaSection.updates:
      return 'Updates';
  }
}

class _MutableCategoryGroup {
  _MutableCategoryGroup({required this.key, required this.label});

  final String key;
  final String label;
  final List<DaylySportMediaItem> items = <DaylySportMediaItem>[];
}

class _ClassifiedMediaTarget {
  const _ClassifiedMediaTarget({
    required this.section,
    this.categoryKey,
    this.categoryLabel,
  });

  final DaylySportMediaSection section;
  final String? categoryKey;
  final String? categoryLabel;
}

class _MediaCategoryDescriptor {
  const _MediaCategoryDescriptor({required this.key, required this.label});

  final String key;
  final String label;
}
