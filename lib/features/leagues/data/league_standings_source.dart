import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
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

const List<String> _preferredStatTypeOrder = [
  'goals',
  'assists',
  'rating',
  'goals_per_90',
  'expected_goals',
  'expected_assists',
  'shots_on_target',
  'big_chances_created',
  'successful_dribbles',
  'accurate_passes',
  'clean_sheets',
  'saves',
];

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
    required this.fixtures,
    required this.playerStatCategories,
    required this.playerStatsByType,
  });

  const LeagueCompetitionDataset.empty()
    : standings = null,
      transferFeed = const [],
      fixtures = const [],
      playerStatCategories = const [],
      playerStatsByType = const {};

  final LeagueStandingsLeague? standings;
  final List<LeagueTransferFeedEntry> transferFeed;
  final List<HomeMatchView> fixtures;
  final List<TopStatCategoryView> playerStatCategories;
  final Map<String, List<TopPlayerLeaderboardEntryView>> playerStatsByType;
}

class _LeagueResolvedData {
  const _LeagueResolvedData({
    required this.standings,
    required this.transfers,
    required this.fixtures,
    required this.playerStatCategories,
    required this.playerStatsByType,
  });

  final LeagueStandingsLeague? standings;
  final List<LeagueTransferFeedEntry> transfers;
  final List<HomeMatchView> fixtures;
  final List<TopStatCategoryView> playerStatCategories;
  final Map<String, List<TopPlayerLeaderboardEntryView>> playerStatsByType;
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
    required EncryptedJsonService encryptedJsonService,
    this.cacheStore,
    this.filePrefix = 'top_standings_full_data',
  }) : _daylySportLocator = daylySportLocator,
       _encryptedJsonService = encryptedJsonService;

  final DaylySportLocator _daylySportLocator;
  final EncryptedJsonService _encryptedJsonService;
  final DaylySportCacheStore? cacheStore;
  final String filePrefix;

  LeagueStandingsBundle? _cachedBundle;
  String? _cachedSourcePath;
  DateTime? _cachedModifiedAtUtc;
  final Map<String, LeagueStandingsLeague?> _cachedLeaguesByCompetitionId = {};
  final Map<String, List<LeagueTransferFeedEntry>>
  _cachedLeagueTransfersByCompetitionId = {};
  final Map<String, List<HomeMatchView>> _cachedLeagueFixturesByCompetitionId =
      {};
  final Map<String, List<TopStatCategoryView>>
  _cachedLeaguePlayerStatCategoriesByCompetitionId = {};
  final Map<String, Map<String, List<TopPlayerLeaderboardEntryView>>>
  _cachedLeaguePlayerStatsByCompetitionId = {};
  final Map<String, String> _cachedLeagueSourcePaths = {};
  final Map<String, DateTime> _cachedLeagueModifiedAtUtc = {};

  Future<LeagueCompetitionDataset> readLeagueDatasetByCompetitionId(
    String competitionId, {
    String? competitionName,
    bool allowSharedFallback = false,
  }) async {
    final normalized = _normalizeKey(competitionId);
    if (normalized.isEmpty) {
      return const LeagueCompetitionDataset.empty();
    }

    final directData = await _readLeagueDataFromFullDataFile(
      normalized,
      competitionName: competitionName,
    );
    if (directData != null) {
      return LeagueCompetitionDataset(
        standings: directData.standings,
        transferFeed: directData.transfers,
        fixtures: directData.fixtures,
        playerStatCategories: directData.playerStatCategories,
        playerStatsByType: directData.playerStatsByType,
      );
    }

    if (!allowSharedFallback) {
      return const LeagueCompetitionDataset.empty();
    }

    final bundle = await loadBundle();
    return LeagueCompetitionDataset(
      standings: bundle.resolveLeague(normalized),
      transferFeed: const [],
      fixtures: const [],
      playerStatCategories: const [],
      playerStatsByType: const {},
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
      final raw = await _encryptedJsonService.readTextFile(sourceFile);
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
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        if (!isEncryptedJsonPath(entity.path)) {
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

      for (final entity
          in directory.listSync(recursive: false, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        if (!isEncryptedJsonPath(entity.path)) {
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
    return logicalSecureContentFileName(path);
  }

  Future<LeagueStandingsLeague?> readLeagueByCompetitionId(
    String competitionId,
    {
    String? competitionName,
    bool allowSharedFallback = false,
  }
  ) async {
    final dataset = await readLeagueDatasetByCompetitionId(
      competitionId,
      competitionName: competitionName,
      allowSharedFallback: allowSharedFallback,
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
        fixtures: _cachedLeagueFixturesByCompetitionId[competitionId] ?? const [],
        playerStatCategories:
            _cachedLeaguePlayerStatCategoriesByCompetitionId[competitionId] ??
            const [],
        playerStatsByType:
            _cachedLeaguePlayerStatsByCompetitionId[competitionId] ?? const {},
      );
    }

    try {
      final raw = await _encryptedJsonService.readTextFile(sourceFile);
      final decoded = await compute(jsonDecode, raw);
      final parsedStandings = _parseSingleLeaguePayload(
        decoded,
        fallbackLookupKey: competitionId,
      );
      final parsedTransfers = _parseTransferFeedPayload(decoded);
      final parsedFixtures = _parseFixturesPayload(
        decoded,
        competitionId: competitionId,
        standings: parsedStandings,
      );
      final parsedPlayerStatsByType = _parsePlayerStatsPayload(
        decoded,
        competitionId: competitionId,
        fallbackTeamNames: _buildTeamNameLookup(parsedStandings, parsedFixtures),
      );
      final parsedStatCategories = _buildPlayerStatCategories(
        parsedPlayerStatsByType,
      );

      if (parsedStandings == null &&
          parsedTransfers.isEmpty &&
          parsedFixtures.isEmpty &&
          parsedPlayerStatsByType.isEmpty) {
        _clearLeagueCacheFor(competitionId);
        return null;
      }

      _cachedLeaguesByCompetitionId[competitionId] = parsedStandings;
      _cachedLeagueTransfersByCompetitionId[competitionId] =
          List.unmodifiable(parsedTransfers);
      _cachedLeagueFixturesByCompetitionId[competitionId] = List.unmodifiable(
        parsedFixtures,
      );
      _cachedLeaguePlayerStatCategoriesByCompetitionId[competitionId] =
          List.unmodifiable(parsedStatCategories);
      _cachedLeaguePlayerStatsByCompetitionId[competitionId] =
          Map.unmodifiable(
            parsedPlayerStatsByType.map(
              (key, value) => MapEntry(key, List.unmodifiable(value)),
            ),
          );
      _cachedLeagueSourcePaths[competitionId] = sourceFile.path;
      _cachedLeagueModifiedAtUtc[competitionId] = lastModifiedUtc;
      return _LeagueResolvedData(
        standings: parsedStandings,
        transfers: parsedTransfers,
        fixtures: parsedFixtures,
        playerStatCategories: parsedStatCategories,
        playerStatsByType: parsedPlayerStatsByType,
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

      final scannedMatch = await _scanLeagueFileByMetadata(
        root,
        competitionId,
        competitionName: competitionName,
      );
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

    final genericNameSlug = _slugify(competitionName);
    if (genericNameSlug != null) {
      expected.add('${genericNameSlug}_full_data.json');
    }

    final slug = _slugify(competitionId);
    if (slug != null && slug.isNotEmpty) {
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

  String? _slugify(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final slug = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return slug.isEmpty ? null : slug;
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
        final file = File(
          '${directory.path}${Platform.pathSeparator}$expected$kEncryptedJsonExtension',
        );
        if (await file.exists()) {
          matches.add(file);
        }
      }
    }

    if (matches.isEmpty) {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        if (!isEncryptedJsonPath(entity.path)) {
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
    String competitionId, {
    String? competitionName,
  }
  ) async {
    final matches = <File>[];
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (!isEncryptedJsonPath(entity.path)) {
        continue;
      }

      final lowerName = _filename(entity.path).toLowerCase();
      if (!_isPotentialLeagueFullDataFile(lowerName)) {
        continue;
      }

      final isMatch = await _fileMatchesCompetitionIdentity(
        entity,
        competitionId: competitionId,
        competitionName: competitionName,
      );
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

  Future<bool> _fileMatchesCompetitionIdentity(
    File file,
    {
    required String competitionId,
    String? competitionName,
  }
  ) async {
    try {
      final decoded = await compute(
        jsonDecode,
        await _encryptedJsonService.readTextFile(file),
      );
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final meta = decoded['meta'];
      if (meta is! Map<String, dynamic>) {
        return false;
      }

      final leagueId = _normalizeKey(_stringValue(meta['leagueId']));
      final normalizedCompetitionId = _normalizeKey(competitionId);
      if (leagueId == normalizedCompetitionId) {
        return true;
      }

      final identityCandidates = <String>{
        normalizedCompetitionId,
        if (_slugify(competitionName) case final nameSlug?) nameSlug,
      };

      final slugOrKey = _normalizeKey(
        _stringValue(meta['slug']) ?? _stringValue(meta['leagueKey']),
      );
      if (slugOrKey.isNotEmpty && identityCandidates.contains(slugOrKey)) {
        return true;
      }

      final metaName = _normalizeKey(
        _stringValue(meta['leagueName']) ??
            _stringValue(meta['competitionName']) ??
            _stringValue(meta['name']),
      );
      if (metaName.isNotEmpty) {
        final normalizedTargetName = _normalizeKey(competitionName);
        if (normalizedTargetName.isNotEmpty && metaName == normalizedTargetName) {
          return true;
        }

        final metaNameSlug = _slugify(metaName);
        if (metaNameSlug != null && identityCandidates.contains(metaNameSlug)) {
          return true;
        }
      }

      return false;
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

  List<HomeMatchView> _parseFixturesPayload(
    dynamic decoded, {
    required String competitionId,
    LeagueStandingsLeague? standings,
  }) {
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final meta = _mapValue(decoded['meta']);
    final fallbackSeasonId =
        _stringValue(meta?['seasonId']) ?? _stringValue(meta?['season']);
    final fallbackTeamNames = _buildTeamNameLookup(standings, const []);
    final nowUtc = DateTime.now().toUtc();
    final rows = _collectFixtureRows(decoded);
    if (rows.isEmpty) {
      return const [];
    }

    final bestById = <String, HomeMatchView>{};
    final qualityById = <String, int>{};

    for (final row in rows) {
      final parsed = _parseFixtureRow(
        row,
        fallbackCompetitionId: competitionId,
        fallbackSeasonId: fallbackSeasonId,
        fallbackTeamNames: fallbackTeamNames,
        updatedAtUtc: nowUtc,
      );
      if (parsed == null) {
        continue;
      }

      final matchId = parsed.match.id;
      final quality =
          (parsed.homeTeamName == 'Unknown Team' ? 0 : 1) +
          (parsed.awayTeamName == 'Unknown Team' ? 0 : 1) +
          ((parsed.match.roundLabel?.trim().isNotEmpty ?? false) ? 1 : 0);
      final previousQuality = qualityById[matchId] ?? -1;
      if (quality >= previousQuality) {
        bestById[matchId] = parsed;
        qualityById[matchId] = quality;
      }
    }

    final fixtures = bestById.values.toList(growable: false)
      ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));
    return fixtures;
  }

  Map<String, String> _buildTeamNameLookup(
    LeagueStandingsLeague? standings,
    List<HomeMatchView> fixtures,
  ) {
    final lookup = <String, String>{};

    final rows = standings?.overallMode?.rows ?? const <LeagueStandingsRow>[];
    for (final row in rows) {
      final teamId = _sanitizeTeamId(row.teamId);
      if (teamId == null) {
        continue;
      }
      lookup[teamId] = row.displayTeamName;
    }

    for (final fixture in fixtures) {
      final homeId = _sanitizeTeamId(fixture.match.homeTeamId);
      final awayId = _sanitizeTeamId(fixture.match.awayTeamId);
      if (homeId != null && fixture.homeTeamName.trim().isNotEmpty) {
        lookup[homeId] = fixture.homeTeamName;
      }
      if (awayId != null && fixture.awayTeamName.trim().isNotEmpty) {
        lookup[awayId] = fixture.awayTeamName;
      }
    }

    return lookup;
  }

  List<Map<String, dynamic>> _collectFixtureRows(dynamic root) {
    final rows = <Map<String, dynamic>>[];

    void visit(dynamic node, int depth) {
      if (depth > 10) {
        return;
      }

      final map = _mapValue(node);
      if (map != null) {
        if (_looksLikeFixtureRow(map)) {
          rows.add(map);
        }

        final extracted = _mapValue(map['extracted']);
        if (extracted != null) {
          visit(extracted['allMatches'], depth + 1);
        }

        visit(map['allMatches'], depth + 1);
        visit(map['matches'], depth + 1);
        visit(map['fixtures'], depth + 1);
        visit(map['data'], depth + 1);
        visit(map['items'], depth + 1);
        visit(map['rounds'], depth + 1);
        visit(map['stages'], depth + 1);
        return;
      }

      if (node is List) {
        for (final item in node) {
          visit(item, depth + 1);
        }
      }
    }

    visit(root['fixtures'], 0);
    visit(root['raw'], 0);
    visit(root['matches'], 0);
    visit(root['allMatches'], 0);

    final deduped = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final matchId =
          _stringValue(row['matchId']) ??
          _stringValue(row['id']) ??
          _stringValue(row['fixtureId']);
      if (matchId == null) {
        continue;
      }
      deduped[matchId] = row;
    }

    return deduped.values.toList(growable: false);
  }

  bool _looksLikeFixtureRow(Map<String, dynamic> row) {
    final summary = _mapValue(row['summary']);
    final matchId =
        _stringValue(row['matchId']) ??
        _stringValue(row['id']) ??
        _stringValue(row['fixtureId']) ??
        _stringValue(summary?['matchId']);
    if (matchId == null) {
      return false;
    }

    final homeNode =
        _mapValue(row['homeTeam']) ??
        _mapValue(row['home']) ??
        _mapValue(summary?['homeTeam']);
    final awayNode =
        _mapValue(row['awayTeam']) ??
        _mapValue(row['away']) ??
        _mapValue(summary?['awayTeam']);

    final homeId =
        _stringValue(row['homeTeamId']) ??
        _stringValue(homeNode?['id']) ??
        _stringValue(homeNode?['teamId']);
    final awayId =
        _stringValue(row['awayTeamId']) ??
        _stringValue(awayNode?['id']) ??
        _stringValue(awayNode?['teamId']);

    return homeId != null && awayId != null;
  }

  HomeMatchView? _parseFixtureRow(
    Map<String, dynamic> row, {
    required String fallbackCompetitionId,
    required String? fallbackSeasonId,
    required Map<String, String> fallbackTeamNames,
    required DateTime updatedAtUtc,
  }) {
    final summary = _mapValue(row['summary']);
    final statusMap = _mapValue(row['status']);

    final matchId =
        _stringValue(row['matchId']) ??
        _stringValue(row['id']) ??
        _stringValue(row['fixtureId']) ??
        _stringValue(summary?['matchId']) ??
        _stringValue(summary?['id']);
    if (matchId == null) {
      return null;
    }

    final homeNode =
        _mapValue(row['homeTeam']) ??
        _mapValue(row['home']) ??
        _mapValue(summary?['homeTeam']);
    final awayNode =
        _mapValue(row['awayTeam']) ??
        _mapValue(row['away']) ??
        _mapValue(summary?['awayTeam']);

    final homeTeamId =
        _sanitizeTeamId(
          _stringValue(row['homeTeamId']) ??
              _stringValue(homeNode?['id']) ??
              _stringValue(homeNode?['teamId']),
        ) ??
        'home_unknown';
    final awayTeamId =
        _sanitizeTeamId(
          _stringValue(row['awayTeamId']) ??
              _stringValue(awayNode?['id']) ??
              _stringValue(awayNode?['teamId']),
        ) ??
        'away_unknown';

    final kickoffUtc =
        _dateTimeValue(row['kickoffUtc']) ??
        _dateTimeValue(row['startTime']) ??
        _dateTimeValue(row['utcTime']) ??
        _dateTimeValue(summary?['utcTime']) ??
        _dateTimeFromEpochValue(row['startTimestamp']) ??
        _dateTimeFromEpochValue(row['startTs']) ??
        _dateTimeFromEpochValue(statusMap?['utcTime']);
    if (kickoffUtc == null) {
      return null;
    }

    final competitionId =
        _stringValue(row['competitionId']) ??
        _stringValue(row['leagueId']) ??
        _stringValue(row['tournamentId']) ??
        fallbackCompetitionId;

    final match = MatchRow(
      id: matchId,
      competitionId: competitionId,
      seasonId:
          _stringValue(row['seasonId']) ??
          _stringValue(row['season']) ??
          fallbackSeasonId,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      kickoffUtc: kickoffUtc,
      status: _resolveFixtureStatus(
        row,
        statusMap: statusMap,
        summary: summary,
      ),
      homeScore:
          _intValue(row['homeScore']) ??
          _intValue(row['home_score']) ??
          _intValue(homeNode?['score']) ??
          _intValue(summary?['homeScore']) ??
          0,
      awayScore:
          _intValue(row['awayScore']) ??
          _intValue(row['away_score']) ??
          _intValue(awayNode?['score']) ??
          _intValue(summary?['awayScore']) ??
          0,
      roundLabel:
          _stringValue(row['round']) ??
          _stringValue(row['roundName']) ??
          _stringValue(summary?['roundName']) ??
          _stringValue(row['stage']) ??
          _stringValue(row['stageName']),
      updatedAtUtc: updatedAtUtc,
    );

    return HomeMatchView(
      match: match,
      homeTeamName: _resolveFixtureTeamName(
        explicitName:
            _stringValue(row['homeTeamName']) ??
            _stringValue(homeNode?['name']) ??
            _stringValue(homeNode?['teamName']),
        teamId: homeTeamId,
        fallbackTeamNames: fallbackTeamNames,
      ),
      awayTeamName: _resolveFixtureTeamName(
        explicitName:
            _stringValue(row['awayTeamName']) ??
            _stringValue(awayNode?['name']) ??
            _stringValue(awayNode?['teamName']),
        teamId: awayTeamId,
        fallbackTeamNames: fallbackTeamNames,
      ),
    );
  }

  String _resolveFixtureStatus(
    Map<String, dynamic> row, {
    Map<String, dynamic>? statusMap,
    Map<String, dynamic>? summary,
  }) {
    final raw =
        _stringValue(row['status']) ??
        _stringValue(statusMap?['type']) ??
        _stringValue(statusMap?['state']) ??
        _stringValue(summary?['status']) ??
        _stringValue(summary?['state']);
    if (raw != null) {
      return raw;
    }

    if (_boolValue(statusMap?['finished']) == true ||
        _boolValue(summary?['finished']) == true) {
      return 'finished';
    }
    if (_boolValue(statusMap?['started']) == true ||
        _boolValue(summary?['started']) == true) {
      return 'live';
    }

    return 'scheduled';
  }

  String _resolveFixtureTeamName({
    required String? explicitName,
    required String teamId,
    required Map<String, String> fallbackTeamNames,
  }) {
    if (explicitName != null && explicitName.trim().isNotEmpty) {
      return explicitName.trim();
    }

    final fallback = fallbackTeamNames[teamId];
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }

    return 'Unknown Team';
  }

  Map<String, List<TopPlayerLeaderboardEntryView>> _parsePlayerStatsPayload(
    dynamic decoded, {
    required String competitionId,
    required Map<String, String> fallbackTeamNames,
  }) {
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    final meta = _mapValue(decoded['meta']);
    final seasonId =
        _stringValue(meta?['seasonId']) ?? _stringValue(meta?['season']);
    final nowUtc = DateTime.now().toUtc();
    final statRoots = _collectStatRoots(decoded);
    if (statRoots.isEmpty) {
      return const {};
    }

    final byType = <String, Map<String, TopPlayerLeaderboardEntryView>>{};
    var syntheticId = 1;

    for (final entry in statRoots.entries) {
      final statType = _normalizeStatType(entry.key);
      if (statType.isEmpty) {
        continue;
      }

      final rows = _extractTopPlayerStatRows(entry.value);
      if (rows.isEmpty) {
        continue;
      }

      var fallbackRank = 1;
      for (final rawRow in rows) {
        final row = _mapValue(rawRow);
        if (row == null) {
          continue;
        }

        final itemType = _normalizeKey(_stringValue(row['type']));
        if (itemType.isNotEmpty && itemType != 'players' && itemType != 'player') {
          continue;
        }

        final playerId = _stringValue(row['id']) ?? _stringValue(row['playerId']);
        final playerName = _stringValue(row['name']) ?? _stringValue(row['playerName']);
        if (playerId == null || playerName == null) {
          continue;
        }

        final teamId = _sanitizeTeamId(
          _stringValue(row['teamId']) ??
              _stringValue(_mapValue(row['team'])?['id']) ??
              _stringValue(_mapValue(row['club'])?['id']),
        );
        final teamName =
            _stringValue(row['teamName']) ??
            _stringValue(_mapValue(row['team'])?['name']) ??
            _stringValue(_mapValue(row['club'])?['name']) ??
            (teamId == null ? null : fallbackTeamNames[teamId]);

        final statValue =
            _extractStatValue(row['statValue']) ??
            _extractStatValue(row['value']) ??
            _extractStatValue(row[statType]);
        if (statValue == null) {
          fallbackRank += 1;
          continue;
        }

        final subStatValue =
            _extractStatValue(row['subStatValue']) ??
            _extractStatValue(row['substatValue']);
        final rank = _intValue(row['rank']) ?? fallbackRank;
        fallbackRank += 1;

        final statRow = TopPlayerStatRow(
          id: syntheticId++,
          competitionId: competitionId,
          seasonId: seasonId,
          statType: statType,
          playerId: playerId,
          teamId: teamId,
          playerName: playerName,
          rank: rank,
          statValue: statValue,
          subStatValue: subStatValue,
          updatedAtUtc: nowUtc,
        );

        final parsed = TopPlayerLeaderboardEntryView(
          stat: statRow,
          teamName: teamName,
        );

        final scoped = byType.putIfAbsent(statType, () => {});
        final existing = scoped[playerId];
        if (existing == null ||
            parsed.stat.rank < existing.stat.rank ||
            parsed.stat.statValue > existing.stat.statValue) {
          scoped[playerId] = parsed;
        }
      }
    }

    if (byType.isEmpty) {
      return const {};
    }

    final resolved = <String, List<TopPlayerLeaderboardEntryView>>{};
    for (final entry in byType.entries) {
      final rows = entry.value.values.toList(growable: false)
        ..sort((a, b) {
          final rankOrder = a.stat.rank.compareTo(b.stat.rank);
          if (rankOrder != 0) {
            return rankOrder;
          }
          return b.stat.statValue.compareTo(a.stat.statValue);
        });
      resolved[entry.key] = rows;
    }

    return resolved;
  }

  Map<String, dynamic> _collectStatRoots(Map<String, dynamic> root) {
    final collected = <String, dynamic>{};

    void absorb(Map<String, dynamic>? source) {
      if (source == null) {
        return;
      }

      final statsMap = _mapValue(source['stats']);
      if (statsMap != null) {
        for (final entry in statsMap.entries) {
          collected[_normalizeStatType(entry.key)] = entry.value;
        }
      }

      final playerStatsMap = _mapValue(source['playerStats']);
      if (playerStatsMap != null) {
        for (final entry in playerStatsMap.entries) {
          collected[_normalizeStatType(entry.key)] = entry.value;
        }
      }

      final topScorers = source['topScorers'];
      if (topScorers != null) {
        collected['goals'] = topScorers;
      }
      final topAssists = source['topAssists'];
      if (topAssists != null) {
        collected['assists'] = topAssists;
      }
      final topRating = source['topRating'];
      if (topRating != null) {
        collected['rating'] = topRating;
      }

      for (final entry in source.entries) {
        if (!_shouldTreatAsStatTypeKey(entry.key)) {
          continue;
        }
        final rows = _extractTopPlayerStatRows(entry.value);
        if (rows.isEmpty) {
          continue;
        }
        collected[_normalizeStatType(entry.key)] = entry.value;
      }
    }

    absorb(root);
    absorb(_mapValue(root['raw']));
    return collected;
  }

  bool _shouldTreatAsStatTypeKey(String key) {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) {
      return false;
    }

    const blocked = {
      'meta',
      'raw',
      'table',
      'tables',
      'fixtures',
      'matches',
      'standings',
      'transfers',
      'overview',
      'seasons',
      'tabs',
      'news',
    };
    return !blocked.contains(normalized);
  }

  List<dynamic> _extractTopPlayerStatRows(dynamic statRoot) {
    if (statRoot is List) {
      return statRoot;
    }
    if (statRoot is! Map<String, dynamic>) {
      return const [];
    }

    final direct = statRoot['statsData'];
    if (direct is List) {
      return direct;
    }

    final data = _mapValue(statRoot['data']);
    final nestedStats = data?['statsData'];
    if (nestedStats is List) {
      return nestedStats;
    }

    final players = statRoot['players'];
    if (players is List) {
      return players;
    }

    return const [];
  }

  String _normalizeStatType(String rawType) {
    final normalized = rawType
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    switch (normalized) {
      case 'top_scorers':
      case 'topscorers':
      case 'scorers':
        return 'goals';
      case 'top_assists':
      case 'topassists':
      case 'assist':
        return 'assists';
      case 'top_rating':
      case 'toprating':
        return 'rating';
      case 'xg':
        return 'expected_goals';
      case 'xa':
        return 'expected_assists';
      default:
        return normalized;
    }
  }

  double? _extractStatValue(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return _extractStatValue(raw['value']) ??
          _extractStatValue(raw['stat']) ??
          _extractStatValue(raw['amount']);
    }
    return _doubleValue(raw);
  }

  List<TopStatCategoryView> _buildPlayerStatCategories(
    Map<String, List<TopPlayerLeaderboardEntryView>> byType,
  ) {
    if (byType.isEmpty) {
      return const [];
    }

    final keys = byType.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList(growable: false)
      ..sort((a, b) {
        final aPriority = _preferredStatTypeOrder.indexOf(a);
        final bPriority = _preferredStatTypeOrder.indexOf(b);
        if (aPriority >= 0 && bPriority >= 0) {
          return aPriority.compareTo(bPriority);
        }
        if (aPriority >= 0) {
          return -1;
        }
        if (bPriority >= 0) {
          return 1;
        }
        return a.compareTo(b);
      });

    return [
      for (final statType in keys)
        TopStatCategoryView(
          statType: statType,
          entryCount: byType[statType]?.length ?? 0,
        ),
    ];
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
    _cachedLeagueFixturesByCompetitionId.remove(competitionId);
    _cachedLeaguePlayerStatCategoriesByCompetitionId.remove(competitionId);
    _cachedLeaguePlayerStatsByCompetitionId.remove(competitionId);
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
    _cachedLeagueFixturesByCompetitionId.clear();
    _cachedLeaguePlayerStatCategoriesByCompetitionId.clear();
    _cachedLeaguePlayerStatsByCompetitionId.clear();
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

DateTime? _dateTimeFromEpochValue(dynamic value) {
  final asInt = _intValue(value);
  if (asInt == null) {
    return null;
  }

  final epochMs = asInt.abs() < 1000000000000 ? asInt * 1000 : asInt;
  return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
}

bool? _boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }
  }
  return null;
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
