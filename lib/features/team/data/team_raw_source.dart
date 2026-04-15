import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:flutter/foundation.dart';

class TeamRawEntry {
  const TeamRawEntry({
    required this.teamId,
    required this.meta,
    required this.raw,
  });

  final String teamId;
  final Map<String, dynamic> meta;
  final Map<String, dynamic> raw;
}

class TeamRawBundle {
  const TeamRawBundle({required this.byTeamId});

  const TeamRawBundle.empty() : byTeamId = const {};

  final Map<String, TeamRawEntry> byTeamId;

  factory TeamRawBundle.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const TeamRawBundle.empty();
    }

    final root = _asMap(raw) ?? const <String, dynamic>{};
    final teamsRaw = _asMap(root['teams']);
    if (teamsRaw == null || teamsRaw.isEmpty) {
      return const TeamRawBundle.empty();
    }

    final byTeamId = <String, TeamRawEntry>{};

    for (final entry in teamsRaw.entries) {
      final teamNode = _asMap(entry.value);
      if (teamNode == null || teamNode.isEmpty) {
        continue;
      }

      final meta = _asMap(teamNode['meta']) ?? const <String, dynamic>{};
      final rawNode = _asMap(teamNode['raw']) ?? const <String, dynamic>{};
      if (rawNode.isEmpty) {
        continue;
      }

      final details = _asMap(rawNode['details']) ?? const <String, dynamic>{};
      final resolvedId =
          _stringValue(details['id']) ??
          _stringValue(meta['teamId']) ??
          _stringValue(entry.key);
      if (resolvedId == null) {
        continue;
      }

      byTeamId[_normalizeTeamId(resolvedId)] = TeamRawEntry(
        teamId: resolvedId,
        meta: meta,
        raw: rawNode,
      );
    }

    return TeamRawBundle(byTeamId: Map.unmodifiable(byTeamId));
  }

  TeamRawEntry? resolveTeam(String teamId) {
    final normalized = _normalizeTeamId(teamId);
    if (normalized.isEmpty) {
      return null;
    }
    return byTeamId[normalized];
  }
}

class _CachedTeamRawEntry {
  const _CachedTeamRawEntry({
    required this.normalizedTeamId,
    required this.teamId,
    required this.sourcePath,
    required this.modifiedAtEpochMs,
    required this.cachedAtEpochMs,
    required this.meta,
    required this.raw,
  });

  final String normalizedTeamId;
  final String teamId;
  final String sourcePath;
  final int modifiedAtEpochMs;
  final int cachedAtEpochMs;
  final Map<String, dynamic> meta;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => {
    'normalizedTeamId': normalizedTeamId,
    'teamId': teamId,
    'sourcePath': sourcePath,
    'modifiedAtEpochMs': modifiedAtEpochMs,
    'cachedAtEpochMs': cachedAtEpochMs,
    'meta': meta,
    'raw': raw,
  };

  static _CachedTeamRawEntry? fromJson(Map<String, dynamic> value) {
    final normalizedTeamId = _stringValue(value['normalizedTeamId']);
    final teamId = _stringValue(value['teamId']);
    final sourcePath = _stringValue(value['sourcePath']);
    final modifiedAtEpochMs = value['modifiedAtEpochMs'];
    final cachedAtEpochMs = value['cachedAtEpochMs'];
    final meta = _asMap(value['meta']);
    final raw = _asMap(value['raw']);

    if (normalizedTeamId == null ||
        teamId == null ||
        sourcePath == null ||
        modifiedAtEpochMs is! int ||
        cachedAtEpochMs is! int ||
        meta == null ||
        raw == null) {
      return null;
    }

    return _CachedTeamRawEntry(
      normalizedTeamId: normalizedTeamId,
      teamId: teamId,
      sourcePath: sourcePath,
      modifiedAtEpochMs: modifiedAtEpochMs,
      cachedAtEpochMs: cachedAtEpochMs,
      meta: meta,
      raw: raw,
    );
  }
}

