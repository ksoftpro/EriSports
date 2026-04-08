import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:flutter/foundation.dart';

const List<String> kPreferredStandingsModeOrder = [
  'all',
  'home',
  'away',
  'form',
  'xg',
];

const Map<String, List<String>> _fullDataFilesByCompetitionId = {
  '47': ['premier_league_full_data.json'],
  '73': ['europa_league_full_data.json'],
  '42': ['champions_league_full_data.json'],
  '87': ['laliga_full_data.json'],
  '54': ['bundesliga_full_data.json'],
  '55': ['serie_a_full_data.json'],
  '53': ['ligue1_full_data.json'],
  '132': ['fa_cup_full_data.json'],
  '536': ['saudi_pro_league_full_data.json'],
};

class LeagueTransferFeedEntry {
  const LeagueTransferFeedEntry({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.position,
    required this.transferDateUtc,
  });

  final String playerId;
  final String playerName;
  final String? teamId;
  final String teamName;
  final String? position;
  final DateTime transferDateUtc;
}

class LeagueCompetitionDataset {
  const LeagueCompetitionDataset({
    required this.standings,
    required this.transferFeed,
  });

  const LeagueCompetitionDataset.empty()
    : standings = null,
      transferFeed = const [];

  final LeagueStandingsLeague? standings;
  final List<LeagueTransferFeedEntry> transferFeed;
}

class _LeagueResolvedData {
  const _LeagueResolvedData({required this.standings, required this.transfers});

  final LeagueStandingsLeague? standings;
  final List<LeagueTransferFeedEntry> transfers;
}

String standingsModeLabel(String modeKey) {
  switch (_normalizeKey(modeKey)) {
    case 'all':
      return 'Overall';
    case 'home':
      return 'Home';
    case 'away':
      return 'Away';
    case 'form':
      return 'Form';
    case 'xg':
      return 'XG';
    default:
      final words = modeKey
          .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
          .trim()
          .split(RegExp(r'\s+'));
      if (words.isEmpty || words.first.isEmpty) {
        return modeKey;
      }
      return words
          .map((word) {
            if (word.length <= 2) {
              return word.toUpperCase();
            }
            final lower = word.toLowerCase();
            return '${lower[0].toUpperCase()}${lower.substring(1)}';
          })
          .join(' ');
  }
}

class LeagueStandingsSource {
  LeagueStandingsSource({
    required DaylySportLocator daylySportLocator,
    this.cacheStore,
    this.filePrefix = 'top_standings_full_data',
  }) : _daylySportLocator = daylySportLocator;

  final DaylySportLocator _daylySportLocator;
  final DaylySportCacheStore? cacheStore;
  final String filePrefix;

  LeagueStandingsBundle? _cachedBundle;
  String? _cachedSourcePath;
  DateTime? _cachedModifiedAtUtc;
  final Map<String, LeagueStandingsLeague?> _cachedLeaguesByCompetitionId = {};
  final Map<String, List<LeagueTransferFeedEntry>>
  _cachedLeagueTransfersByCompetitionId = {};
  final Map<String, String> _cachedLeagueSourcePaths = {};
  final Map<String, DateTime> _cachedLeagueModifiedAtUtc = {};

  Future<LeagueCompetitionDataset> readLeagueDatasetByCompetitionId(
    String competitionId, {
    String? competitionName,
  }) async {
    final normalized = _normalizeKey(competitionId);
    if (normalized.isEmpty) {
      return const LeagueCompetitionDataset.empty();
    }

    final directData = await _readLeagueDataFromFullDataFile(
      normalized,
      competitionName: competitionName,
    );
    if (directData != null &&
        (directData.standings != null || directData.transfers.isNotEmpty)) {
      return LeagueCompetitionDataset(
        standings: directData.standings,
        transferFeed: directData.transfers,
      );
    }

    final bundle = await loadBundle();
    return LeagueCompetitionDataset(
      standings: bundle.resolveLeague(normalized),
      transferFeed: const [],
    );
  }

