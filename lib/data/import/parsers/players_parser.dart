import 'dart:convert';

class ParsedPlayer {
  const ParsedPlayer({
    required this.id,
    required this.teamId,
    required this.name,
    this.position,
    this.jerseyNumber,
  });

  final String id;
  final String? teamId;
  final String name;
  final String? position;
  final int? jerseyNumber;
}

class PlayersParseResult {
  const PlayersParseResult({required this.players});

  final List<ParsedPlayer> players;
}

class PlayersParser {
  PlayersParseResult parse(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    final rows = _extractRows(decoded);
    final players = <ParsedPlayer>[];

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

      players.add(
        ParsedPlayer(
          id: playerId,
          teamId: teamId,
          name: playerName,
          position: _readString(row, ['position', 'role']),
          jerseyNumber: _readInt(row, ['jerseyNumber', 'shirtNumber', 'number']),
        ),
      );
    }

    return PlayersParseResult(players: players);
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