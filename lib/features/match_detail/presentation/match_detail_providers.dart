import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/parsers/match_detail_parser.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchCenterState {
  const MatchCenterState({
    required this.requestedMatchId,
    required this.resolvedMatchId,
    required this.detail,
    required this.events,
    required this.stats,
    required this.debugLogs,
  });

  final String requestedMatchId;
  final String? resolvedMatchId;
  final MatchDetailView? detail;
  final List<MatchEventView> events;
  final List<MatchTeamStatComparison> stats;
  final List<String> debugLogs;

  bool get isResolved => detail != null;
}

class _ResolvedDbMatch {
  const _ResolvedDbMatch({
    required this.matchId,
    required this.detail,
    required this.events,
    required this.stats,
  });

  final String matchId;
  final MatchDetailView detail;
  final List<MatchEventView> events;
  final List<MatchTeamStatComparison> stats;
}

class _HydratedMatchRecord {
  const _HydratedMatchRecord({
    required this.matchId,
    required this.competitionId,
    required this.competitionName,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.kickoffUtc,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    this.roundLabel,
    this.detailPayload,
  });

  final String matchId;
  final String competitionId;
  final String competitionName;
  final String homeTeamId;
  final String homeTeamName;
  final String awayTeamId;
  final String awayTeamName;
  final DateTime kickoffUtc;
  final String status;
  final int homeScore;
  final int awayScore;
  final String? roundLabel;
  final Map<String, dynamic>? detailPayload;
}

typedef _LogFn = void Function(String message, {bool warn});

final matchDetailProvider = FutureProvider.family<MatchCenterState, String>((
  ref,
  matchId,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.matchDetails));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.matches));

  final services = ref.read(appServicesProvider);
  final diagnostics = <String>[];

  void log(String message, {bool warn = false}) {
    final line = '[MatchDetail] $message';
    diagnostics.add(line);
    if (warn) {
      services.logger.warn(line);
    } else {
      services.logger.info(line);
    }
  }

  final candidateIds = _buildCandidateMatchIds(matchId);
  log('Incoming route matchId="$matchId".');
  log('Candidate IDs: ${candidateIds.join(', ')}.');

  var resolved = await _resolveFromDatabase(
    services: services,
    candidateIds: candidateIds,
    log: log,
  );

  if (resolved == null) {
    final hydratedId = await _hydrateFromLocalJson(
      services: services,
      candidateIds: candidateIds,
      log: log,
    );
    if (hydratedId != null) {
      final retryIds = <String>{hydratedId, ...candidateIds};
      resolved = await _resolveFromDatabase(
        services: services,
        candidateIds: retryIds,
        log: log,
      );
    }
  }

  if (resolved == null) {
    log(
      'No match detail resolved for route id "$matchId" after DB and JSON fallback.',
      warn: true,
    );
    return MatchCenterState(
      requestedMatchId: matchId,
      resolvedMatchId: null,
      detail: null,
      events: const [],
      stats: const [],
      debugLogs: List.unmodifiable(diagnostics),
    );
  }

  log(
    'Resolved match id "${resolved.matchId}" (events=${resolved.events.length}, stats=${resolved.stats.length}).',
  );

  return MatchCenterState(
    requestedMatchId: matchId,
    resolvedMatchId: resolved.matchId,
    detail: resolved.detail,
    events: resolved.events,
    stats: resolved.stats,
    debugLogs: List.unmodifiable(diagnostics),
  );
});