  Future<LeagueStandingsBundle> loadBundle() async {
    final sourceFile = await _resolveSourceFile();
    if (sourceFile == null) {
      const empty = LeagueStandingsBundle.empty();
      _cachedBundle = empty;
      _cachedSourcePath = null;
      _cachedModifiedAtUtc = null;
      return empty;
    }

    final stat = await sourceFile.stat();
    final lastModifiedUtc = stat.modified.toUtc();
    final cached = _cachedBundle;
    if (cached != null &&
        _cachedSourcePath == sourceFile.path &&
        _cachedModifiedAtUtc == lastModifiedUtc) {
      return cached;
    }

    try {
      final raw = await sourceFile.readAsString();
      final decoded = await compute(jsonDecode, raw);
      final parsed = LeagueStandingsBundle.fromJson(decoded);
      _cachedBundle = parsed;
      _cachedSourcePath = sourceFile.path;
      _cachedModifiedAtUtc = lastModifiedUtc;
      return parsed;
    } catch (_) {
      const empty = LeagueStandingsBundle.empty();
      _cachedBundle = empty;
      _cachedSourcePath = sourceFile.path;
      _cachedModifiedAtUtc = lastModifiedUtc;
      return empty;
    }
  }

  Future<File?> _resolveSourceFile() async {
    try {
      final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
      if (!await root.exists()) {
        return null;
      }

      final cached = cacheStore?.readLocatedFile(root.path, filePrefix);
      if (cached != null) {
        final cachedFile = File(cached.path);
        if (await cachedFile.exists()) {
          final stat = await cachedFile.stat();
          if (stat.modified.toUtc().millisecondsSinceEpoch ==
              cached.modifiedAtEpochMs) {
            return cachedFile;
          }
        }
      }

      final directCandidate = await _findInKnownLocations(root);
      if (directCandidate != null) {
        await _cacheLocatedFile(root.path, directCandidate);
        return directCandidate;
      }

      final matches = <File>[];
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }
        final lowerName = _filename(entity.path).toLowerCase();
        if (lowerName.startsWith(filePrefix.toLowerCase()) &&
            lowerName.endsWith('.json')) {
          matches.add(entity);
        }
      }

      if (matches.isEmpty) {
        return null;
      }

      matches.sort((a, b) {
        final aTime = a.statSync().modified;
        final bTime = b.statSync().modified;
        return bTime.compareTo(aTime);
      });
      final resolved = matches.first;
      await _cacheLocatedFile(root.path, resolved);
      return resolved;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _findInKnownLocations(Directory root) async {
    final candidateDirs = [
      root,
      Directory('${root.path}${Platform.pathSeparator}assets'),
      Directory('${root.path}${Platform.pathSeparator}standings'),
      Directory('${root.path}${Platform.pathSeparator}json'),
    ];

    final matches = <File>[];
    for (final directory in candidateDirs) {
      if (!await directory.exists()) {
        continue;
      }

      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        final lowerName = _filename(entity.path).toLowerCase();
        if (lowerName.startsWith(filePrefix.toLowerCase()) &&
            lowerName.endsWith('.json')) {
          matches.add(entity);
        }
      }
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return matches.first;
  }