class TeamRawSource {
  TeamRawSource({
    required DaylySportLocator daylySportLocator,
    required EncryptedJsonService encryptedJsonService,
    this.cacheStore,
    this.cacheKey = 'team_payload_json',
  }) : _daylySportLocator = daylySportLocator,
       _encryptedJsonService = encryptedJsonService;

  final DaylySportLocator _daylySportLocator;
  final EncryptedJsonService _encryptedJsonService;
  final DaylySportCacheStore? cacheStore;
  final String cacheKey;
  static const _teamEntryCacheKey = 'team_payload_entry_cache_v1';
  static const _teamEntryCacheLimit = 12;

  TeamRawBundle? _cachedBundle;
  String? _cachedSourcePath;
  DateTime? _cachedModifiedAtUtc;

  Future<TeamRawEntry?> readTeamById(String teamId) async {
    final normalizedTeamId = _normalizeTeamId(teamId);
    if (normalizedTeamId.isEmpty) {
      return null;
    }

    final memoryHit = _cachedBundle?.resolveTeam(normalizedTeamId);
    if (memoryHit != null) {
      return memoryHit;
    }

    final persistedHit = await _readPersistedTeamEntry(normalizedTeamId);
    if (persistedHit != null) {
      return persistedHit;
    }

    final bundle = await loadBundle();
    final resolved = bundle.resolveTeam(normalizedTeamId);
    if (resolved != null) {
      await _persistTeamEntry(resolved);
    }
    return resolved;
  }

  Future<void> warmUp({bool preloadBundle = false}) async {
    if (preloadBundle) {
      await loadBundle();
      return;
    }
    await _resolveCandidateFiles();
  }

  Future<TeamRawBundle> loadBundle() async {
    final candidates = await _resolveCandidateFiles();
    if (candidates.isEmpty) {
      const empty = TeamRawBundle.empty();
      _cachedBundle = empty;
      _cachedSourcePath = null;
      _cachedModifiedAtUtc = null;
      return empty;
    }

    for (final candidate in candidates) {
      final stat = await candidate.stat();
      final modifiedAtUtc = stat.modified.toUtc();
      final cached = _cachedBundle;
      if (cached != null &&
          _cachedSourcePath == candidate.path &&
          _cachedModifiedAtUtc == modifiedAtUtc) {
        return cached;
      }

      try {
        final raw = await _encryptedJsonService.readTextFile(candidate);
        final decoded = await compute(_decodeTeamPayloadJson, raw);
        final bundle = TeamRawBundle.fromJson(decoded);
        if (bundle.byTeamId.isEmpty) {
          continue;
        }

        _cachedBundle = bundle;
        _cachedSourcePath = candidate.path;
        _cachedModifiedAtUtc = modifiedAtUtc;
        await _cacheLocatedFile(candidate, modifiedAtUtc);
        return bundle;
      } catch (_) {
        continue;
      }
    }

    const empty = TeamRawBundle.empty();
    _cachedBundle = empty;
    _cachedSourcePath = null;
    _cachedModifiedAtUtc = null;
    return empty;
  }

  Future<List<File>> _resolveCandidateFiles() async {
    final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
    if (!await root.exists()) {
      return const [];
    }

    final cached = cacheStore?.readLocatedFile(root.path, cacheKey);
    if (cached != null) {
      final cachedFile = File(cached.path);
      if (await cachedFile.exists()) {
        final stat = await cachedFile.stat();
        if (stat.modified.toUtc().millisecondsSinceEpoch ==
            cached.modifiedAtEpochMs) {
          return [cachedFile];
        }
      }
    }

    final candidates = <File>[];
    const preferredFileNames = [
      'fotmob_teams_from_top_leagues_plus_fc26_ready.json',
      'fotmob_teams_data.json',
      'fotmob_teams_complete_data.json',
    ];

    final candidateDirs = [
      root,
      Directory('${root.path}${Platform.pathSeparator}assets'),
      Directory('${root.path}${Platform.pathSeparator}catalog'),
      Directory('${root.path}${Platform.pathSeparator}json'),
    ];

    for (final directory in candidateDirs) {
      if (!await directory.exists()) {
        continue;
      }

      for (final name in preferredFileNames) {
        for (final candidatePath in candidateSecureJsonPaths(
          '${directory.path}${Platform.pathSeparator}$name',
        )) {
          final file = File(candidatePath);
          if (await file.exists()) {
            candidates.add(file);
          }
        }
      }
    }

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final lowerName = _fileName(entity.path).toLowerCase();
      if (_looksLikeTeamPayloadName(lowerName)) {
        candidates.add(entity);
      }
    }

