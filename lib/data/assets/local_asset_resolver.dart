import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

enum SportsAssetType { teams, players, leagues, banners }

const _defaultPlayerPlaceholderAssetPath = 'assets/default.png';

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
  LocalAssetResolver({
    required DaylySportLocator daylySportLocator,
    AppLogger? logger,
    DaylySportCacheStore? cacheStore,
      EncryptedJsonService? encryptedJsonService,
  }) : _daylySportLocator = daylySportLocator,
       _logger = logger,
      _cacheStore = cacheStore,
      _encryptedJsonService = encryptedJsonService;

  final DaylySportLocator _daylySportLocator;
  final AppLogger? _logger;
  final DaylySportCacheStore? _cacheStore;
    final EncryptedJsonService? _encryptedJsonService;

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

  void invalidateCache({bool clearPersistent = false}) {
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

    if (clearPersistent) {
      unawaited(
        _daylySportLocator
            .getOrCreateDaylySportDirectory()
            .then((root) async {
              for (final type in SportsAssetType.values) {
                await _cacheStore?.removePathList(
                  root.path,
                  'asset_paths_${type.name}',
                );
              }
            })
            .catchError((_) {}),
      );
    }
  }

  Future<void> warmUp({
    bool includeTeamAssets = true,
    bool includePlayerAssets = true,
  }) async {
    await _ensureBundledAssetsLoaded();
    await _ensureBundledManifestLoaded();

    if (_localScanDisabled) {
      return;
    }

    try {
      if (includeTeamAssets) {
        await _ensureLocalFilesLoaded(SportsAssetType.teams);
      }
      if (includePlayerAssets) {
        await _ensureLocalFilesLoaded(SportsAssetType.players);
      }
    } catch (_) {
      _localScanDisabled = true;
      if (includeTeamAssets) {
        _localFilesByType[SportsAssetType.teams] = const [];
      }
      if (includePlayerAssets) {
        _localFilesByType[SportsAssetType.players] = const [];
      }
    }
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
    if (type == SportsAssetType.teams) {
      return resolveTeamBadge(teamId: entityId, teamName: entityName);
    }

    final id = entityId.trim().toLowerCase();
    final normalizedName = _normalizeLookup(entityName ?? '');
    final cacheKey = '${type.name}|$id|$normalizedName';
    if (_resolvedCache.containsKey(cacheKey)) {
      return _resolvedCache[cacheKey];
    }

    if (type == SportsAssetType.players) {
      final resolved = ResolvedImageRef.asset(_defaultPlayerPlaceholderAssetPath);
      _resolvedCache[cacheKey] = resolved;
      return resolved;
    }

    if (id.isEmpty && normalizedName.isEmpty) {
      return null;
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

  Future<ResolvedImageRef?> resolveTeamBadge({
    String? teamId,
    String? teamName,
    String? source,
  }) async {
    final rawId = teamId?.trim() ?? '';
    final id = rawId.toLowerCase();
    final nameVariants = _teamNameVariants(teamName ?? '');
    final variantKey = nameVariants.toList(growable: false)..sort();

    if (id.isEmpty && variantKey.isEmpty) {
      _logTeamBadgeResolution(
        source: source,
        teamId: rawId,
        teamName: teamName,
        resolvedPath: null,
        strategy: 'missing-input',
        usedNameFallback: false,
      );
      return null;
    }

    final cacheKey = 'team-badge|$id|${variantKey.join('|')}';
    if (_resolvedCache.containsKey(cacheKey)) {
      return _resolvedCache[cacheKey];
    }

    await _ensureBundledAssetsLoaded();
    await _ensureBundledManifestLoaded();
    if (!_localScanDisabled) {
      try {
        await _ensureLocalFilesLoaded(SportsAssetType.teams);
      } catch (_) {
        _localScanDisabled = true;
        _localFilesByType[SportsAssetType.teams] = const [];
      }
    }

    final idCandidates = id.isEmpty ? const <String>[] : _idCandidates(id);
    final bundledTeamAssets =
        _bundledAssetsByType[SportsAssetType.teams] ?? const <String>[];
    final localTeamAssets =
        _localFilesByType[SportsAssetType.teams] ?? const <String>[];

    for (final candidateId in idCandidates) {
      final manifestPath = _teamBadgePathById[candidateId];
      if (manifestPath != null && await File(manifestPath).exists()) {
        return _finishTeamBadgeResolution(
          cacheKey: cacheKey,
          source: source,
          teamId: rawId,
          teamName: teamName,
          resolved: ResolvedImageRef.file(manifestPath),
          strategy: 'local-manifest-id',
          usedNameFallback: false,
        );
      }
    }

    final localById = _bestTeamPathById(
      _localTeamPathsById,
      idCandidates,
      nameVariants,
    );
    if (localById != null) {
      return _finishTeamBadgeResolution(
        cacheKey: cacheKey,
        source: source,
        teamId: rawId,
        teamName: teamName,
        resolved: ResolvedImageRef.file(localById),
        strategy: 'local-indexed-id',
        usedNameFallback: false,
      );
    }

    final localByName = _bestTeamPathByName(localTeamAssets, nameVariants);
    if (localByName != null) {
      return _finishTeamBadgeResolution(
        cacheKey: cacheKey,
        source: source,
        teamId: rawId,
        teamName: teamName,
        resolved: ResolvedImageRef.file(localByName),
        strategy: 'local-name-fallback',
        usedNameFallback: true,
      );
    }

    for (final candidateId in idCandidates) {
      final bundledPath = _bundledTeamBadgePathById[candidateId];
      if (bundledPath != null) {
        return _finishTeamBadgeResolution(
          cacheKey: cacheKey,
          source: source,
          teamId: rawId,
          teamName: teamName,
          resolved: ResolvedImageRef.asset(bundledPath),
          strategy: 'bundled-manifest-id',
          usedNameFallback: false,
        );
      }
    }

    final bundledById = _bestTeamPathById(
      _bundledTeamPathsById,
      idCandidates,
      nameVariants,
    );
    if (bundledById != null) {
      return _finishTeamBadgeResolution(
        cacheKey: cacheKey,
        source: source,
        teamId: rawId,
        teamName: teamName,
        resolved: ResolvedImageRef.asset(bundledById),
        strategy: 'bundled-indexed-id',
        usedNameFallback: false,
      );
    }

    final bundledByName = _bestTeamPathByName(bundledTeamAssets, nameVariants);
    if (bundledByName != null) {
      return _finishTeamBadgeResolution(
        cacheKey: cacheKey,
        source: source,
        teamId: rawId,
        teamName: teamName,
        resolved: ResolvedImageRef.asset(bundledByName),
        strategy: 'bundled-name-fallback',
        usedNameFallback: true,
      );
    }

    _resolvedCache[cacheKey] = null;
    _logTeamBadgeResolution(
      source: source,
      teamId: rawId,
      teamName: teamName,
      resolvedPath: null,
      strategy: 'not-found',
      usedNameFallback: id.isEmpty,
    );
    return null;
  }

  Future<void> _ensureBundledAssetsLoaded() async {
    if (_bundleLoaded) {
      return;
    }

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = assetManifest.listAssets();

      for (final type in SportsAssetType.values) {
        final prefixes = _assetPrefixesFor(type);
        final paths = allAssets
          .where((path) => prefixes.any(path.startsWith))
          .toSet()
          .toList(growable: false)..sort();
        _bundledAssetsByType[type] = paths;

        if (type == SportsAssetType.teams) {
          _indexTeamAssetPaths(paths, _bundledTeamPathsById);
        }

        if (type == SportsAssetType.players) {
          _indexPlayerAssetPaths(paths, _bundledPlayerPathsById);
        }
      }
    } catch (_) {
      try {
        final manifestJson = await rootBundle.loadString('AssetManifest.json');
        final manifestMap = jsonDecode(manifestJson) as Map<String, dynamic>;

        for (final type in SportsAssetType.values) {
          final prefixes = _assetPrefixesFor(type);
          final paths = manifestMap.keys
            .where((path) => prefixes.any(path.startsWith))
            .toSet()
            .toList(growable: false)..sort();
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
      final daylySportDir =
          await _daylySportLocator.getOrCreateDaylySportDirectory();
      final candidatePaths = [
        p.join(daylySportDir.path, 'manifest', 'fotmob_assets_manifest.json'),
        p.join(
          daylySportDir.path,
          'assets',
          'manifest',
          'fotmob_assets_manifest.json',
        ),
      ];

      File? sourceFile;
      for (final basePath in candidatePaths) {
        for (final candidatePath in candidateSecureJsonPaths(basePath)) {
          final file = File(candidatePath);
          if (await file.exists()) {
            sourceFile = file;
            break;
          }
        }
        if (sourceFile != null) {
          break;
        }
      }

      if (sourceFile == null) {
        _bundleManifestLoaded = true;
        return;
      }

      final decoded = jsonDecode(await _readLocalJsonText(sourceFile));
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
            final fileName =
                _stringValue(
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
      // Ignore malformed/unavailable local manifest.
    }

    _bundleManifestLoaded = true;
  }

  Future<void> _ensureLocalFilesLoaded(SportsAssetType type) async {
    if (_localFilesByType.containsKey(type)) {
      return;
    }

    final daylySportDir =
        await _daylySportLocator.getOrCreateDaylySportDirectory();
    final cachedPaths = _cacheStore?.readPathList(
      daylySportDir.path,
      'asset_paths_${type.name}',
    );

    if (cachedPaths != null && cachedPaths.isNotEmpty) {
      final existing = <String>[];
      for (final path in cachedPaths) {
        if (await File(path).exists()) {
          existing.add(path);
        }
      }

      if (existing.isNotEmpty) {
        _localFilesByType[type] = existing;
        if (type == SportsAssetType.players) {
          _indexPlayerAssetPaths(existing, _localPlayerPathsById);
        }
        if (type == SportsAssetType.teams) {
          _indexTeamAssetPaths(existing, _localTeamPathsById);
          await _ensureTeamManifestLoaded(daylySportDir, existing);
        }
        return;
      }
    }

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
    await _cacheStore?.writePathList(
      daylySportDir.path,
      'asset_paths_${type.name}',
      results,
    );

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

    final manifestCandidatePaths = [
      p.join(
        daylySportDir.path,
        'manifest',
        'fotmob_club_badges_manifest.json',
      ),
      p.join(
        daylySportDir.path,
        'assets',
        'manifest',
        'fotmob_club_badges_manifest.json',
      ),
    ];

    for (final basePath in manifestCandidatePaths) {
      File? manifestFile;
      for (final candidatePath in candidateSecureJsonPaths(basePath)) {
        final file = File(candidatePath);
        if (await file.exists()) {
          manifestFile = file;
          break;
        }
      }
      if (manifestFile == null) {
        continue;
      }

      try {
        final decoded = jsonDecode(await _readLocalJsonText(manifestFile));
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

  Future<String> _readLocalJsonText(File sourceFile) {
    final encryptedJsonService = _encryptedJsonService;
    if (encryptedJsonService == null) {
      return sourceFile.readAsString();
    }
    return encryptedJsonService.readTextFile(sourceFile);
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
    Set<String> nameVariants,
  ) {
    for (final candidateId in idCandidates) {
      final paths = indexedPaths[candidateId];
      if (paths == null || paths.isEmpty) {
        continue;
      }

      final bestPath = _pickBestTeamPath(paths, nameVariants);
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
    final trailingDigits = RegExp(
      r'(\d+)(?:[_-]badge)?$',
    ).firstMatch(basename)?.group(1);
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

  String? _pickBestTeamPath(List<String> paths, Set<String> nameVariants) {
    if (paths.isEmpty) {
      return null;
    }

    if (nameVariants.isNotEmpty) {
      final bestByName = _bestTeamPathByName(paths, nameVariants);
      if (bestByName != null) {
        return bestByName;
      }
    }

    return paths.first;
  }

  String? _bestTeamPathByName(List<String> paths, Set<String> nameVariants) {
    if (paths.isEmpty || nameVariants.isEmpty) {
      return null;
    }

    String? bestPath;
    var bestScore = 0;

    for (final path in paths) {
      final candidateVariants = _teamNameVariants(_teamNameStemFromPath(path));
      final score = _scoreTeamNameMatch(candidateVariants, nameVariants);
      if (score > bestScore) {
        bestScore = score;
        bestPath = path;
      }
    }

    return bestScore > 0 ? bestPath : null;
  }

  String _teamNameStemFromPath(String path) {
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
    return stem;
  }

  Set<String> _teamNameVariants(String value) {
    final variants = <String>{};
    final normalized = _normalizeLookup(value);
    if (normalized.isNotEmpty) {
      variants.add(normalized);
      variants.add(_stripTeamStopwords(normalized));

      final withSaint = normalized.replaceAll(RegExp(r'\bst\b'), 'saint');
      final withSt = normalized.replaceAll('saint', 'st');
      variants.add(withSaint.trim());
      variants.add(withSt.trim());
    }

    variants.removeWhere((variant) => variant.trim().isEmpty);
    return variants;
  }

  int _scoreTeamNameMatch(
    Set<String> candidateVariants,
    Set<String> requestedVariants,
  ) {
    var bestScore = 0;

    for (final candidate in candidateVariants) {
      final candidateTokens =
          candidate.split(' ').where((token) => token.isNotEmpty).toSet();
      final candidateCore = _stripTeamStopwords(candidate);

      for (final requested in requestedVariants) {
        final requestedTokens =
            requested.split(' ').where((token) => token.isNotEmpty).toSet();
        final requestedCore = _stripTeamStopwords(requested);

        var score = 0;
        if (candidate == requested) {
          score = 500 + candidate.length;
        } else if (candidateCore.isNotEmpty && candidateCore == requestedCore) {
          score = 420 + candidateCore.length;
        } else if (candidate.contains(requested) ||
            requested.contains(candidate)) {
          score =
              320 +
              (candidate.length < requested.length
                  ? candidate.length
                  : requested.length);
        }

        final sharedTokens =
            candidateTokens.intersection(requestedTokens).length;
        if (sharedTokens > 0) {
          score += sharedTokens * 60;
        }

        if (sharedTokens >= 2 &&
            candidateCore.isNotEmpty &&
            requestedCore.isNotEmpty) {
          score += 80;
        }

        if (score > bestScore) {
          bestScore = score;
        }
      }
    }

    return bestScore;
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
    return _foldToAscii(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _stripTeamStopwords(String value) {
    return value
        .split(' ')
        .where((token) => token.isNotEmpty && !_teamStopwords.contains(token))
        .join(' ')
        .trim();
  }

  String _foldToAscii(String value) {
    if (value.isEmpty) {
      return value;
    }

    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_latinFoldMap[char] ?? char);
    }
    return buffer.toString();
  }

  ResolvedImageRef? _finishTeamBadgeResolution({
    required String cacheKey,
    required String? source,
    required String? teamId,
    required String? teamName,
    required ResolvedImageRef resolved,
    required String strategy,
    required bool usedNameFallback,
  }) {
    _resolvedCache[cacheKey] = resolved;
    _logTeamBadgeResolution(
      source: source,
      teamId: teamId,
      teamName: teamName,
      resolvedPath: resolved.path,
      strategy: strategy,
      usedNameFallback: usedNameFallback,
    );
    return resolved;
  }

  void _logTeamBadgeResolution({
    required String? source,
    required String? teamId,
    required String? teamName,
    required String? resolvedPath,
    required String strategy,
    required bool usedNameFallback,
  }) {
    if (_logger == null) {
      return;
    }

    final normalizedSource =
        source == null || source.trim().isEmpty ? 'unknown' : source.trim();
    final normalizedId =
        teamId == null || teamId.trim().isEmpty ? '-' : teamId.trim();
    final normalizedName =
        teamName == null || teamName.trim().isEmpty ? '-' : teamName.trim();
    final matchFound = resolvedPath != null;

    _logger.info(
      '[TeamBadge] source=$normalizedSource teamId=$normalizedId teamName="$normalizedName" strategy=$strategy matched=$matchFound usedNameFallback=$usedNameFallback resolved=${resolvedPath ?? '-'}',
    );
  }

  static const Set<String> _teamStopwords = {
    'fc',
    'cf',
    'sc',
    'afc',
    'ac',
    'as',
    'fk',
    'if',
    'bk',
    'sk',
    'club',
    'de',
  };

  static const Map<String, String> _latinFoldMap = {
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'Å': 'A',
    'Æ': 'AE',
    'Ç': 'C',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ð': 'D',
    'Ñ': 'N',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'Ø': 'O',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ý': 'Y',
    'Þ': 'TH',
    'ß': 'ss',
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ð': 'd',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'þ': 'th',
    'ÿ': 'y',
    'Ā': 'A',
    'ā': 'a',
    'Ă': 'A',
    'ă': 'a',
    'Ą': 'A',
    'ą': 'a',
    'Ć': 'C',
    'ć': 'c',
    'Ĉ': 'C',
    'ĉ': 'c',
    'Ċ': 'C',
    'ċ': 'c',
    'Č': 'C',
    'č': 'c',
    'Ď': 'D',
    'ď': 'd',
    'Đ': 'D',
    'đ': 'd',
    'Ē': 'E',
    'ē': 'e',
    'Ĕ': 'E',
    'ĕ': 'e',
    'Ė': 'E',
    'ė': 'e',
    'Ę': 'E',
    'ę': 'e',
    'Ě': 'E',
    'ě': 'e',
    'Ĝ': 'G',
    'ĝ': 'g',
    'Ğ': 'G',
    'ğ': 'g',
    'Ġ': 'G',
    'ġ': 'g',
    'Ģ': 'G',
    'ģ': 'g',
    'Ĥ': 'H',
    'ĥ': 'h',
    'Ħ': 'H',
    'ħ': 'h',
    'Ĩ': 'I',
    'ĩ': 'i',
    'Ī': 'I',
    'ī': 'i',
    'Ĭ': 'I',
    'ĭ': 'i',
    'Į': 'I',
    'į': 'i',
    'İ': 'I',
    'ı': 'i',
    'Ĵ': 'J',
    'ĵ': 'j',
    'Ķ': 'K',
    'ķ': 'k',
    'Ĺ': 'L',
    'ĺ': 'l',
    'Ļ': 'L',
    'ļ': 'l',
    'Ľ': 'L',
    'ľ': 'l',
    'Ł': 'L',
    'ł': 'l',
    'Ń': 'N',
    'ń': 'n',
    'Ņ': 'N',
    'ņ': 'n',
    'Ň': 'N',
    'ň': 'n',
    'Ō': 'O',
    'ō': 'o',
    'Ŏ': 'O',
    'ŏ': 'o',
    'Ő': 'O',
    'ő': 'o',
    'Œ': 'OE',
    'œ': 'oe',
    'Ŕ': 'R',
    'ŕ': 'r',
    'Ŗ': 'R',
    'ŗ': 'r',
    'Ř': 'R',
    'ř': 'r',
    'Ś': 'S',
    'ś': 's',
    'Ŝ': 'S',
    'ŝ': 's',
    'Ş': 'S',
    'ş': 's',
    'Š': 'S',
    'š': 's',
    'Ţ': 'T',
    'ţ': 't',
    'Ť': 'T',
    'ť': 't',
    'Ũ': 'U',
    'ũ': 'u',
    'Ū': 'U',
    'ū': 'u',
    'Ŭ': 'U',
    'ŭ': 'u',
    'Ů': 'U',
    'ů': 'u',
    'Ű': 'U',
    'ű': 'u',
    'Ų': 'U',
    'ų': 'u',
    'Ŵ': 'W',
    'ŵ': 'w',
    'Ŷ': 'Y',
    'ŷ': 'y',
    'Ÿ': 'Y',
    'Ź': 'Z',
    'ź': 'z',
    'Ż': 'Z',
    'ż': 'z',
    'Ž': 'Z',
    'ž': 'z',
  };

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
