import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/parsers/players_parser.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class PlayerProfileInfo {
  const PlayerProfileInfo({
    this.nationality,
    this.country,
    this.birthDate,
    this.age,
    this.height,
    this.weight,
    this.preferredFoot,
    this.summary,
    this.stats = const {},
  });

  final String? nationality;
  final String? country;
  final String? birthDate;
  final String? age;
  final String? height;
  final String? weight;
  final String? preferredFoot;
  final String? summary;
  final Map<String, String> stats;

  bool get hasExtendedInfo {
    return nationality != null ||
        country != null ||
        birthDate != null ||
        age != null ||
        height != null ||
        weight != null ||
        preferredFoot != null ||
        (summary != null && summary!.trim().isNotEmpty) ||
        stats.isNotEmpty;
  }
}

class PlayerDetailState {
  const PlayerDetailState({
    required this.requestedPlayerId,
    required this.resolvedPlayerId,
    required this.player,
    required this.team,
    required this.competition,
    required this.profile,
    required this.debugLogs,
  });

  final String requestedPlayerId;
  final String? resolvedPlayerId;
  final PlayerRow? player;
  final TeamRow? team;
  final CompetitionRow? competition;
  final PlayerProfileInfo profile;
  final List<String> debugLogs;

  bool get isResolved => player != null;
}

class _ResolvedDbPlayer {
  const _ResolvedDbPlayer({
    required this.playerId,
    required this.player,
    required this.team,
    required this.competition,
  });

  final String playerId;
  final PlayerRow player;
  final TeamRow? team;
  final CompetitionRow? competition;
}

class _HydratedPlayerResult {
  const _HydratedPlayerResult({
    required this.playerId,
    this.rawPlayerNode,
    this.source,
  });

  final String playerId;
  final Map<String, dynamic>? rawPlayerNode;
  final String? source;
}

typedef _LogFn = void Function(String message, {bool warn});

const _defaultMaxPlayerFilesToScan = 280;

final playerDetailProvider = FutureProvider.family<PlayerDetailState, String>((
  ref,
  playerId,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));

  final services = ref.read(appServicesProvider);

  final diagnostics = <String>[];
  void log(String message, {bool warn = false}) {
    final line = '[PlayerDetail] $message';
    diagnostics.add(line);
    if (warn) {
      services.logger.warn(line);
    } else {
      services.logger.info(line);
    }
  }

  final candidateIds = _buildCandidatePlayerIds(playerId);
  log('Incoming route playerId="$playerId".');
  log('Candidate IDs: ${candidateIds.join(', ')}.');

  Map<String, dynamic>? rawProfileNode;

  var resolved = await _resolveFromDatabase(
    services: services,
    candidateIds: candidateIds,
    log: log,
  );

  if (resolved == null) {
    final hydrated = await _hydratePlayerFromLocalJson(
      services: services,
      candidateIds: candidateIds,
      log: log,
    );
    if (hydrated != null) {
      rawProfileNode = hydrated.rawPlayerNode;
      if (hydrated.source != null) {
        log('Hydrated player candidate from ${hydrated.source}.');
      }

      resolved = await _resolveFromDatabase(
        services: services,
        candidateIds: <String>{hydrated.playerId, ...candidateIds},
        log: log,
      );
    }
  }

  if (resolved == null) {
    log(
      'Unable to resolve player detail for "$playerId" from DB and local JSON.',
      warn: true,
    );
    return PlayerDetailState(
      requestedPlayerId: playerId,
      resolvedPlayerId: null,
      player: null,
      team: null,
      competition: null,
      profile: const PlayerProfileInfo(),
      debugLogs: List.unmodifiable(diagnostics),
    );
  }

  final profile = _buildProfileInfo(rawProfileNode);
  log('Resolved player id "${resolved.playerId}".');

  return PlayerDetailState(
    requestedPlayerId: playerId,
    resolvedPlayerId: resolved.playerId,
    player: resolved.player,
    team: resolved.team,
    competition: resolved.competition,
    profile: profile,
    debugLogs: List.unmodifiable(diagnostics),
  );
});