    final byPath = <String, File>{};
    for (final file in candidates) {
      byPath[file.path] = file;
    }

    final deduped = byPath.values.toList(growable: false)..sort((a, b) {
      final aName = _fileName(a.path).toLowerCase();
      final bName = _fileName(b.path).toLowerCase();
      final aPriority = _candidatePriority(aName);
      final bPriority = _candidatePriority(bName);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      return aName.compareTo(bName);
    });

    return deduped;
  }

  Future<TeamRawEntry?> _readPersistedTeamEntry(String normalizedTeamId) async {
    if (cacheStore == null) {
      return null;
    }

    final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
    final located = cacheStore!.readLocatedFile(root.path, cacheKey);
    if (located == null) {
      return null;
    }

    final sourceFile = File(located.path);
    if (!await sourceFile.exists()) {
      return null;
    }

    final sourceStat = await sourceFile.stat();
    final sourceModifiedMs = sourceStat.modified.toUtc().millisecondsSinceEpoch;
    if (sourceModifiedMs != located.modifiedAtEpochMs) {
      return null;
    }

    final cachedEntries = _readCachedTeamEntries(root.path);
    _CachedTeamRawEntry? hit;
    for (final entry in cachedEntries) {
      if (entry.normalizedTeamId != normalizedTeamId) {
        continue;
      }
      if (entry.sourcePath != sourceFile.path) {
        continue;
      }
      if (entry.modifiedAtEpochMs != sourceModifiedMs) {
        continue;
      }
      hit = entry;
      break;
    }

    if (hit == null) {
      return null;
    }

    _cachedSourcePath = sourceFile.path;
    _cachedModifiedAtUtc = DateTime.fromMillisecondsSinceEpoch(
      sourceModifiedMs,
      isUtc: true,
    );

    await _persistCachedTeamEntries(root.path, [
      _CachedTeamRawEntry(
        normalizedTeamId: hit.normalizedTeamId,
        teamId: hit.teamId,
        sourcePath: hit.sourcePath,
        modifiedAtEpochMs: hit.modifiedAtEpochMs,
        cachedAtEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        meta: hit.meta,
        raw: hit.raw,
      ),
      ...cachedEntries.where(
        (entry) =>
            !(entry.normalizedTeamId == hit!.normalizedTeamId &&
                entry.sourcePath == hit.sourcePath &&
                entry.modifiedAtEpochMs == hit.modifiedAtEpochMs),
      ),
    ]);

    return TeamRawEntry(teamId: hit.teamId, meta: hit.meta, raw: hit.raw);
  }

  Future<void> _persistTeamEntry(TeamRawEntry entry) async {
    if (cacheStore == null ||
        _cachedSourcePath == null ||
        _cachedModifiedAtUtc == null) {
      return;
    }

    final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
    final normalizedTeamId = _normalizeTeamId(entry.teamId);
    if (normalizedTeamId.isEmpty) {
      return;
    }

    final modifiedAtMs = _cachedModifiedAtUtc!.millisecondsSinceEpoch;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final cachedEntries = _readCachedTeamEntries(root.path)
        .where(
          (item) =>
              !(item.normalizedTeamId == normalizedTeamId &&
                  item.sourcePath == _cachedSourcePath &&
                  item.modifiedAtEpochMs == modifiedAtMs),
        )
        .toList(growable: true);

    cachedEntries.insert(
      0,
      _CachedTeamRawEntry(
        normalizedTeamId: normalizedTeamId,
        teamId: entry.teamId,
        sourcePath: _cachedSourcePath!,
        modifiedAtEpochMs: modifiedAtMs,
        cachedAtEpochMs: nowMs,
        meta: entry.meta,
        raw: entry.raw,
      ),
    );

    await _persistCachedTeamEntries(root.path, cachedEntries);
  }

  List<_CachedTeamRawEntry> _readCachedTeamEntries(String scope) {
    if (cacheStore == null) {
      return const [];
    }

    final rawEntries = cacheStore!.readJsonObjectList(
      scope,
      _teamEntryCacheKey,
    );
    final entries = <_CachedTeamRawEntry>[];
    for (final rawEntry in rawEntries) {
      final parsed = _CachedTeamRawEntry.fromJson(rawEntry);
      if (parsed != null) {
        entries.add(parsed);
      }
    }

    entries.sort((a, b) => b.cachedAtEpochMs.compareTo(a.cachedAtEpochMs));
    return entries;
  }

  Future<void> _persistCachedTeamEntries(
    String scope,
    List<_CachedTeamRawEntry> entries,
  ) {
    if (cacheStore == null) {
      return Future.value();
    }

    final trimmed = entries.take(_teamEntryCacheLimit).toList(growable: false);
    return cacheStore!.writeJsonObjectList(
      scope,
      _teamEntryCacheKey,
      trimmed.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  Future<void> _cacheLocatedFile(File file, DateTime modifiedAtUtc) async {
    if (cacheStore == null) {
      return;
    }

    final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
    await cacheStore!.writeLocatedFile(
      root.path,
      cacheKey,
      CachedLocatedFile(
        path: file.path,
        modifiedAtEpochMs: modifiedAtUtc.millisecondsSinceEpoch,
      ),
    );
  }

  bool _looksLikeTeamPayloadName(String lowerName) {
    if (!lowerName.endsWith('.json')) {
      return false;
    }
    if (lowerName.contains('teams_from_top_leagues')) {
      return true;
    }
    if (!lowerName.contains('team')) {
      return false;
    }

    final excludedTokens = [
      'standing',
      'match',
      'player',
      'asset',
      'manifest',
      'lineup',
      'timeline',
    ];
    for (final token in excludedTokens) {
      if (lowerName.contains(token)) {
        return false;
      }
    }

    return lowerName.contains('teams') || lowerName.startsWith('fotmob_team');
  }

  int _candidatePriority(String lowerName) {
    if (lowerName.contains('teams_from_top_leagues')) {
      return 0;
    }
    if (lowerName == 'fotmob_teams_data.json') {
      return 1;
    }
    if (lowerName.startsWith('fotmob_teams')) {
      return 2;
    }
    if (lowerName.contains('teams')) {
      return 3;
    }
    return 4;
  }

  String _fileName(String path) {
    return logicalSecureContentFileName(path);
  }

  void invalidateCache({bool clearPersistent = false}) {
    _cachedBundle = null;
    _cachedSourcePath = null;
    _cachedModifiedAtUtc = null;

    if (clearPersistent) {
      unawaited(
        _daylySportLocator
            .getOrCreateDaylySportDirectory()
            .then((root) async {
              await cacheStore?.writeLocatedFile(root.path, cacheKey, null);
              await cacheStore?.writeJsonObjectList(
                root.path,
                _teamEntryCacheKey,
                const <Map<String, dynamic>>[],
              );
            })
            .catchError((_) {}),
      );
    }
  }
}

dynamic _decodeTeamPayloadJson(String raw) => jsonDecode(raw);

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }
  return null;
}

String? _stringValue(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) {
    return value.toString();
  }
  return null;
}

String _normalizeTeamId(String value) => value.trim();
