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
  bool _bundleManifestLoaded = false;
  bool _localScanDisabled = false;
  final Map<SportsAssetType, List<String>> _bundledAssetsByType = {};
  final Map<SportsAssetType, List<String>> _localFilesByType = {};
  final Map<String, String> _teamBadgePathById = {};
  final Map<String, String> _bundledTeamBadgePathById = {};
  final Map<String, List<String>> _bundledTeamPathsById = {};
  final Map<String, List<String>> _localTeamPathsById = {};
  final Map<String, String> _bundledLeagueBadgePathById = {};
  final Map<String, List<String>> _bundledPlayerPathsById = {};
  final Map<String, List<String>> _localPlayerPathsById = {};
  final Map<String, ResolvedImageRef?> _resolvedCache = {};

  void invalidateCache() {
    _bundleLoaded = false;
    _teamManifestLoaded = false;
    _bundleManifestLoaded = false;
    _localScanDisabled = false;
    _bundledAssetsByType.clear();
    _localFilesByType.clear();
    _teamBadgePathById.clear();
    _bundledTeamBadgePathById.clear();
    _bundledTeamPathsById.clear();
    _localTeamPathsById.clear();
    _bundledLeagueBadgePathById.clear();
    _bundledPlayerPathsById.clear();
    _localPlayerPathsById.clear();
    _resolvedCache.clear();
  }

  Future<ResolvedImageRef?> resolveByEntityId({
    required SportsAssetType type,
    required String entityId,
  }) async {
    return resolve(type: type, entityId: entityId);
  }

  Future<ResolvedImageRef?> resolve({
    required SportsAssetType type,
    required String entityId,
    String? entityName,
  }) async {
    final id = entityId.trim().toLowerCase();
    final normalizedName = _normalizeLookup(entityName ?? '');
    if (id.isEmpty && normalizedName.isEmpty) {
      return null;
    }

    final cacheKey = '${type.name}|$id|$normalizedName';
    if (_resolvedCache.containsKey(cacheKey)) {
      return _resolvedCache[cacheKey];
    }

    await _ensureBundledAssetsLoaded();
    await _ensureBundledManifestLoaded();
    if (!_localScanDisabled) {
      try {
        await _ensureLocalFilesLoaded(type);
      } catch (_) {
        // If local external storage is unavailable/denied, fall back to bundled assets.
        _localScanDisabled = true;
        _localFilesByType[type] = const [];
      }
    }

    final idCandidates = id.isEmpty ? const <String>[] : _idCandidates(id);

    if (type == SportsAssetType.teams) {
      for (final candidateId in idCandidates) {
        final bundledPath = _bundledTeamBadgePathById[candidateId];
        if (bundledPath != null) {
          final resolved = ResolvedImageRef.asset(bundledPath);
          _resolvedCache[cacheKey] = resolved;
          return resolved;
        }
      }

      final bundledById = _bestTeamPathById(
        _bundledTeamPathsById,
        idCandidates,
        normalizedName,
      );
      if (bundledById != null) {
        final resolved = ResolvedImageRef.asset(bundledById);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }

      for (final candidateId in idCandidates) {
        final manifestPath = _teamBadgePathById[candidateId];
        if (manifestPath != null && await File(manifestPath).exists()) {
          final resolved = ResolvedImageRef.file(manifestPath);
          _resolvedCache[cacheKey] = resolved;
          return resolved;
        }
      }

      final localById = _bestTeamPathById(
        _localTeamPathsById,
        idCandidates,
        normalizedName,
      );
      if (localById != null) {
        final resolved = ResolvedImageRef.file(localById);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }
    }

    if (type == SportsAssetType.leagues) {
      for (final candidateId in idCandidates) {
        final bundledPath = _bundledLeagueBadgePathById[candidateId];
        if (bundledPath != null) {
          final resolved = ResolvedImageRef.asset(bundledPath);
          _resolvedCache[cacheKey] = resolved;
          return resolved;
        }
      }
    }

    if (type == SportsAssetType.players) {
      final localById = _bestPlayerPathById(
        _localPlayerPathsById,
        idCandidates,
        normalizedName,
      );
      if (localById != null) {
        final resolved = ResolvedImageRef.file(localById);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }

      final bundledById = _bestPlayerPathById(
        _bundledPlayerPathsById,
        idCandidates,
        normalizedName,
      );
      if (bundledById != null) {
        final resolved = ResolvedImageRef.asset(bundledById);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }
    }

    for (final candidateId in idCandidates) {
      final localMatch = _matchPath(
        _localFilesByType[type] ?? const [],
        candidateId,
      );
      if (localMatch != null) {
        final resolved = ResolvedImageRef.file(localMatch);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }

      final bundledMatch = _matchPath(
        _bundledAssetsByType[type] ?? const [],
        candidateId,
      );
      if (bundledMatch != null) {
        final resolved = ResolvedImageRef.asset(bundledMatch);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }
    }

    if (normalizedName.isNotEmpty) {
      final localByName = _matchPathByName(
        _localFilesByType[type] ?? const [],
        normalizedName,
      );
      if (localByName != null) {
        final resolved = ResolvedImageRef.file(localByName);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }

      final bundledByName = _matchPathByName(
        _bundledAssetsByType[type] ?? const [],
        normalizedName,
      );
      if (bundledByName != null) {
        final resolved = ResolvedImageRef.asset(bundledByName);
        _resolvedCache[cacheKey] = resolved;
        return resolved;
      }
    }

    _resolvedCache[cacheKey] = null;
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
        final prefixes = _assetPrefixesFor(type);
        final paths = manifestMap.keys
            .where((path) => prefixes.any(path.startsWith))
            .toSet()
            .toList(growable: false)
          ..sort();
        _bundledAssetsByType[type] = paths;

        if (type == SportsAssetType.teams) {
          _indexTeamAssetPaths(paths, _bundledTeamPathsById);
        }

        if (type == SportsAssetType.players) {
          _indexPlayerAssetPaths(paths, _bundledPlayerPathsById);
        }
      }
    } catch (_) {
      for (final type in SportsAssetType.values) {
        _bundledAssetsByType[type] = const [];
      }
    }

    _bundleLoaded = true;
  }

  Future<void> _ensureBundledManifestLoaded() async {
    if (_bundleManifestLoaded) {
      return;
    }

    final teamAssets = _bundledAssetsByType[SportsAssetType.teams] ?? const [];
    final leagueAssets =
        _bundledAssetsByType[SportsAssetType.leagues] ?? const [];
    final teamPathByBase = {
      for (final path in teamAssets) p.basename(path).toLowerCase(): path,
    };

    try {
      final raw = await rootBundle.loadString(
        'assets/manifest/fotmob_assets_manifest.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _bundleManifestLoaded = true;
        return;
      }

      final leagues = decoded['leagues'];
      if (leagues is! Map<String, dynamic>) {
        _bundleManifestLoaded = true;
        return;
      }

      for (final entry in leagues.entries) {
        final leagueData = entry.value;
        if (leagueData is! Map<String, dynamic>) {
          continue;
        }

        final meta = leagueData['meta'];
        if (meta is Map<String, dynamic>) {
          final leagueId = _stringValue(meta['leagueId']);
          if (leagueId != null) {
            final mapped = _matchPath(leagueAssets, leagueId.toLowerCase());
            if (mapped != null) {
              _bundledLeagueBadgePathById[leagueId.toLowerCase()] = mapped;
            }
          }
        }

        final teams = leagueData['teams'];
        if (teams is! List) {
          continue;
        }

        for (final rawTeam in teams) {
          if (rawTeam is! Map<String, dynamic>) {
            continue;
          }

          final teamId = _stringValue(rawTeam['teamId'])?.toLowerCase();
          if (teamId == null || teamId.isEmpty) {
            continue;
          }

          String? mappedPath;
          final badge = rawTeam['badge'];
          if (badge is Map<String, dynamic>) {
            final fileName = _stringValue(
              badge['fileName'] ?? badge['filename'],
            )?.toLowerCase();
            if (fileName != null) {
              mappedPath = teamPathByBase[fileName];
            }
          }

          mappedPath ??= _matchPath(teamAssets, teamId);
          if (mappedPath != null) {
            _bundledTeamBadgePathById[teamId] = mappedPath;
          }
        }
      }
    } catch (_) {
      // Ignore malformed/unavailable bundled manifest.
    }

    _bundleManifestLoaded = true;
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

    if (type == SportsAssetType.players) {
      _indexPlayerAssetPaths(results, _localPlayerPathsById);
    }

    if (type == SportsAssetType.teams) {
      _indexTeamAssetPaths(results, _localTeamPathsById);
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
    } else if (type == SportsAssetType.players) {
      candidates.addAll([
        Directory(p.join(daylySportDir.path, 'player')),
        Directory(p.join(daylySportDir.path, 'assets', 'player')),
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

    final escaped = RegExp.escape(entityIdLower);
    final tokenRegex = RegExp(
      '(^|[_-])$escaped([_-]|\\.)',
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

  String? _matchPathByName(List<String> candidates, String normalizedName) {
    if (candidates.isEmpty || normalizedName.isEmpty) {
      return null;
    }

    for (final path in candidates) {
      final basename = _normalizeLookup(p.basenameWithoutExtension(path));
      if (basename.contains(normalizedName)) {
        return path;
      }
    }

    return null;
  }

  List<String> _idCandidates(String rawId) {
    final candidates = <String>{rawId};
    final digits = RegExp(r'\d+').allMatches(rawId).map((m) => m.group(0)!);
    candidates.addAll(digits);
    return candidates.where((value) => value.trim().isNotEmpty).toList();
  }

  String? _bestTeamPathById(
    Map<String, List<String>> indexedPaths,
    List<String> idCandidates,
    String normalizedName,
  ) {
    for (final candidateId in idCandidates) {
      final paths = indexedPaths[candidateId];
      if (paths == null || paths.isEmpty) {
        continue;
      }

      final bestPath = _pickBestTeamPath(paths, normalizedName);
      if (bestPath != null) {
        return bestPath;
      }
    }

    return null;
  }

  void _indexTeamAssetPaths(
    List<String> paths,
    Map<String, List<String>> output,
  ) {
    output.clear();

    for (final path in paths) {
      final teamId = _extractTeamIdFromPath(path);
      if (teamId == null || teamId.isEmpty) {
        continue;
      }
      output.putIfAbsent(teamId, () => []).add(path);
    }

    for (final entry in output.entries) {
      entry.value.sort();
    }
  }

  String? _extractTeamIdFromPath(String path) {
    final basename = p.basenameWithoutExtension(path).toLowerCase();
    final trailingDigits =
        RegExp(r'(\d+)(?:[_-]badge)?$').firstMatch(basename)?.group(1);
    if (trailingDigits != null && trailingDigits.isNotEmpty) {
      return trailingDigits;
    }

    final matches = RegExp(r'\d+').allMatches(basename).toList(growable: false);
    if (matches.isEmpty) {
      return null;
    }

    // Pick the longest digit token, then the right-most one when lengths tie.
    matches.sort((a, b) {
      final lenCompare = b.group(0)!.length.compareTo(a.group(0)!.length);
      if (lenCompare != 0) {
        return lenCompare;
      }
      return b.start.compareTo(a.start);
    });

    return matches.first.group(0);
  }

  String _normalizedTeamNameFromPath(String path) {
    final basename = p.basenameWithoutExtension(path);
    var stem = basename;

    final lowerStem = stem.toLowerCase();
    if (lowerStem.startsWith('team_')) {
      stem = stem.substring('team_'.length);
    } else if (lowerStem.startsWith('club_')) {
      stem = stem.substring('club_'.length);
    }

    stem = stem.replaceFirst(RegExp(r'[_-]?badge$', caseSensitive: false), '');
    stem = stem.replaceFirst(RegExp(r'[_-]?\d+$'), '');
    return _normalizeLookup(stem);
  }

  String? _pickBestTeamPath(List<String> paths, String normalizedName) {
    if (paths.isEmpty) {
      return null;
    }

    if (normalizedName.isNotEmpty) {
      for (final path in paths) {
        final candidateName = _normalizedTeamNameFromPath(path);
        if (candidateName.contains(normalizedName) ||
            normalizedName.contains(candidateName)) {
          return path;
        }
      }
    }

    return paths.first;
  }

  String? _bestPlayerPathById(
    Map<String, List<String>> indexedPaths,
    List<String> idCandidates,
    String normalizedName,
  ) {
    for (final candidateId in idCandidates) {
      final paths = indexedPaths[candidateId];
      if (paths == null || paths.isEmpty) {
        continue;
      }

      final bestPath = _pickBestPlayerPath(paths, normalizedName);
      if (bestPath != null) {
        return bestPath;
      }
    }

    return null;
  }

  void _indexPlayerAssetPaths(
    List<String> paths,
    Map<String, List<String>> output,
  ) {
    output.clear();

    for (final path in paths) {
      final playerId = _extractPlayerIdFromPath(path);
      if (playerId == null || playerId.isEmpty) {
        continue;
      }
      output.putIfAbsent(playerId, () => []).add(path);
    }

    for (final entry in output.entries) {
      entry.value.sort();
    }
  }

  String? _extractPlayerIdFromPath(String path) {
    final basename = p.basenameWithoutExtension(path).toLowerCase();
    final trailingDigits = RegExp(r'(\d+)$').firstMatch(basename)?.group(1);
    if (trailingDigits != null && trailingDigits.isNotEmpty) {
      return trailingDigits;
    }

    final matches = RegExp(r'\d+').allMatches(basename).toList(growable: false);
    if (matches.isEmpty) {
      return null;
    }

    // Pick the longest digit token, then the right-most one when lengths tie.
    matches.sort((a, b) {
      final lenCompare = b.group(0)!.length.compareTo(a.group(0)!.length);
      if (lenCompare != 0) {
        return lenCompare;
      }
      return b.start.compareTo(a.start);
    });

    return matches.first.group(0);
  }

  String _normalizedPlayerNameFromPath(String path) {
    final basename = p.basenameWithoutExtension(path);
    var stem = basename;

    final lowerStem = stem.toLowerCase();
    if (lowerStem.startsWith('player_')) {
      stem = stem.substring('player_'.length);
    } else if (lowerStem.startsWith('players_')) {
      stem = stem.substring('players_'.length);
    }

    stem = stem.replaceFirst(RegExp(r'[_-]?\d+$'), '');
    return _normalizeLookup(stem);
  }

  String? _pickBestPlayerPath(List<String> paths, String normalizedName) {
    if (paths.isEmpty) {
      return null;
    }

    if (normalizedName.isNotEmpty) {
      for (final path in paths) {
        final candidateName = _normalizedPlayerNameFromPath(path);
        if (candidateName.contains(normalizedName) ||
            normalizedName.contains(candidateName)) {
          return path;
        }
      }
    }

    return paths.first;
  }

  String _normalizeLookup(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _assetPrefixesFor(SportsAssetType type) {
    final folderName = _folderNameFor(type);
    final prefixes = <String>{'assets/$folderName/'};
    if (type == SportsAssetType.players) {
      prefixes.add('assets/player/');
    }
    return prefixes.toList(growable: false);
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
