import 'dart:convert';

class ParsedPlayerCompetition {
  const ParsedPlayerCompetition({required this.id, required this.name});

  final String id;
  final String name;
}

class ParsedPlayerTeam {
  const ParsedPlayerTeam({
    required this.id,
    required this.name,
    this.competitionId,
  });

  final String id;
  final String name;
  final String? competitionId;
}

class ParsedPlayer {
  const ParsedPlayer({
    required this.id,
    required this.teamId,
    required this.competitionId,
    required this.name,
    this.teamName,
    this.competitionName,
    this.position,
    this.jerseyNumber,
  });

  final String id;
  final String? teamId;
  final String? competitionId;
  final String name;
  final String? teamName;
  final String? competitionName;
  final String? position;
  final int? jerseyNumber;
}

class PlayersParseResult {
  const PlayersParseResult({
    required this.players,
    required this.competitions,
    required this.teams,
  });

  final List<ParsedPlayer> players;
  final List<ParsedPlayerCompetition> competitions;
  final List<ParsedPlayerTeam> teams;
}

class PlayersParser {
  PlayersParseResult parse(String jsonContent) {
    return parseDecoded(jsonDecode(jsonContent));
  }

  PlayersParseResult parseDecoded(dynamic decoded) {
    final nested = _parseNestedLeaguePayload(decoded);
    if (nested != null) {
      return nested;
    }

    final rows = _extractRows(decoded);
    final players = <ParsedPlayer>[];
    final competitionById = <String, ParsedPlayerCompetition>{};
    final teamById = <String, ParsedPlayerTeam>{};

    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final playerId = _readString(row, ['id', 'playerId', 'player_id']);
      final playerName = _readString(row, ['name', 'playerName', 'fullName']);
      if (playerId == null || playerName == null) {
        continue;
      }

      final teamId = _nestedString(
            row,
            parentKeys: ['team', 'club'],
            childKeys: ['id', 'teamId', 'team_id'],
          ) ??
          _readString(row, ['teamId', 'team_id', 'clubId']);

      final teamName =
          _nestedString(
            row,
            parentKeys: ['team', 'club'],
            childKeys: ['name', 'teamName', 'shortName'],
          ) ??
          _readString(row, ['teamName', 'clubName']);

      final competitionId =
          _nestedString(
            row,
            parentKeys: ['league', 'competition'],
            childKeys: ['id', 'leagueId', 'competitionId'],
          ) ??
          _readString(row, ['leagueId', 'competitionId', 'competition_id']);

      final competitionName =
          _nestedString(
            row,
            parentKeys: ['league', 'competition'],
            childKeys: ['name', 'slug'],
          ) ??
          _readString(row, ['leagueName', 'competitionName', 'leagueKey']);

      if (competitionId != null) {
        competitionById[competitionId] = ParsedPlayerCompetition(
          id: competitionId,
          name: competitionName ?? 'League $competitionId',
        );
      }

      if (teamId != null && teamName != null) {
        teamById[teamId] = ParsedPlayerTeam(
          id: teamId,
          name: teamName,
          competitionId: competitionId,
        );
      }

      players.add(
        ParsedPlayer(
          id: playerId,
          teamId: teamId,
          competitionId: competitionId,
          name: playerName,
          teamName: teamName,
          competitionName: competitionName,
          position: _readString(row, ['position', 'role']),
          jerseyNumber: _readInt(row, ['jerseyNumber', 'shirtNumber', 'number']),
        ),
      );
    }

