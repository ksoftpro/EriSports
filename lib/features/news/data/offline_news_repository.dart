import 'dart:io';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:path/path.dart' as p;

const Set<String> _supportedImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
  kEncryptedImageExtension,
};

class OfflineNewsMediaItem {
  const OfflineNewsMediaItem({
    required this.file,
    required this.lastModified,
    required this.sizeBytes,
  });

  final File file;
  final DateTime lastModified;
  final int sizeBytes;

  String get fileName => logicalSecureContentFileName(file.path);
}

class OfflineNewsGallerySnapshot {
  const OfflineNewsGallerySnapshot({
    required this.rootDirectory,
    required this.newsDirectory,
    required this.images,
    required this.supportedFormats,
    required this.skippedUnsupportedCount,
    required this.unreadableCount,
    required this.scannedAt,
    required this.newsDirectoryExists,
  });

  final Directory rootDirectory;
  final Directory newsDirectory;
  final List<OfflineNewsMediaItem> images;
  final List<String> supportedFormats;
  final int skippedUnsupportedCount;
  final int unreadableCount;
  final DateTime scannedAt;
  final bool newsDirectoryExists;

  bool get hasImages => images.isNotEmpty;
}

class OfflineNewsRepository {
  OfflineNewsRepository({required DaylySportLocator daylySportLocator})
    : _daylySportLocator = daylySportLocator;

  final DaylySportLocator _daylySportLocator;

  OfflineNewsGallerySnapshot? _cachedSnapshot;
  DateTime? _cachedNewsDirectoryModifiedUtc;

  Future<OfflineNewsGallerySnapshot> loadGallery({
    bool forceRefresh = false,
  }) async {
    final rootDirectory = await _daylySportLocator.getOrCreateDaylySportDirectory();
    final newsDirectory = Directory(p.join(rootDirectory.path, 'news'));

    if (!forceRefresh && _cachedSnapshot != null) {
      final currentModifiedUtc = await _readDirectoryModifiedUtc(newsDirectory);
      if (currentModifiedUtc != null &&
          currentModifiedUtc == _cachedNewsDirectoryModifiedUtc) {
        return _cachedSnapshot!;
      }
      if (currentModifiedUtc == null && !_cachedSnapshot!.newsDirectoryExists) {
        return _cachedSnapshot!;
      }
    }

    final snapshot = await _scanNewsDirectory(rootDirectory, newsDirectory);
    _cachedSnapshot = snapshot;
    _cachedNewsDirectoryModifiedUtc = await _readDirectoryModifiedUtc(newsDirectory);
    return snapshot;
  }

  Future<OfflineNewsGallerySnapshot> _scanNewsDirectory(
    Directory rootDirectory,
    Directory newsDirectory,
  ) async {
    final directoryExists = await newsDirectory.exists();
    if (!directoryExists) {
      return OfflineNewsGallerySnapshot(
        rootDirectory: rootDirectory,
        newsDirectory: newsDirectory,
        images: const <OfflineNewsMediaItem>[],
        supportedFormats: _supportedImageExtensions.toList()..sort(),
        skippedUnsupportedCount: 0,
        unreadableCount: 0,
        scannedAt: DateTime.now().toUtc(),
        newsDirectoryExists: false,
      );
    }

    final images = <OfflineNewsMediaItem>[];
    var skippedUnsupported = 0;
    var unreadable = 0;

    try {
      await for (final entity in newsDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        final extension = p.extension(entity.path).toLowerCase();
        if (!_supportedImageExtensions.contains(extension)) {
          skippedUnsupported += 1;
          continue;
        }

        try {
          final stat = await entity.stat();
          images.add(
            OfflineNewsMediaItem(
              file: entity,
              lastModified: stat.modified.toUtc(),
              sizeBytes: stat.size,
            ),
          );
        } catch (_) {
          unreadable += 1;
        }
      }
    } on FileSystemException {
      unreadable += 1;
    }

    images.sort((a, b) {
      final modifiedComparison = b.lastModified.compareTo(a.lastModified);
      if (modifiedComparison != 0) {
        return modifiedComparison;
      }
      return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
    });

    return OfflineNewsGallerySnapshot(
      rootDirectory: rootDirectory,
      newsDirectory: newsDirectory,
      images: images,
      supportedFormats: _supportedImageExtensions.toList()..sort(),
      skippedUnsupportedCount: skippedUnsupported,
      unreadableCount: unreadable,
      scannedAt: DateTime.now().toUtc(),
      newsDirectoryExists: true,
    );
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