  Future<void> _cacheLocatedFile(String scope, File file) async {
    if (cacheStore == null) {
      return;
    }

    final stat = await file.stat();
    await cacheStore!.writeLocatedFile(
      scope,
      filePrefix,
      CachedLocatedFile(
        path: file.path,
        modifiedAtEpochMs: stat.modified.toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  String _filename(String path) {
    final separators = RegExp(r'[\\/]');
    final parts = path.split(separators);
    return parts.isEmpty ? path : parts.last;
  }

  Future<LeagueStandingsLeague?> readLeagueByCompetitionId(
    String competitionId,
    {
    String? competitionName,
  }
  ) async {
    final dataset = await readLeagueDatasetByCompetitionId(
      competitionId,
      competitionName: competitionName,
    );
    return dataset.standings;
  }

  Future<_LeagueResolvedData?> _readLeagueDataFromFullDataFile(
    String competitionId, {
    String? competitionName,
  }) async {
    final sourceFile = await _resolveLeagueSourceFile(
      competitionId,
      competitionName: competitionName,
    );
    if (sourceFile == null) {
      _clearLeagueCacheFor(competitionId);
      return null;
    }

    final stat = await sourceFile.stat();
    final lastModifiedUtc = stat.modified.toUtc();
    final hasCachedEntry = _cachedLeagueSourcePaths.containsKey(competitionId);
    if (hasCachedEntry &&
        _cachedLeagueSourcePaths[competitionId] == sourceFile.path &&
        _cachedLeagueModifiedAtUtc[competitionId] == lastModifiedUtc) {
      return _LeagueResolvedData(
        standings: _cachedLeaguesByCompetitionId[competitionId],
        transfers:
            _cachedLeagueTransfersByCompetitionId[competitionId] ?? const [],
      );
    }

    try {
      final raw = await sourceFile.readAsString();
      final decoded = await compute(jsonDecode, raw);
      final parsedStandings = _parseSingleLeaguePayload(
        decoded,
        fallbackLookupKey: competitionId,
      );
      final parsedTransfers = _parseTransferFeedPayload(decoded);
      if (parsedStandings == null && parsedTransfers.isEmpty) {
        _clearLeagueCacheFor(competitionId);
        return null;
      }

      _cachedLeaguesByCompetitionId[competitionId] = parsedStandings;
      _cachedLeagueTransfersByCompetitionId[competitionId] =
          List.unmodifiable(parsedTransfers);
      _cachedLeagueSourcePaths[competitionId] = sourceFile.path;
      _cachedLeagueModifiedAtUtc[competitionId] = lastModifiedUtc;
      return _LeagueResolvedData(
        standings: parsedStandings,
        transfers: parsedTransfers,
      );
    } catch (_) {
      _clearLeagueCacheFor(competitionId);
      return null;
    }
  }

  Future<File?> _resolveLeagueSourceFile(
    String competitionId, {
    String? competitionName,
  }) async {
    try {
      final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
      if (!await root.exists()) {
        return null;
      }

      final cacheKey = _leagueFileCacheKey(competitionId);
      final cached = cacheStore?.readLocatedFile(root.path, cacheKey);
      if (cached != null) {
        final cachedFile = File(cached.path);
        if (await cachedFile.exists()) {
          final stat = await cachedFile.stat();
          if (stat.modified.toUtc().millisecondsSinceEpoch ==
              cached.modifiedAtEpochMs) {
            return cachedFile;
          }
        }
      }

      final expectedNames = _candidateLeagueFileNames(
        competitionId,
        competitionName: competitionName,
      );
      final namedMatch = await _findLeagueFileByName(root, expectedNames);
      if (namedMatch != null) {
        await _cacheLocatedLeagueFile(root.path, competitionId, namedMatch);
        return namedMatch;
      }

      final scannedMatch = await _scanLeagueFileByMetadata(root, competitionId);
      if (scannedMatch != null) {
        await _cacheLocatedLeagueFile(root.path, competitionId, scannedMatch);
        return scannedMatch;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Set<String> _candidateLeagueFileNames(
    String competitionId, {
    String? competitionName,
  }) {
    final expected = <String>{};

    final mapped = _fullDataFilesByCompetitionId[competitionId];
    if (mapped != null && mapped.isNotEmpty) {
      expected.addAll(mapped.map((name) => name.toLowerCase()));
    }

    final byName = _fullDataFileNameFromCompetitionName(competitionName);
    if (byName != null) {
      expected.add(byName.toLowerCase());
    }

    final slug = competitionId
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isNotEmpty) {
      expected.add('${slug}_full_data.json');
    }

    return expected;
  }

  String? _fullDataFileNameFromCompetitionName(String? competitionName) {
    if (competitionName == null || competitionName.trim().isEmpty) {
      return null;
    }

    final normalized = competitionName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.contains('premier league')) {
      return 'premier_league_full_data.json';
    }
    if (normalized.contains('champions league')) {
      return 'champions_league_full_data.json';
    }
    if (normalized.contains('europa league')) {
      return 'europa_league_full_data.json';
    }
    if (normalized.contains('ligue 1')) {
      return 'ligue1_full_data.json';
    }
    if (normalized.contains('bundesliga')) {
      return 'bundesliga_full_data.json';
    }
    if (normalized.contains('serie a')) {
      return 'serie_a_full_data.json';
    }
    if (normalized == 'laliga' || normalized.contains('la liga')) {
      return 'laliga_full_data.json';
    }
    if (normalized.contains('saudi pro league') ||
        normalized.contains('saudi professional league') ||
        normalized.contains('roshn saudi league')) {
      return 'saudi_pro_league_full_data.json';
    }
    if (normalized.contains('fa cup') ||
        normalized.contains('english fa cup')) {
      return 'fa_cup_full_data.json';
    }

    return null;
  }

  Future<File?> _findLeagueFileByName(
    Directory root,
    Set<String> expectedNames,
  ) async {
    if (expectedNames.isEmpty) {
      return null;
    }

    final candidateDirs = [
      root,
      Directory('${root.path}${Platform.pathSeparator}assets'),
      Directory('${root.path}${Platform.pathSeparator}standings'),
      Directory('${root.path}${Platform.pathSeparator}json'),
    ];

    final matches = <File>[];
    for (final directory in candidateDirs) {
      if (!await directory.exists()) {
        continue;
      }

      for (final expected in expectedNames) {
        final file = File('${directory.path}${Platform.pathSeparator}$expected');
        if (await file.exists()) {
          matches.add(file);
        }
      }
    }

    if (matches.isEmpty) {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        final lowerName = _filename(entity.path).toLowerCase();
        if (expectedNames.contains(lowerName)) {
          matches.add(entity);
        }
      }
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return matches.first;
  }

  Future<File?> _scanLeagueFileByMetadata(
    Directory root,
    String competitionId,
  ) async {
    final matches = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final lowerName = _filename(entity.path).toLowerCase();
      if (!_isPotentialLeagueFullDataFile(lowerName)) {
        continue;
      }

      final isMatch = await _fileMatchesCompetitionId(entity, competitionId);
      if (isMatch) {
        matches.add(entity);
      }
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return matches.first;
  }

  bool _isPotentialLeagueFullDataFile(String lowerName) {
    if (!lowerName.endsWith('_full_data.json')) {
      return false;
    }

    if (lowerName == 'fixtures_full_data.json') {
      return false;
    }

    if (lowerName == 'fotmob_full_player_stats.json') {
      return false;
    }

    return !lowerName.startsWith('top_standings_full_data');
  }

  Future<bool> _fileMatchesCompetitionId(
    File file,
    String competitionId,
  ) async {
    try {
      final decoded = await compute(jsonDecode, await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final meta = decoded['meta'];
      if (meta is! Map<String, dynamic>) {
        return false;
      }

      final leagueId = _normalizeKey(_stringValue(meta['leagueId']));
      if (leagueId == competitionId) {
        return true;
      }

      final slug = _normalizeKey(
        _stringValue(meta['slug']) ?? _stringValue(meta['leagueKey']),
      );
      return slug == competitionId;
    } catch (_) {
      return false;
    }
  }

  LeagueStandingsLeague? _parseSingleLeaguePayload(
    dynamic decoded, {
    required String fallbackLookupKey,
  }) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final meta =
        decoded['meta'] is Map<String, dynamic>
            ? decoded['meta'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final leagueKey =
        _stringValue(meta['leagueKey']) ??
        _stringValue(meta['slug']) ??
        fallbackLookupKey;

    final directStandings = decoded['standings'];
    if (directStandings is Map<String, dynamic>) {
      return LeagueStandingsLeague.fromJson(leagueKey, {
        'meta': meta,
        'standings': directStandings,
      });
    }

    final raw = decoded['raw'];
    if (raw is Map<String, dynamic>) {
      final standings = _extractStandingsFromRaw(raw);
      if (standings != null) {
        return LeagueStandingsLeague.fromJson(leagueKey, {
          'meta': meta,
          'standings': standings,
        });
      }
    }

    final bundle = LeagueStandingsBundle.fromJson(decoded);
    return bundle.resolveLeague(fallbackLookupKey);
  }

  List<LeagueTransferFeedEntry> _parseTransferFeedPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final raw = decoded['raw'];
    if (raw is! Map<String, dynamic>) {
      return const [];
    }

    return _extractTransferFeedFromRaw(raw);
  }

  List<LeagueTransferFeedEntry> _extractTransferFeedFromRaw(
    Map<String, dynamic> raw,
  ) {
    final transferRoot = _mapValue(raw['transfers']);
    if (transferRoot == null) {
      return const [];
    }

    final rawRows = transferRoot['data'];
    if (rawRows is! List) {
      return const [];
    }

    final parsed = <LeagueTransferFeedEntry>[];
    for (final row in rawRows) {
      final data = _mapValue(row);
      if (data == null) {
        continue;
      }

      final playerId = _stringValue(data['playerId']) ?? _stringValue(data['id']);
      final playerName = _stringValue(data['name']) ?? _stringValue(data['playerName']);
      if (playerId == null || playerName == null) {
        continue;
      }

      final toClubName = _stringValue(data['toClub']);
      final fromClubName = _stringValue(data['fromClub']);
      final toClubId = _sanitizeTeamId(_stringValue(data['toClubId']));
      final fromClubId = _sanitizeTeamId(_stringValue(data['fromClubId']));
      final resolvedTeamId = toClubId ?? fromClubId;
      final resolvedTeamName =
          toClubName ?? fromClubName ?? _stringValue(data['teamName']) ?? 'Unknown Team';

      final positionMap = _mapValue(data['position']);
      final position =
          _stringValue(positionMap?['label']) ??
          _stringValue(positionMap?['key']) ??
          _stringValue(data['position']);

      final transferDate =
          _dateTimeValue(data['transferDate']) ??
          _dateTimeValue(data['fromDate']) ??
          _dateTimeValue(data['toDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

      parsed.add(
        LeagueTransferFeedEntry(
          playerId: playerId,
          playerName: playerName,
          teamId: resolvedTeamId,
          teamName: resolvedTeamName,
          position: position,
          transferDateUtc: transferDate,
        ),
      );
    }

    parsed.sort((a, b) => b.transferDateUtc.compareTo(a.transferDateUtc));
    return parsed;
  }

  String? _sanitizeTeamId(String? value) {
    if (value == null || value.isEmpty || value == '-1' || value == '0') {
      return null;
    }
    return value;
  }

  Map<String, dynamic>? _extractStandingsFromRaw(Map<String, dynamic> raw) {
    final dataCandidates = _collectRawTableDataCandidates(raw['table']);
    Map<String, dynamic>? fallback;

    for (final candidate in dataCandidates) {
      final table = candidate['table'];
      if (table is! Map<String, dynamic>) {
        continue;
      }

      final normalizedTable = _normalizeModeTable(table);
      if (normalizedTable.isEmpty) {
        continue;
      }

      final standings = <String, dynamic>{
        'table': normalizedTable,
      };

      final allRows = normalizedTable['all'];
      if (allRows != null && allRows.isNotEmpty) {
        standings['flatTable'] = allRows;
      }

      final tableType = _stringValue(candidate['tableType']);
      if (tableType != null) {
        standings['tableType'] = tableType;
      }

      if (candidate['isCurrentSeason'] == true) {
        return standings;
      }

      fallback ??= standings;
    }

    return fallback;
  }

  List<Map<String, dynamic>> _collectRawTableDataCandidates(dynamic tableRoot) {
    final candidates = <Map<String, dynamic>>[];

    void addCandidate(dynamic value) {
      if (value is Map<String, dynamic>) {
        candidates.add(value);
        return;
      }

      if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            candidates.add(item);
          }
        }
      }
    }

    if (tableRoot is Map<String, dynamic>) {
      addCandidate(tableRoot['data']);
      if (tableRoot['table'] is Map<String, dynamic>) {
        candidates.add(tableRoot);
      }
      return candidates;
    }

    if (tableRoot is List) {
      for (final section in tableRoot) {
        if (section is! Map<String, dynamic>) {
          continue;
        }

        addCandidate(section['data']);
        if (section['table'] is Map<String, dynamic>) {
          candidates.add(section);
        }
      }
    }

    return candidates;
  }

  Map<String, List<Map<String, dynamic>>> _normalizeModeTable(
    Map<String, dynamic> rawTable,
  ) {
    final normalized = <String, List<Map<String, dynamic>>>{};
    for (final entry in rawTable.entries) {
      final modeKey = _normalizeKey(entry.key);
      if (modeKey.isEmpty || entry.value is! List) {
        continue;
      }

      final rows = <Map<String, dynamic>>[];
      for (final row in entry.value as List<dynamic>) {
        if (row is Map<String, dynamic>) {
          rows.add(row);
          continue;
        }

        if (row is Map) {
          rows.add(row.map((key, value) => MapEntry('$key', value)));
        }
      }

      if (rows.isNotEmpty) {
        normalized[modeKey] = rows;
      }
    }

    return normalized;
  }

  String _leagueFileCacheKey(String competitionId) {
    return 'league_full_data::$competitionId';
  }

  Future<void> _cacheLocatedLeagueFile(
    String scope,
    String competitionId,
    File file,
  ) async {
    if (cacheStore == null) {
      return;
    }

    final stat = await file.stat();
    await cacheStore!.writeLocatedFile(
      scope,
      _leagueFileCacheKey(competitionId),
      CachedLocatedFile(
        path: file.path,
        modifiedAtEpochMs: stat.modified.toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  void _clearLeagueCacheFor(String competitionId) {
    _cachedLeaguesByCompetitionId.remove(competitionId);
    _cachedLeagueTransfersByCompetitionId.remove(competitionId);
    _cachedLeagueSourcePaths.remove(competitionId);
    _cachedLeagueModifiedAtUtc.remove(competitionId);
  }

  void invalidateCache({bool clearPersistent = false}) {
    final idsToClear = <String>{
      ..._fullDataFilesByCompetitionId.keys,
      ..._cachedLeagueSourcePaths.keys,
    };

    _cachedBundle = null;
    _cachedSourcePath = null;
    _cachedModifiedAtUtc = null;
    _cachedLeaguesByCompetitionId.clear();
    _cachedLeagueTransfersByCompetitionId.clear();
    _cachedLeagueSourcePaths.clear();
    _cachedLeagueModifiedAtUtc.clear();

    if (clearPersistent) {
      unawaited(
        _daylySportLocator
            .getOrCreateDaylySportDirectory()
            .then((root) async {
              await cacheStore?.writeLocatedFile(root.path, filePrefix, null);
              for (final competitionId in idsToClear) {
                await cacheStore?.writeLocatedFile(
                  root.path,
                  _leagueFileCacheKey(competitionId),
                  null,
                );
              }
            })
            .catchError((_) {}),
      );
    }
  }
}

class LeagueStandingsBundle {
  const LeagueStandingsBundle({
    required this.byLeagueKey,
    required this.byCompetitionId,
  });

  const LeagueStandingsBundle.empty()
    : byLeagueKey = const {},
      byCompetitionId = const {};

  final Map<String, LeagueStandingsLeague> byLeagueKey;
  final Map<String, LeagueStandingsLeague> byCompetitionId;

  factory LeagueStandingsBundle.fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const LeagueStandingsBundle.empty();
    }

    final byKey = <String, LeagueStandingsLeague>{};
    final byId = <String, LeagueStandingsLeague>{};

    for (final entry in raw.entries) {
      final key = _normalizeKey(entry.key);
      final data = entry.value;
      if (data is! Map<String, dynamic>) {
        continue;
      }

      final league = LeagueStandingsLeague.fromJson(entry.key, data);
      if (league == null) {
        continue;
      }

      byKey[key] = league;

      final leagueId = _normalizeKey(league.meta.leagueId);
      if (leagueId.isNotEmpty) {
        byId[leagueId] = league;
      }

      final slug = _normalizeKey(league.meta.slug);
      if (slug.isNotEmpty) {
        byId.putIfAbsent(slug, () => league);
      }
    }

    return LeagueStandingsBundle(
      byLeagueKey: Map.unmodifiable(byKey),
      byCompetitionId: Map.unmodifiable(byId),
    );
  }

  LeagueStandingsLeague? resolveLeague(String competitionId) {
    final normalized = _normalizeKey(competitionId);
    if (normalized.isEmpty) {
      return null;
    }

    final byId = byCompetitionId[normalized];
    if (byId != null) {
      return byId;
    }

    return byLeagueKey[normalized];
  }
}

class LeagueStandingsLeague {
  const LeagueStandingsLeague({
    required this.leagueKey,
    required this.meta,
    required this.tableType,
    required this.modes,
  });

  final String leagueKey;
  final LeagueStandingsMeta meta;
  final String? tableType;
  final Map<String, LeagueStandingsModeData> modes;

  static LeagueStandingsLeague? fromJson(
    String leagueKey,
    Map<String, dynamic> json,
  ) {
    final meta = LeagueStandingsMeta.fromJson(json['meta']);

    final standings = json['standings'];
    if (standings is! Map<String, dynamic>) {
      return null;
    }

    final parsedModes = _extractModes(standings);
    if (parsedModes.isEmpty) {
      return null;
    }

    return LeagueStandingsLeague(
      leagueKey: leagueKey,
      meta: meta,
      tableType: _stringValue(standings['tableType']),
      modes: Map.unmodifiable(parsedModes),
    );
  }

  String get displayName {
    final slug = meta.slug;
    if (slug != null && slug.trim().isNotEmpty) {
      return _humanizeSlug(slug);
    }
    return _humanizeSlug(leagueKey);
  }

  List<String> get orderedModeKeys {
    final keys = modes.keys.toList(growable: false);
    if (keys.isEmpty) {
      return const [];
    }

    final preferred = <String>[];
    for (final mode in kPreferredStandingsModeOrder) {
      if (keys.contains(mode)) {
        preferred.add(mode);
      }
    }

    final custom =
        keys.where((key) => !preferred.contains(key)).toList()..sort();

    return [...preferred, ...custom];
  }

  LeagueStandingsModeData? mode(String modeKey) {
    return modes[_normalizeKey(modeKey)];
  }

  LeagueStandingsModeData? get defaultMode {
    for (final preferred in kPreferredStandingsModeOrder) {
      final found = modes[preferred];
      if (found != null && found.rows.isNotEmpty) {
        return found;
      }
    }

    for (final entry in orderedModeKeys) {
      final found = modes[entry];
      if (found != null && found.rows.isNotEmpty) {
        return found;
      }
    }

    return null;
  }

  LeagueStandingsModeData? get overallMode {
    final all = modes['all'];
    if (all != null && all.rows.isNotEmpty) {
      return all;
    }
    return defaultMode;
  }
}

Map<String, LeagueStandingsModeData> _extractModes(
  Map<String, dynamic> standings,
) {
  final parsedModes = <String, LeagueStandingsModeData>{};

  void addMode(String modeKey, List<dynamic> rawRows) {
    final normalizedMode = _normalizeKey(modeKey);
    if (normalizedMode.isEmpty) {
      return;
    }

    final rows = <LeagueStandingsRow>[];
    for (var i = 0; i < rawRows.length; i++) {
      final rawRow = rawRows[i];
      if (rawRow is! Map<String, dynamic>) {
        continue;
      }
      rows.add(LeagueStandingsRow.fromJson(rawRow, fallbackPosition: i + 1));
    }

    if (rows.isEmpty) {
      return;
    }

    parsedModes[normalizedMode] = LeagueStandingsModeData(
      key: normalizedMode,
      label: standingsModeLabel(normalizedMode),
      rows: List.unmodifiable(rows),
    );
  }

  final table = standings['table'];
  if (table is Map<String, dynamic>) {
    for (final entry in table.entries) {
      if (entry.value is List) {
        addMode(entry.key, entry.value as List<dynamic>);
      }
    }
  }

  final tables = standings['tables'];
  if (tables is List) {
    for (var i = 0; i < tables.length; i++) {
      final rawTable = tables[i];
      if (rawTable is! Map<String, dynamic>) {
        continue;
      }

      final rows = rawTable['table'];
      if (rows is! List) {
        continue;
      }

      final modeKey =
          _stringValue(rawTable['name']) ??
          _stringValue(rawTable['key']) ??
          _stringValue(rawTable['type']) ??
          'all';
      addMode(modeKey, rows.cast<dynamic>());
    }
  }

  final flatTable = standings['flatTable'];
  if (flatTable is List && flatTable.isNotEmpty) {
    addMode('all', flatTable.cast<dynamic>());
  }

  return parsedModes;
}

class LeagueStandingsMeta {
  const LeagueStandingsMeta({
    this.leagueId,
    this.slug,
    this.season,
    this.fetchedAt,
    this.sourceUrl,
  });

  final String? leagueId;
  final String? slug;
  final String? season;
  final String? fetchedAt;
  final String? sourceUrl;

  static LeagueStandingsMeta fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const LeagueStandingsMeta();
    }

    return LeagueStandingsMeta(
      leagueId: _stringValue(raw['leagueId']),
      slug: _stringValue(raw['slug']),
      season: _stringValue(raw['season']),
      fetchedAt: _stringValue(raw['fetchedAt']),
      sourceUrl: _stringValue(raw['sourceUrl']),
    );
  }
}

class LeagueStandingsModeData {
  const LeagueStandingsModeData({
    required this.key,
    required this.label,
    required this.rows,
  });

  final String key;
  final String label;
  final List<LeagueStandingsRow> rows;

  bool get hasXgColumns {
    return rows.any(
      (row) =>
          row.xg != null ||
          row.xgConceded != null ||
          row.xPoints != null ||
          row.xPosition != null,
    );
  }
}

class LeagueStandingsRow {
  const LeagueStandingsRow({
    required this.teamId,
    required this.teamName,
    required this.shortName,
    required this.position,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.scoresStr,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalConDiff,
    required this.points,
    this.pageUrl,
    this.qualColor,
    this.form,
    this.goalsScored,
    this.xg,
    this.xgConceded,
    this.xPoints,
    this.xPosition,
    this.xPositionDiff,
  });

  final String teamId;
  final String teamName;
  final String shortName;
  final int position;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final String scoresStr;
  final int goalsFor;
  final int goalsAgainst;
  final int goalConDiff;
  final int points;
  final String? pageUrl;
  final String? qualColor;
  final String? form;
  final int? goalsScored;
  final double? xg;
  final double? xgConceded;
  final double? xPoints;
  final int? xPosition;
  final int? xPositionDiff;

  String get displayTeamName {
    if (shortName.trim().isNotEmpty) {
      return shortName;
    }
    return teamName;
  }

  static LeagueStandingsRow fromJson(
    Map<String, dynamic> json, {
    required int fallbackPosition,
  }) {
    final teamId = _stringValue(json['id']) ?? 'unknown-$fallbackPosition';
    final teamName = _stringValue(json['name']) ?? 'Unknown Team';
    final shortName = _stringValue(json['shortName']) ?? teamName;

    final parsedScore = _parseScore(_stringValue(json['scoresStr']));
    final goalsFor =
        _intValue(json['goalsFor']) ??
        _intValue(json['goalsScored']) ??
        parsedScore.$1 ??
        0;

    var goalsAgainst =
        _intValue(json['goalsAgainst']) ??
        _intValue(json['goalsConceded']) ??
        parsedScore.$2;

    final goalDiff =
        _intValue(json['goalConDiff']) ?? _intValue(json['goalDiff']) ?? 0;

    goalsAgainst ??= goalsFor - goalDiff;

    final scoreString =
        _stringValue(json['scoresStr']) ?? '$goalsFor-$goalsAgainst';

    return LeagueStandingsRow(
      teamId: teamId,
      teamName: teamName,
      shortName: shortName,
      position:
          _intValue(json['idx']) ??
          _intValue(json['position']) ??
          fallbackPosition,
      played: _intValue(json['played']) ?? 0,
      wins: _intValue(json['wins']) ?? _intValue(json['won']) ?? 0,
      draws: _intValue(json['draws']) ?? _intValue(json['draw']) ?? 0,
      losses: _intValue(json['losses']) ?? _intValue(json['lost']) ?? 0,
      scoresStr: scoreString,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      goalConDiff: goalDiff,
      points: _intValue(json['pts']) ?? _intValue(json['points']) ?? 0,
      pageUrl: _stringValue(json['pageUrl']),
      qualColor: _stringValue(json['qualColor']),
      form: _stringValue(json['form']) ?? _stringValue(json['formStr']),
      goalsScored: _intValue(json['goalsScored']),
      xg: _doubleValue(json['xg']),
      xgConceded: _doubleValue(json['xgConceded']),
      xPoints: _doubleValue(json['xPoints']),
      xPosition: _intValue(json['xPosition']),
      xPositionDiff: _intValue(json['xPositionDiff']),
    );
  }
}

String _normalizeKey(String? value) {
  return (value ?? '').trim().toLowerCase();
}

String _humanizeSlug(String value) {
  final words = value
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'));

  if (words.isEmpty || words.first.isEmpty) {
    return value;
  }

  return words
      .map((word) {
        final lower = word.toLowerCase();
        if (lower.length <= 2) {
          return lower.toUpperCase();
        }
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
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

Map<String, dynamic>? _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return null;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value.toUtc();
  }

  final text = _stringValue(value);
  if (text == null) {
    return null;
  }

  return DateTime.tryParse(text)?.toUtc();
}

int? _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _doubleValue(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

(int?, int?) _parseScore(String? score) {
  if (score == null || score.trim().isEmpty) {
    return (null, null);
  }

  final separator = score.contains('-') ? '-' : ':';
  final parts = score.split(separator);
  if (parts.length != 2) {
    return (null, null);
  }

  return (int.tryParse(parts[0].trim()), int.tryParse(parts[1].trim()));
}