Set<String> _buildCandidateMatchIds(String routeMatchId) {
  final candidates = <String>{};

  void add(String? value) {
    if (value == null) {
      return;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    candidates.add(trimmed);
  }

  add(routeMatchId);

  try {
    add(Uri.decodeComponent(routeMatchId));
  } catch (_) {
    // Ignore malformed URI values and keep the original route parameter.
  }

  for (final segment in routeMatchId.split('/')) {
    add(segment);
  }

  final lowered = routeMatchId.toLowerCase();
  if (lowered.startsWith('match_')) {
    add(routeMatchId.substring(6));
  }
  if (lowered.startsWith('fixture_')) {
    add(routeMatchId.substring(8));
  }

  final digits = RegExp(r'\d{4,}').allMatches(routeMatchId);
  for (final match in digits) {
    add(match.group(0));
  }

  return candidates;
}

Future<_ResolvedDbMatch?> _resolveFromDatabase({
  required AppServices services,
  required Iterable<String> candidateIds,
  required _LogFn log,
}) async {
  for (final candidate in candidateIds) {
    final detail = await services.database.readMatchDetailById(candidate);
    if (detail == null) {
      log('DB miss for match id "$candidate".');
      continue;
    }

    final events = await services.database.readMatchEventsByMatchId(candidate);
    final stats = await services.database.readMatchStatComparisons(candidate);
    log('DB hit for match id "$candidate".');

    return _ResolvedDbMatch(
      matchId: candidate,
      detail: detail,
      events: events,
      stats: stats,
    );
  }

  return null;
}

Future<String?> _hydrateFromLocalJson({
  required AppServices services,
  required Set<String> candidateIds,
  required _LogFn log,
}) async {
  Directory root;
  try {
    root = await services.daylySportLocator.getOrCreateDaylySportDirectory();
  } catch (error) {
    log('Failed to resolve daylysport directory: $error', warn: true);
    return null;
  }

  log('Resolved daylysport path: ${root.path}');

  if (!await root.exists()) {
    log('daylysport path does not exist on disk.', warn: true);
    return null;
  }

  final files = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && isSupportedSecureJsonPath(entity.path)) {
      files.add(entity);
    }
  }

  if (files.isEmpty) {
    log('No JSON files found under daylysport path.', warn: true);
    return null;
  }

  files.sort(
    (a, b) => _jsonPriority(a.path, candidateIds).compareTo(
      _jsonPriority(b.path, candidateIds),
    ),
  );

  const maxFilesToDecode = 300;
  if (files.length > maxFilesToDecode) {
    log(
      'Large JSON inventory detected (${files.length}). Scanning top $maxFilesToDecode candidates first.',
    );
  } else {
    log('Scanning ${files.length} JSON file(s) for match resolution.');
  }

  final parser = MatchDetailParser();
  final scanFiles = files.take(maxFilesToDecode);

  for (final file in scanFiles) {
    final lowerName = logicalSecureContentFileName(file.path).toLowerCase();
    if (!_looksLikeMatchDataFile(lowerName, candidateIds)) {
      continue;
    }

    log('Inspecting JSON: ${file.path}');

    String raw;
    try {
      raw = await services.secureContentCoordinator.readJsonText(file);
    } catch (error) {
      log('Unable to read ${file.path}: $error', warn: true);
      continue;
    }

    if (!_textMayContainCandidate(raw, candidateIds) &&
        !_isKnownMatchCatalogFile(lowerName)) {
      continue;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      continue;
    }

    final hydrated = _extractHydratedMatchRecord(
      decoded,
      lowerName,
      candidateIds,
    );
    if (hydrated != null) {
      await _upsertHydratedMatchRecord(services, hydrated, log);

      final parsedDetail = _parseMatchDetailPayload(
        parser,
        raw,
        hydrated.detailPayload,
      );
      if (parsedDetail != null) {
        await _upsertParsedMatchDetail(services, parsedDetail, log);
      }

      return hydrated.matchId;
    }

    final parsed = parser.parse(raw);
    if (parsed != null && candidateIds.contains(parsed.matchId)) {
      log('Parsed timeline/stats for match id "${parsed.matchId}" from ${file.path}.');
      await _upsertParsedMatchDetail(services, parsed, log);
      return parsed.matchId;
    }
  }

  log(
    'No matching JSON match payload found for candidate IDs: ${candidateIds.join(', ')}.',
    warn: true,
  );
  return null;
}

