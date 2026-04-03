import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

enum SportsAssetType {
  teams,
  players,
  leagues,
  banners,
}

class ResolvedImageRef {
  const ResolvedImageRef._({
    required this.path,
    required this.isFile,
  });

  final String path;
  final bool isFile;

  factory ResolvedImageRef.file(String path) {
    return ResolvedImageRef._(path: path, isFile: true);
  }

  factory ResolvedImageRef.asset(String path) {
    return ResolvedImageRef._(path: path, isFile: false);
  }
}

class LocalAssetResolver {
  LocalAssetResolver({
    required DaylySportLocator daylySportLocator,
  }) : _daylySportLocator = daylySportLocator;

  final DaylySportLocator _daylySportLocator;

  bool _bundleLoaded = false;
  final Map<SportsAssetType, List<String>> _bundledAssetsByType = {};
  final Map<SportsAssetType, List<String>> _localFilesByType = {};

  void invalidateCache() {
    _bundleLoaded = false;
    _bundledAssetsByType.clear();
    _localFilesByType.clear();
  }

  Future<ResolvedImageRef?> resolveByEntityId({
    required SportsAssetType type,
    required String entityId,
  }) async {
    final id = entityId.trim().toLowerCase();
    if (id.isEmpty) {
      return null;
    }

    await _ensureBundledAssetsLoaded();
    await _ensureLocalFilesLoaded(type);

    final localMatch = _matchPath(_localFilesByType[type] ?? const [], id);
    if (localMatch != null) {
      return ResolvedImageRef.file(localMatch);
    }

    final bundledMatch = _matchPath(_bundledAssetsByType[type] ?? const [], id);
    if (bundledMatch != null) {
      return ResolvedImageRef.asset(bundledMatch);
    }

    return null;
  }

  Future<void> _ensureBundledAssetsLoaded() async {
    if (_bundleLoaded) {
      return;
    }

    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final manifestMap = jsonDecode(manifestJson) as Map<String, dynamic>;

      for (final type in SportsAssetType.values) {
        final folder = _folderNameFor(type);
        final prefix = 'assets/$folder/';
        final paths = manifestMap.keys
            .where((path) => path.startsWith(prefix))
            .toList(growable: false);
        _bundledAssetsByType[type] = paths;
      }
    } catch (_) {
      for (final type in SportsAssetType.values) {
        _bundledAssetsByType[type] = const [];
      }
    }

    _bundleLoaded = true;
  }

  Future<void> _ensureLocalFilesLoaded(SportsAssetType type) async {
    if (_localFilesByType.containsKey(type)) {
      return;
    }

    final daylySportDir = await _daylySportLocator.getOrCreateDaylySportDirectory();
    final folderName = _folderNameFor(type);

    final candidateDirs = [
      Directory(p.join(daylySportDir.path, folderName)),
      Directory(p.join(daylySportDir.path, 'assets', folderName)),
    ];

    final results = <String>[];
    for (final dir in candidateDirs) {
      if (!await dir.exists()) {
        continue;
      }

      final entities = await dir
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      for (final file in entities) {
        final lower = file.path.toLowerCase();
        if (lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp')) {
          results.add(file.path);
        }
      }
    }

    _localFilesByType[type] = results;
  }

  String? _matchPath(List<String> candidates, String entityIdLower) {
    if (candidates.isEmpty) {
      return null;
    }

    final tokenRegex = RegExp(
      '(^|_)${RegExp.escape(entityIdLower)}(_|\\.)',
      caseSensitive: false,
    );
    final exactNames = {
      '$entityIdLower.png',
      '$entityIdLower.jpg',
      '$entityIdLower.jpeg',
      '$entityIdLower.webp',
    };

    for (final path in candidates) {
      final basename = p.basename(path).toLowerCase();
      if (exactNames.contains(basename) || tokenRegex.hasMatch(basename)) {
        return path;
      }
    }

    return null;
  }

  String _folderNameFor(SportsAssetType type) {
    switch (type) {
      case SportsAssetType.teams:
        return 'teams';
      case SportsAssetType.players:
        return 'players';
      case SportsAssetType.leagues:
        return 'leagues';
      case SportsAssetType.banners:
        return 'banners';
    }
  }
}