Set<String> _buildCandidatePlayerIds(String routePlayerId) {
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

  add(routePlayerId);

  try {
    add(Uri.decodeComponent(routePlayerId));
  } catch (_) {
    // Ignore malformed URI sequences.
  }

  final lower = routePlayerId.toLowerCase();
  if (lower.startsWith('player_')) {
    add(routePlayerId.substring('player_'.length));
  }
  if (lower.startsWith('person_')) {
    add(routePlayerId.substring('person_'.length));
  }
  if (lower.startsWith('id:')) {
    add(routePlayerId.substring(3));
  }
  if (lower.startsWith('player:')) {
    add(routePlayerId.substring(7));
  }

  final digitMatches = RegExp(r'\d{4,}').allMatches(routePlayerId);
  for (final match in digitMatches) {
    add(match.group(0));
  }

  return candidates;
}

Future<_ResolvedDbPlayer?> _resolveFromDatabase({
  required AppServices services,
  required Iterable<String> candidateIds,
  required _LogFn log,
}) async {
  for (final candidate in candidateIds) {
    final player = await services.database.readPlayerById(candidate);
    if (player == null) {
      log('DB miss for player id "$candidate".');
      continue;
    }

    final team =
        player.teamId == null
            ? null
            : await services.database.readTeamById(player.teamId!);
    final competition =
        team?.competitionId == null
            ? null
            : await services.database.readCompetitionById(team!.competitionId!);

    log('DB hit for player id "$candidate".');

    return _ResolvedDbPlayer(
      playerId: candidate,
      player: player,
      team: team,
      competition: competition,
    );
  }

  return null;
}

Future<_HydratedPlayerResult?> _hydratePlayerFromLocalJson({
  required AppServices services,
  required Set<String> candidateIds,
  required _LogFn log,
}) async {
  final fromTeamRaw = await _hydrateFromTeamRawBundle(
    services: services,
    candidateIds: candidateIds,
    log: log,
  );
  if (fromTeamRaw != null) {
    return fromTeamRaw;
  }

  Directory root;
  try {
    root = await services.daylySportLocator.getOrCreateDaylySportDirectory();
  } catch (error) {
    log('Failed to resolve daylysport path: $error', warn: true);
    return null;
  }

  log('Resolved daylysport path: ${root.path}');

  if (!await root.exists()) {
    log('daylysport path does not exist.', warn: true);
    return null;
  }

  final files = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
      files.add(entity);
    }
  }

  if (files.isEmpty) {
    log('No JSON files found under daylysport path.', warn: true);
    return null;
  }

  files.sort(
    (a, b) => _playerJsonPriority(a.path, candidateIds).compareTo(
      _playerJsonPriority(b.path, candidateIds),
    ),
  );

  final parser = PlayersParser();
  final scanFiles = files.take(_defaultMaxPlayerFilesToScan);

  for (final file in scanFiles) {
    final lowerName = p.basename(file.path).toLowerCase();
    if (!_looksLikePlayerDataFile(lowerName, candidateIds)) {
      continue;
    }

    String raw;
    try {
      raw = await file.readAsString();
    } catch (error) {
      log('Unable to read ${file.path}: $error', warn: true);
      continue;
    }

    if (!_textMayContainCandidate(raw, candidateIds) &&
        !_isKnownPlayerCatalogFile(lowerName)) {
      continue;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      continue;
    }

    final parsed = parser.parseDecoded(decoded);
    for (final player in parsed.players) {
      if (!_isCandidateId(player.id, candidateIds)) {
        continue;
      }

      await _upsertParsedPlayer(
        services,
        parsed,
        player,
        sourceLabel: file.path,
        log: log,
      );

      final rawPlayer = _findPlayerNodeInRaw(decoded, candidateIds);
      return _HydratedPlayerResult(
        playerId: player.id,
        rawPlayerNode: rawPlayer,
        source: file.path,
      );
    }

    final rawPlayer = _findPlayerNodeInRaw(decoded, candidateIds);
    if (rawPlayer != null) {
      final inferred = _parsedPlayerFromRaw(rawPlayer);
      if (inferred != null) {
        await _upsertParsedPlayer(
          services,
          const PlayersParseResult(players: [], competitions: [], teams: []),
          inferred,
          sourceLabel: file.path,
          log: log,
        );
        return _HydratedPlayerResult(
          playerId: inferred.id,
          rawPlayerNode: rawPlayer,
          source: file.path,
        );
      }
    }
  }

  log(
    'No matching player payload found in local JSON for ids: ${candidateIds.join(', ')}.',
    warn: true,
  );
  return null;
}