int _jsonPriority(String path, Set<String> candidateIds) {
  final lower = path.toLowerCase();
  if (candidateIds.any((id) => id.isNotEmpty && lower.contains(id))) {
    return 0;
  }
  if (lower.contains('match_detail') || lower.contains('match-detail')) {
    return 1;
  }
  if (lower.contains('fotmob_match_details_data')) {
    return 2;
  }
  if (lower.contains('fixtures_full_data')) {
    return 3;
  }
  if (lower.contains('fotmob_matches_data')) {
    return 4;
  }
  if (lower.contains('match') || lower.contains('fixture')) {
    return 5;
  }
  return 20;
}

bool _looksLikeMatchDataFile(String lowerName, Set<String> candidateIds) {
  if (candidateIds.any((id) => id.length >= 4 && lowerName.contains(id))) {
    return true;
  }

  return lowerName.contains('match') ||
      lowerName.contains('fixture') ||
      lowerName.contains('incident') ||
      lowerName.contains('timeline') ||
      lowerName.contains('event');
}

bool _isKnownMatchCatalogFile(String lowerName) {
  return lowerName == 'fotmob_match_details_data.json' ||
      lowerName == 'fotmob_matches_data.json' ||
      lowerName == 'fixtures_full_data.json';
}

bool _textMayContainCandidate(String text, Set<String> candidateIds) {
  for (final id in candidateIds) {
    if (id.length < 4) {
      continue;
    }
    if (text.contains(id)) {
      return true;
    }
  }
  return false;
}

_HydratedMatchRecord? _extractHydratedMatchRecord(
  dynamic decoded,
  String lowerFileName,
  Set<String> candidateIds,
) {
  final root = _asMap(decoded);
  if (root == null) {
    return _extractFromAnyNode(decoded, candidateIds);
  }

  if (lowerFileName == 'fotmob_match_details_data.json') {
    return _extractFromFotmobMatchDetailsData(root, candidateIds);
  }

  if (lowerFileName == 'fotmob_matches_data.json') {
    return _extractFromFotmobMatchesData(root, candidateIds);
  }

  if (lowerFileName == 'fixtures_full_data.json') {
    return _extractFromFixturesFullData(root, candidateIds);
  }

  return _extractFromAnyNode(root, candidateIds);
}

_HydratedMatchRecord? _extractFromFotmobMatchDetailsData(
  Map<String, dynamic> root,
  Set<String> candidateIds,
) {
  for (final entry in root.entries) {
    final rows = _asList(entry.value);
    if (rows == null) {
      continue;
    }

    for (final rowNode in rows) {
      final row = _asMap(rowNode);
      if (row == null) {
        continue;
      }

      final summary = _asMap(row['summary']);
      final matchId =
          _stringValue(summary?['matchId']) ?? _stringValue(row['matchId']);
      if (!_isCandidateMatchId(matchId, candidateIds)) {
        continue;
      }

      final homeNode = _asMap(summary?['homeTeam']);
      final awayNode = _asMap(summary?['awayTeam']);
      final homeTeamId = _stringValue(homeNode?['id']);
      final awayTeamId = _stringValue(awayNode?['id']);
      final kickoffUtc = _dateTimeValue(summary?['utcTime']);
      if (homeTeamId == null || awayTeamId == null || kickoffUtc == null) {
        continue;
      }

      final competitionId = _competitionIdFromLeagueKey(entry.key);
      final competitionName =
          _normalizeLeagueName(_competitionNameFromLeagueKey(entry.key));

      return _HydratedMatchRecord(
        matchId: matchId!,
        competitionId: competitionId,
        competitionName: competitionName,
        homeTeamId: homeTeamId,
        homeTeamName: _stringValue(homeNode?['name']) ?? 'Unknown Team',
        awayTeamId: awayTeamId,
        awayTeamName: _stringValue(awayNode?['name']) ?? 'Unknown Team',
        kickoffUtc: kickoffUtc,
        status: _stringValue(summary?['status']) ?? 'scheduled',
        homeScore: _intValue(homeNode?['score']) ?? 0,
        awayScore: _intValue(awayNode?['score']) ?? 0,
        roundLabel: _stringValue(summary?['roundName']),
        detailPayload: Map<String, dynamic>.from(row)
          ..putIfAbsent('matchId', () => matchId)
          ..putIfAbsent('homeTeamId', () => homeTeamId)
          ..putIfAbsent('awayTeamId', () => awayTeamId),
      );
    }
  }

  return null;
}

