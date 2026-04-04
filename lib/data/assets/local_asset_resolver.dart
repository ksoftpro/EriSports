import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

enum SportsAssetType { teams, players, leagues, banners }

class ResolvedImageRef {
  const ResolvedImageRef._({required this.path, required this.isFile});

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
  LocalAssetResolver({required DaylySportLocator daylySportLocator})
    : _daylySportLocator = daylySportLocator;

  final DaylySportLocator _daylySportLocator;

  bool _bundleLoaded = false;
  bool _teamManifestLoaded = false;
  final Map<SportsAssetType, List<String>> _bundledAssetsByType = {};
  final Map<SportsAssetType, List<String>> _localFilesByType = {};
  final Map<String, String> _teamBadgePathById = {};

  void invalidateCache() {
    _bundleLoaded = false;
    _teamManifestLoaded = false;
    _bundledAssetsByType.clear();
    _localFilesByType.clear();
    _teamBadgePathById.clear();
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

    if (type == SportsAssetType.teams) {
      final manifestPath = _teamBadgePathById[id];
      if (manifestPath != null && await File(manifestPath).exists()) {
        return ResolvedImageRef.file(manifestPath);
      }
    }

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

    final daylySportDir =
        await _daylySportLocator.getOrCreateDaylySportDirectory();
    final candidateDirs = _candidateDirsForType(type, daylySportDir);

    final results = <String>[];
    for (final dir in candidateDirs) {
      if (!await dir.exists()) {
        continue;
      }

      final entities =
          await dir
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

    if (type == SportsAssetType.teams) {
      await _ensureTeamManifestLoaded(daylySportDir, results);
    }
  }

  List<Directory> _candidateDirsForType(
    SportsAssetType type,
    Directory daylySportDir,
  ) {
    final folderName = _folderNameFor(type);
    final candidates = <Directory>[
      Directory(p.join(daylySportDir.path, folderName)),
      Directory(p.join(daylySportDir.path, 'assets', folderName)),
    ];

    if (type == SportsAssetType.teams) {
      candidates.addAll([
        Directory(p.join(daylySportDir.path, 'club_badges')),
        Directory(p.join(daylySportDir.path, 'assets', 'club_badges')),
      ]);
    }

    final deduped = <String, Directory>{};
    for (final candidate in candidates) {
      deduped[candidate.path] = candidate;
    }
    return deduped.values.toList(growable: false);
  }

  Future<void> _ensureTeamManifestLoaded(
    Directory daylySportDir,
    List<String> teamFiles,
  ) async {
    if (_teamManifestLoaded) {
      return;
    }

    final fileByBasename = <String, String>{
      for (final file in teamFiles) p.basename(file).toLowerCase(): file,
    };

    final manifestCandidates = [
      File(
        p.join(
          daylySportDir.path,
          'manifest',
          'fotmob_club_badges_manifest.json',
        ),
      ),
      File(
        p.join(
          daylySportDir.path,
          'assets',
          'manifest',
          'fotmob_club_badges_manifest.json',
        ),
      ),
    ];

    for (final manifestFile in manifestCandidates) {
      if (!await manifestFile.exists()) {
        continue;
      }

      try {
        final decoded = jsonDecode(await manifestFile.readAsString());
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final leagues = decoded['leagues'];
        if (leagues is! Map<String, dynamic>) {
          continue;
        }

        for (final leagueEntry in leagues.entries) {
          final leagueData = leagueEntry.value;
          if (leagueData is! Map<String, dynamic>) {
            continue;
          }

          final saved = leagueData['saved'];
          if (saved is! List) {
            continue;
          }

          for (final rawItem in saved) {
            if (rawItem is! Map<String, dynamic>) {
              continue;
            }

            final teamId = _stringValue(rawItem['teamId']);
            if (teamId == null) {
              continue;
            }

            final absolutePath = _stringValue(rawItem['filePath']);
            if (absolutePath != null && await File(absolutePath).exists()) {
              _teamBadgePathById[teamId.toLowerCase()] = absolutePath;
              continue;
            }

            final fileName = _stringValue(rawItem['fileName'])?.toLowerCase();
            if (fileName != null) {
              final matched = fileByBasename[fileName];
              if (matched != null) {
                _teamBadgePathById[teamId.toLowerCase()] = matched;
              }
            }
          }
        }
      } catch (_) {
        // Ignore malformed local manifest and keep heuristic-based matching.
      }
    }

    _teamManifestLoaded = true;
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
    return null;
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