Future<_HydratedPlayerResult?> _hydrateFromTeamRawBundle({
  required AppServices services,
  required Set<String> candidateIds,
  required _LogFn log,
}) async {
  try {
    final bundle = await services.teamRawSource.loadBundle();
    if (bundle.byTeamId.isEmpty) {
      return null;
    }

    for (final entry in bundle.byTeamId.values) {
      final rawPlayer = _findPlayerNodeInRaw(entry.raw, candidateIds);
      if (rawPlayer == null) {
        continue;
      }

      final fallbackTeamId = _stringValue(_deepFind(rawPlayer, const ['teamId'])) ?? entry.teamId;
      final fallbackTeamName =
          _stringValue(_deepFind(rawPlayer, const ['teamName'])) ??
          _stringValue(_deepFind(entry.raw, const ['details', 'name']));
      final fallbackCompetitionId =
          _stringValue(_deepFind(rawPlayer, const ['leagueId'])) ??
          _stringValue(entry.meta['leagueId']);
      final fallbackCompetitionName =
          _stringValue(_deepFind(rawPlayer, const ['leagueName'])) ??
          _stringValue(entry.meta['slug']);

      final inferred = _parsedPlayerFromRaw(
        rawPlayer,
        fallbackTeamId: fallbackTeamId,
        fallbackTeamName: fallbackTeamName,
        fallbackCompetitionId: fallbackCompetitionId,
        fallbackCompetitionName: fallbackCompetitionName,
      );
      if (inferred == null) {
        continue;
      }

      await _upsertParsedPlayer(
        services,
        const PlayersParseResult(players: [], competitions: [], teams: []),
        inferred,
        sourceLabel: 'team-raw-bundle',
        log: log,
      );

      return _HydratedPlayerResult(
        playerId: inferred.id,
        rawPlayerNode: rawPlayer,
        source: 'team-raw-bundle',
      );
    }
  } catch (error) {
    log('Unable to inspect team raw bundle: $error', warn: true);
  }

  return null;
}