_HydratedMatchRecord? _extractFromFotmobMatchesData(
  Map<String, dynamic> root,
  Set<String> candidateIds,
) {
  for (final entry in root.entries) {
    final rows = _asList(entry.value);
    if (rows == null) {
      continue;
    }

    for (final rowNode in rows) {
      final row = _asMap(rowNode);
      if (row == null) {
        continue;
      }

      final parsed = _buildRecordFromMap(
        row,
        fallbackCompetitionId: _competitionIdFromLeagueKey(entry.key),
        fallbackCompetitionName: _normalizeLeagueName(
          _competitionNameFromLeagueKey(entry.key),
        ),
      );
      if (parsed != null && _isCandidateMatchId(parsed.matchId, candidateIds)) {
        return parsed;
      }
    }
  }

  return null;
}

_HydratedMatchRecord? _extractFromFixturesFullData(
  Map<String, dynamic> root,
  Set<String> candidateIds,
) {
  for (final entry in root.entries) {
    final leagueNode = _asMap(entry.value);
    if (leagueNode == null) {
      continue;
    }

    final meta = _asMap(leagueNode['meta']);
    final competitionId =
        _stringValue(meta?['leagueId']) ?? _competitionIdFromLeagueKey(entry.key);
    final competitionName = _normalizeLeagueName(
      _stringValue(meta?['slug']) ?? _competitionNameFromLeagueKey(entry.key),
    );

    final fixtures = _asMap(leagueNode['fixtures']);
    final extracted = _asMap(fixtures?['extracted']);
    final rows = _asList(extracted?['allMatches']);
    if (rows == null) {
      continue;
    }

    for (final rowNode in rows) {
      final row = _asMap(rowNode);
      if (row == null) {
        continue;
      }

      final parsed = _buildRecordFromMap(
        row,
        fallbackCompetitionId: competitionId,
        fallbackCompetitionName: competitionName,
      );
      if (parsed != null && _isCandidateMatchId(parsed.matchId, candidateIds)) {
        return parsed;
      }
    }
  }

  return null;
}