    return PlayersParseResult(
      players: players,
      competitions: competitionById.values.toList(growable: false),
      teams: teamById.values.toList(growable: false),
    );
  }

  PlayersParseResult? _parseNestedLeaguePayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final leagues = decoded['leagues'];
    if (leagues is! Map<String, dynamic>) {
      return null;
    }

    final playersById = <String, ParsedPlayer>{};
    final competitionById = <String, ParsedPlayerCompetition>{};
    final teamById = <String, ParsedPlayerTeam>{};

    for (final leagueEntry in leagues.entries) {
      final leagueRoot = leagueEntry.value;
      if (leagueRoot is! Map<String, dynamic>) {
        continue;
      }

      final leagueMeta =
          leagueRoot['meta'] is Map<String, dynamic>
              ? leagueRoot['meta'] as Map<String, dynamic>
              : const <String, dynamic>{};

      final leagueId =
          _readString(leagueMeta, ['leagueId', 'id']) ??
          _readString({'leagueId': leagueEntry.key}, ['leagueId']);
      final leagueName = _deriveLeagueName(leagueEntry.key, leagueMeta);

      if (leagueId != null) {
        competitionById[leagueId] = ParsedPlayerCompetition(
          id: leagueId,
          name: leagueName,
        );
      }

      final selectedTeams = leagueRoot['selectedTeams'];
      if (selectedTeams is! List) {
        continue;
      }

      for (final rawTeam in selectedTeams) {
        if (rawTeam is! Map<String, dynamic>) {
          continue;
        }

        final teamId = _readString(rawTeam, ['teamId', 'id']);
        final teamName = _readString(rawTeam, ['teamName', 'name', 'shortName']);
        if (teamId == null || teamName == null) {
          continue;
        }

        teamById[teamId] = ParsedPlayerTeam(
          id: teamId,
          name: teamName,
          competitionId: leagueId,
        );

        final players = rawTeam['players'];
        if (players is! List) {
          continue;
        }

        for (final rawPlayer in players) {
          if (rawPlayer is! Map<String, dynamic>) {
            continue;
          }

          final playerId = _readString(rawPlayer, ['playerId', 'id']);
          final playerName = _readString(rawPlayer, ['name', 'playerName']);
          if (playerId == null || playerName == null) {
            continue;
          }

          // Team placeholder rows can appear as pseudo-players with same id.
          if (playerId == teamId && playerName.toLowerCase() == teamName.toLowerCase()) {
            continue;
          }

          final parsedPlayer = ParsedPlayer(
            id: playerId,
            teamId: _readString(rawPlayer, ['teamId']) ?? teamId,
            competitionId:
                _readString(rawPlayer, ['leagueId', 'competitionId']) ?? leagueId,
            name: playerName,
            teamName: _readString(rawPlayer, ['teamName']) ?? teamName,
            competitionName: leagueName,
            position: _resolvePosition(rawPlayer['position']),
            jerseyNumber: _readInt(rawPlayer, ['shirtNo', 'shirtNumber', 'jerseyNumber']),
          );

          final existing = playersById[playerId];
          if (existing == null || _playerQuality(parsedPlayer) >= _playerQuality(existing)) {
            playersById[playerId] = parsedPlayer;
          }
        }
      }
    }

    return PlayersParseResult(
      players: playersById.values.toList(growable: false),
      competitions: competitionById.values.toList(growable: false),
      teams: teamById.values.toList(growable: false),
    );
  }

  int _playerQuality(ParsedPlayer player) {
    var score = 0;
    if (player.teamId != null) {
      score += 2;
    }
    if (player.competitionId != null) {
      score += 2;
    }
    if (player.position != null && player.position!.trim().isNotEmpty) {
      score += 1;
    }
    if (player.jerseyNumber != null) {
      score += 1;
    }
    return score;
  }

  String _deriveLeagueName(String leagueKey, Map<String, dynamic> leagueMeta) {
    final slug = _readString(leagueMeta, ['slug']);
    if (slug != null && slug.trim().isNotEmpty) {
      return slug
          .replaceAll('-', ' ')
          .split(' ')
          .where((part) => part.trim().isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
    }

    return leagueKey
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String? _resolvePosition(dynamic rawPosition) {
    if (rawPosition is String && rawPosition.trim().isNotEmpty) {
      return rawPosition.trim();
    }

    if (rawPosition is! Map<String, dynamic>) {
      return null;
    }

    final label = _readString(rawPosition, ['label', 'fallback']);
    if (label != null && label.trim().isNotEmpty) {
      return label;
    }

    return _readString(rawPosition, ['key']);
  }

  List<dynamic> _extractRows(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      const keys = ['players', 'squad', 'data', 'items'];
      for (final key in keys) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }
      }
    }

    return const [];
  }

  String? _readString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  String? _nestedString(
    Map<String, dynamic> row, {
    required List<String> parentKeys,
    required List<String> childKeys,
  }) {
    for (final parentKey in parentKeys) {
      final parent = row[parentKey];
      if (parent is! Map) {
        continue;
      }

      for (final childKey in childKeys) {
        final value = parent[childKey];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        if (value is num) {
          return value.toString();
        }
      }
    }

    return null;
  }
}