Future<void> _upsertParsedPlayer(
  AppServices services,
  PlayersParseResult parsedResult,
  ParsedPlayer player, {
  required String sourceLabel,
  required _LogFn log,
}) async {
  final now = DateTime.now().toUtc();

  await services.database.transaction(() async {
    for (final competition in parsedResult.competitions) {
      await _ensureCompetition(
        services,
        competitionId: competition.id,
        competitionName: competition.name,
        now: now,
      );
    }

    for (final team in parsedResult.teams) {
      await _ensureTeam(
        services,
        teamId: team.id,
        teamName: team.name,
        competitionId: team.competitionId,
        now: now,
      );
    }

    if (player.competitionId != null) {
      await _ensureCompetition(
        services,
        competitionId: player.competitionId!,
        competitionName:
            player.competitionName ?? 'League ${player.competitionId}',
        now: now,
      );
    }

    if (player.teamId != null) {
      await _ensureTeam(
        services,
        teamId: player.teamId!,
        teamName: player.teamName,
        competitionId: player.competitionId,
        now: now,
      );
    }

    final existing = await services.database.readPlayerById(player.id);

    await services.database.into(services.database.players).insertOnConflictUpdate(
      PlayersCompanion.insert(
        id: player.id,
        teamId: Value(player.teamId ?? existing?.teamId),
        name: player.name,
        position: Value(player.position ?? existing?.position),
        jerseyNumber: Value(player.jerseyNumber ?? existing?.jerseyNumber),
        photoAssetKey: Value(existing?.photoAssetKey),
        updatedAtUtc: now,
      ),
    );
  });

  log('Hydrated player row for "${player.id}" from $sourceLabel.');
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
          name: existing?.name ?? _normalizeLeagueName(competitionName),
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

PlayerProfileInfo _buildProfileInfo(Map<String, dynamic>? rawPlayer) {
  if (rawPlayer == null) {
    return const PlayerProfileInfo();
  }

  String? stringify(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  String? pick(List<String> keys) {
    return stringify(_deepFind(rawPlayer, keys));
  }

  final stats = <String, String>{};
  final statMap = _asMap(_deepFind(rawPlayer, const ['stats']));
  if (statMap != null) {
    const preferredKeys = [
      'appearances',
      'minutes',
      'goals',
      'assists',
      'xg',
      'xa',
      'rating',
      'cleanSheets',
      'saves',
    ];
    for (final key in preferredKeys) {
      final value = stringify(statMap[key]);
      if (value != null) {
        stats[_prettyLabel(key)] = value;
      }
    }
  }

  final age = pick(const ['age']);
  final birthDate = pick(const ['birthDate']) ??
      pick(const ['dateOfBirth']) ??
      pick(const ['dob']);

  return PlayerProfileInfo(
    nationality:
        pick(const ['nationality']) ?? pick(const ['nationalityName']),
    country:
        pick(const ['country']) ??
        pick(const ['countryName']) ??
        pick(const ['nation']),
    birthDate: birthDate,
    age: age,
    height:
        pick(const ['height']) ??
        pick(const ['heightCm']) ??
        pick(const ['heightInCm']),
    weight:
        pick(const ['weight']) ??
        pick(const ['weightKg']) ??
        pick(const ['weightInKg']),
    preferredFoot:
        pick(const ['preferredFoot']) ??
        pick(const ['foot']) ??
        pick(const ['strongFoot']),
    summary:
        pick(const ['summary']) ??
        pick(const ['about']) ??
        pick(const ['biography']) ??
        pick(const ['description']),
    stats: stats,
  );
}

int _playerJsonPriority(String path, Set<String> candidateIds) {
  final lower = path.toLowerCase();
  if (candidateIds.any((id) => id.length >= 4 && lower.contains(id))) {
    return 0;
  }
  if (lower.contains('player_detail') || lower.contains('player-detail')) {
    return 1;
  }
  if (lower.contains('players') || lower.contains('squad')) {
    return 2;
  }
  if (lower.contains('full_player_stats') || lower.contains('top_score')) {
    return 3;
  }
  if (lower.contains('team')) {
    return 4;
  }
  return 12;
}

bool _looksLikePlayerDataFile(String lowerName, Set<String> candidateIds) {
  if (candidateIds.any((id) => id.length >= 4 && lowerName.contains(id))) {
    return true;
  }

  return lowerName.contains('player') ||
      lowerName.contains('squad') ||
      lowerName.contains('team') ||
      lowerName.contains('top_score');
}

bool _isKnownPlayerCatalogFile(String lowerName) {
  return lowerName == 'fotmob_full_player_stats.json' ||
      lowerName == 'top_score_data.json' ||
      lowerName == 'fotmob_teams_from_top_leagues_plus_fc26_ready.json';
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

bool _isCandidateId(String? value, Set<String> candidateIds) {
  if (value == null || value.trim().isEmpty) {
    return false;
  }
  final normalized = value.trim();
  if (candidateIds.contains(normalized)) {
    return true;
  }

  for (final match in RegExp(r'\d{4,}').allMatches(normalized)) {
    final token = match.group(0);
    if (token != null && candidateIds.contains(token)) {
      return true;
    }
  }

  return false;
}

Map<String, dynamic>? _findPlayerNodeInRaw(dynamic node, Set<String> candidateIds) {
  if (candidateIds.isEmpty) {
    return null;
  }

  Map<String, dynamic>? visit(dynamic current, int depth) {
    if (depth > 12) {
      return null;
    }

    final map = _asMap(current);
    if (map != null) {
      final id =
          _stringValue(map['id']) ??
          _stringValue(map['playerId']) ??
          _stringValue(map['personId']);
      final name =
          _stringValue(map['name']) ??
          _stringValue(map['playerName']) ??
          _stringValue(map['fullName']);

      if (name != null && _isCandidateId(id, candidateIds)) {
        return map;
      }

      for (final value in map.values) {
        final nested = visit(value, depth + 1);
        if (nested != null) {
          return nested;
        }
      }

      return null;
    }

    if (current is List) {
      for (final item in current) {
        final nested = visit(item, depth + 1);
        if (nested != null) {
          return nested;
        }
      }
    }

    return null;
  }

  return visit(node, 0);
}

ParsedPlayer? _parsedPlayerFromRaw(
  Map<String, dynamic> raw, {
  String? fallbackTeamId,
  String? fallbackTeamName,
  String? fallbackCompetitionId,
  String? fallbackCompetitionName,
}) {
  final id =
      _stringValue(raw['id']) ??
      _stringValue(raw['playerId']) ??
      _stringValue(raw['personId']);
  final name =
      _stringValue(raw['name']) ??
      _stringValue(raw['playerName']) ??
      _stringValue(raw['fullName']);

  if (id == null || name == null) {
    return null;
  }

  final team = _asMap(raw['team']) ?? _asMap(raw['club']);
  final competition = _asMap(raw['league']) ?? _asMap(raw['competition']);
  final positionNode = raw['position'];

  String? position;
  if (positionNode is String && positionNode.trim().isNotEmpty) {
    position = positionNode.trim();
  } else {
    final positionMap = _asMap(positionNode);
    position =
        _stringValue(positionMap?['label']) ??
        _stringValue(positionMap?['short']) ??
        _stringValue(positionMap?['name']) ??
        _stringValue(positionMap?['key']);
  }

  return ParsedPlayer(
    id: id,
    teamId:
        _stringValue(raw['teamId']) ??
        _stringValue(team?['id']) ??
        _stringValue(team?['teamId']) ??
        fallbackTeamId,
    competitionId:
        _stringValue(raw['competitionId']) ??
        _stringValue(raw['leagueId']) ??
        _stringValue(competition?['id']) ??
        _stringValue(competition?['leagueId']) ??
        fallbackCompetitionId,
    name: name,
    teamName:
        _stringValue(raw['teamName']) ??
        _stringValue(team?['name']) ??
        _stringValue(team?['teamName']) ??
        fallbackTeamName,
    competitionName:
        _stringValue(raw['competitionName']) ??
        _stringValue(raw['leagueName']) ??
        _stringValue(competition?['name']) ??
        _stringValue(competition?['slug']) ??
        fallbackCompetitionName,
    position: position,
    jerseyNumber:
        _intValue(raw['shirtNumber']) ??
        _intValue(raw['jerseyNumber']) ??
        _intValue(raw['number']),
  );
}

dynamic _deepFind(dynamic node, List<String> keyPath, {int depth = 0}) {
  if (keyPath.isEmpty || depth > 14) {
    return null;
  }

  final map = _asMap(node);
  if (map == null) {
    if (node is List) {
      for (final item in node) {
        final found = _deepFind(item, keyPath, depth: depth + 1);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  final head = keyPath.first;
  final matchedEntry = map.entries.where((entry) {
    return entry.key.toLowerCase() == head.toLowerCase();
  }).firstOrNull;
  if (matchedEntry != null) {
    if (keyPath.length == 1) {
      return matchedEntry.value;
    }
    return _deepFind(matchedEntry.value, keyPath.sublist(1), depth: depth + 1);
  }

  for (final value in map.values) {
    final found = _deepFind(value, keyPath, depth: depth + 1);
    if (found != null) {
      return found;
    }
  }

  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is String) {
        result[entry.key as String] = entry.value;
      }
    }
    return result;
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

String _prettyLabel(String raw) {
  return raw
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