_HydratedMatchRecord? _extractFromAnyNode(
  dynamic node,
  Set<String> candidateIds, {
  int depth = 0,
}) {
  if (depth > 10) {
    return null;
  }

  final map = _asMap(node);
  if (map != null) {
    final parsed = _buildRecordFromMap(map);
    if (parsed != null && _isCandidateMatchId(parsed.matchId, candidateIds)) {
      return parsed;
    }

    for (final value in map.values) {
      final nested = _extractFromAnyNode(value, candidateIds, depth: depth + 1);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }

  final list = _asList(node);
  if (list != null) {
    for (final value in list) {
      final nested = _extractFromAnyNode(value, candidateIds, depth: depth + 1);
      if (nested != null) {
        return nested;
      }
    }
  }

  return null;
}

_HydratedMatchRecord? _buildRecordFromMap(
  Map<String, dynamic> map, {
  String? fallbackCompetitionId,
  String? fallbackCompetitionName,
}) {
  final summary = _asMap(map['summary']);
  final statusMap = _asMap(map['status']);

  final matchId =
      _stringValue(map['matchId']) ??
      _stringValue(map['id']) ??
      _stringValue(map['fixtureId']) ??
      _stringValue(summary?['matchId']) ??
      _stringValue(summary?['id']);
  if (matchId == null) {
    return null;
  }

  final homeNode =
      _asMap(map['homeTeam']) ??
      _asMap(map['home']) ??
      _asMap(map['team1']) ??
      _asMap(summary?['homeTeam']);
  final awayNode =
      _asMap(map['awayTeam']) ??
      _asMap(map['away']) ??
      _asMap(map['team2']) ??
      _asMap(summary?['awayTeam']);

  final homeTeamId =
      _stringValue(map['homeTeamId']) ??
      _stringValue(homeNode?['id']) ??
      _stringValue(homeNode?['teamId']);
  final awayTeamId =
      _stringValue(map['awayTeamId']) ??
      _stringValue(awayNode?['id']) ??
      _stringValue(awayNode?['teamId']);
  if (homeTeamId == null || awayTeamId == null) {
    return null;
  }

  final kickoffUtc =
      _dateTimeValue(map['kickoffUtc']) ??
      _dateTimeValue(map['startTime']) ??
      _dateTimeValue(map['utcTime']) ??
      _dateTimeValue(map['date']) ??
      _dateTimeValue(summary?['utcTime']) ??
      _dateTimeValue(summary?['startTime']) ??
      _dateTimeValue(statusMap?['utcTime']) ??
      _dateTimeValue(statusMap?['startDate']);
  if (kickoffUtc == null) {
    return null;
  }

  final competitionId =
      _stringValue(map['competitionId']) ??
      _stringValue(map['leagueId']) ??
      _stringValue(map['tournamentId']) ??
      _stringValue(summary?['competitionId']) ??
      fallbackCompetitionId ??
      'unknown_competition';

  final competitionName =
      _stringValue(map['competitionName']) ??
      _stringValue(map['leagueName']) ??
      _stringValue(summary?['competitionName']) ??
      fallbackCompetitionName ??
      'Unknown Competition';

  final homeScore =
      _intValue(map['homeScore']) ??
      _intValue(homeNode?['score']) ??
      _intValue(_asMap(map['score'])?['home']) ??
      _scorePairFromStatus(statusMap).$1;
  final awayScore =
      _intValue(map['awayScore']) ??
      _intValue(awayNode?['score']) ??
      _intValue(_asMap(map['score'])?['away']) ??
      _scorePairFromStatus(statusMap).$2;

  Map<String, dynamic>? detailPayload;
  if (_asList(map['events']) != null ||
      _asList(map['timeline']) != null ||
      _asList(map['incidents']) != null ||
      _asMap(map['teamStats']) != null ||
      _asList(map['stats']) != null ||
      _asList(map['statistics']) != null ||
      summary != null) {
    detailPayload = Map<String, dynamic>.from(map)
      ..putIfAbsent('matchId', () => matchId)
      ..putIfAbsent('homeTeamId', () => homeTeamId)
      ..putIfAbsent('awayTeamId', () => awayTeamId);
  }

  return _HydratedMatchRecord(
    matchId: matchId,
    competitionId: competitionId,
    competitionName: competitionName,
    homeTeamId: homeTeamId,
    homeTeamName:
        _stringValue(map['homeTeamName']) ??
        _stringValue(homeNode?['name']) ??
        _stringValue(homeNode?['teamName']) ??
        'Unknown Team',
    awayTeamId: awayTeamId,
    awayTeamName:
        _stringValue(map['awayTeamName']) ??
        _stringValue(awayNode?['name']) ??
        _stringValue(awayNode?['teamName']) ??
        'Unknown Team',
    kickoffUtc: kickoffUtc,
    status:
        _stringValue(map['status']) ??
        _stringValue(statusMap?['short']) ??
        _stringValue(_asMap(statusMap?['reason'])?['short']) ??
        _stringValue(summary?['status']) ??
        'scheduled',
    homeScore: homeScore,
    awayScore: awayScore,
    roundLabel:
        _stringValue(map['round']) ??
        _stringValue(map['roundName']) ??
        _stringValue(summary?['roundName']),
    detailPayload: detailPayload,
  );
}

(int, int) _scorePairFromStatus(Map<String, dynamic>? statusMap) {
  final scoreStr = _stringValue(statusMap?['scoreStr']);
  if (scoreStr == null || scoreStr.isEmpty) {
    return (0, 0);
  }

  final separator = scoreStr.contains('-') ? '-' : ':';
  final parts = scoreStr.split(separator);
  if (parts.length != 2) {
    return (0, 0);
  }

  final home = int.tryParse(parts[0].trim()) ?? 0;
  final away = int.tryParse(parts[1].trim()) ?? 0;
  return (home, away);
}

bool _isCandidateMatchId(String? value, Set<String> candidateIds) {
  if (value == null || value.trim().isEmpty) {
    return false;
  }
  final trimmed = value.trim();
  if (candidateIds.contains(trimmed)) {
    return true;
  }

  final digits = RegExp(r'\d{4,}').allMatches(trimmed).map((m) => m.group(0));
  for (final token in digits) {
    if (token != null && candidateIds.contains(token)) {
      return true;
    }
  }

  return false;
}

MatchDetailParseResult? _parseMatchDetailPayload(
  MatchDetailParser parser,
  String rawFile,
  Map<String, dynamic>? detailPayload,
) {
  if (detailPayload != null) {
    try {
      final encoded = jsonEncode(detailPayload);
      final parsed = parser.parse(encoded);
      if (parsed != null) {
        return parsed;
      }
    } catch (_) {
      // Fallback to full raw payload parse.
    }
  }

  return parser.parse(rawFile);
}

Future<void> _upsertHydratedMatchRecord(
  AppServices services,
  _HydratedMatchRecord record,
  _LogFn log,
) async {
  final now = DateTime.now().toUtc();
  await services.database.transaction(() async {
    await _ensureCompetition(
      services,
      competitionId: record.competitionId,
      competitionName: record.competitionName,
      now: now,
    );
    await _ensureTeam(
      services,
      teamId: record.homeTeamId,
      teamName: record.homeTeamName,
      competitionId: record.competitionId,
      now: now,
    );
    await _ensureTeam(
      services,
      teamId: record.awayTeamId,
      teamName: record.awayTeamName,
      competitionId: record.competitionId,
      now: now,
    );

    await services.database.into(services.database.matches).insertOnConflictUpdate(
      MatchesCompanion.insert(
        id: record.matchId,
        competitionId: record.competitionId,
        seasonId: const Value(null),
        homeTeamId: record.homeTeamId,
        awayTeamId: record.awayTeamId,
        kickoffUtc: record.kickoffUtc,
        status: Value(record.status),
        homeScore: Value(record.homeScore),
        awayScore: Value(record.awayScore),
        roundLabel: Value(record.roundLabel),
        updatedAtUtc: now,
      ),
    );
  });

  log('Hydrated match row from JSON for id "${record.matchId}".');
}

Future<void> _upsertParsedMatchDetail(
  AppServices services,
  MatchDetailParseResult parsed,
  _LogFn log,
) async {
  final now = DateTime.now().toUtc();
  final db = services.database;

  await db.transaction(() async {
    await (db.delete(db.matchEvents)
      ..where((tbl) => tbl.matchId.equals(parsed.matchId))).go();
    await (db.delete(db.matchTeamStats)
      ..where((tbl) => tbl.matchId.equals(parsed.matchId))).go();

    for (final event in parsed.events) {
      if (event.teamId != null) {
        await _ensureTeam(
          services,
          teamId: event.teamId!,
          teamName: null,
          competitionId: null,
          now: now,
        );
      }

      if (event.playerId != null) {
        await _ensurePlayer(
          services,
          playerId: event.playerId!,
          playerName: event.playerName,
          teamId: event.teamId,
          now: now,
        );
      }

      await db.into(db.matchEvents).insert(
        MatchEventsCompanion.insert(
          matchId: parsed.matchId,
          minute: event.minute,
          eventType: event.eventType,
          teamId: Value(event.teamId),
          playerId: Value(event.playerId),
          playerName: Value(event.playerName),
          detail: Value(event.detail),
        ),
      );
    }

    for (final stat in parsed.stats) {
      await _ensureTeam(
        services,
        teamId: stat.teamId,
        teamName: null,
        competitionId: null,
        now: now,
      );

      await db.into(db.matchTeamStats).insert(
        MatchTeamStatsCompanion.insert(
          matchId: parsed.matchId,
          teamId: stat.teamId,
          statKey: stat.statKey,
          statValue: stat.statValue,
        ),
      );
    }
  });

  log(
    'Hydrated timeline/stats for "${parsed.matchId}" (events=${parsed.events.length}, stats=${parsed.stats.length}).',
  );
}

Future<void> _ensureCompetition(
  AppServices services, {
  required String competitionId,
  required String competitionName,
  required DateTime now,
}) async {
  final existing = await services.database.readCompetitionById(competitionId);
  await services.database
      .into(services.database.competitions)
      .insertOnConflictUpdate(
        CompetitionsCompanion.insert(
          id: competitionId,
          name: existing?.name ?? competitionName,
          country: Value(existing?.country),
          updatedAtUtc: now,
        ),
      );
}

Future<void> _ensureTeam(
  AppServices services, {
  required String teamId,
  required String? teamName,
  required String? competitionId,
  required DateTime now,
}) async {
  final existing = await services.database.readTeamById(teamId);
  await services.database.into(services.database.teams).insertOnConflictUpdate(
    TeamsCompanion.insert(
      id: teamId,
      name: teamName ?? existing?.name ?? 'Unknown Team',
      shortName: Value(existing?.shortName),
      competitionId: Value(competitionId ?? existing?.competitionId),
      updatedAtUtc: now,
    ),
  );
}

Future<void> _ensurePlayer(
  AppServices services, {
  required String playerId,
  required String? playerName,
  required String? teamId,
  required DateTime now,
}) async {
  final existing = await services.database.readPlayerById(playerId);
  if (existing != null) {
    return;
  }

  await services.database.into(services.database.players).insert(
    PlayersCompanion.insert(
      id: playerId,
      teamId: Value(teamId),
      name: playerName ?? 'Unknown Player',
      position: const Value(null),
      jerseyNumber: const Value(null),
      photoAssetKey: const Value(null),
      updatedAtUtc: now,
    ),
  );
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) {
        result[key] = entry.value;
      }
    }
    return result;
  }
  return null;
}

List<dynamic>? _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return null;
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

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is int) {
    if (value > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
  }
  if (value is num) {
    final intValue = value.toInt();
    return _dateTimeValue(intValue);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return parsed.toUtc();
    }

    final asInt = int.tryParse(trimmed);
    if (asInt != null) {
      return _dateTimeValue(asInt);
    }
  }
  return null;
}

String _competitionIdFromLeagueKey(String key) {
  return _fotmobLeagueIdByKey[key] ?? key;
}

String _competitionNameFromLeagueKey(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _normalizeLeagueName(String name) {
  return name
      .replaceAll('-', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        if (lower.length <= 2) {
          return lower.toUpperCase();
        }
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

const Map<String, String> _fotmobLeagueIdByKey = {
  'premier_league': '47',
  'europa_league': '73',
  'champions_league': '42',
  'laliga': '87',
  'bundesliga': '54',
  'serie_a': '55',
  'ligue1': '53',
  'fa_cup': '132',
};
