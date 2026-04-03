import 'dart:convert';

class ParsedMatchEvent {
  const ParsedMatchEvent({
    required this.matchId,
    required this.minute,
    required this.eventType,
    this.teamId,
    this.playerId,
    this.playerName,
    this.detail,
  });

  final String matchId;
  final int minute;
  final String eventType;
  final String? teamId;
  final String? playerId;
  final String? playerName;
  final String? detail;
}

class ParsedMatchTeamStat {
  const ParsedMatchTeamStat({
    required this.matchId,
    required this.teamId,
    required this.statKey,
    required this.statValue,
  });

  final String matchId;
  final String teamId;
  final String statKey;
  final double statValue;
}

class MatchDetailParseResult {
  const MatchDetailParseResult({
    required this.matchId,
    required this.events,
    required this.stats,
  });

  final String matchId;
  final List<ParsedMatchEvent> events;
  final List<ParsedMatchTeamStat> stats;
}

class MatchDetailParser {
  MatchDetailParseResult? parse(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final matchId = _readString(decoded, ['matchId', 'id', 'fixtureId']);
    if (matchId == null) {
      return null;
    }

    final events = _parseEvents(decoded, matchId);
    final stats = _parseStats(decoded, matchId);
    return MatchDetailParseResult(matchId: matchId, events: events, stats: stats);
  }

  List<ParsedMatchEvent> _parseEvents(
    Map<String, dynamic> root,
    String matchId,
  ) {
    final rawList = _extractList(root, ['events', 'timeline', 'incidents']);
    final events = <ParsedMatchEvent>[];

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final minute = _readInt(item, ['minute', 'time', 'matchMinute']) ?? 0;
      final type = _readString(item, ['type', 'eventType', 'incidentType']) ??
          'event';
      final teamId = _readString(item, ['teamId', 'team_id']);
      final playerId = _readString(item, ['playerId', 'player_id']);
      final playerName = _readString(item, ['playerName', 'name']);
      final detail = _readString(item, ['detail', 'description', 'text']);

      events.add(
        ParsedMatchEvent(
          matchId: matchId,
          minute: minute,
          eventType: type,
          teamId: teamId,
          playerId: playerId,
          playerName: playerName,
          detail: detail,
        ),
      );
    }

    return events;
  }

  List<ParsedMatchTeamStat> _parseStats(
    Map<String, dynamic> root,
    String matchId,
  ) {
    final stats = <ParsedMatchTeamStat>[];

    final statsList = _extractList(root, ['stats', 'statistics']);
    for (final stat in statsList) {
      if (stat is! Map<String, dynamic>) {
        continue;
      }

      final key = _readString(stat, ['key', 'name', 'statKey']);
      if (key == null) {
        continue;
      }

      final homeTeamId = _readString(stat, ['homeTeamId', 'home_team_id']);
      final awayTeamId = _readString(stat, ['awayTeamId', 'away_team_id']);

      final homeValue = _readDouble(stat, ['homeValue', 'home', 'valueHome']);
      final awayValue = _readDouble(stat, ['awayValue', 'away', 'valueAway']);

      if (homeTeamId != null && homeValue != null) {
        stats.add(
          ParsedMatchTeamStat(
            matchId: matchId,
            teamId: homeTeamId,
            statKey: key,
            statValue: homeValue,
          ),
        );
      }

      if (awayTeamId != null && awayValue != null) {
        stats.add(
          ParsedMatchTeamStat(
            matchId: matchId,
            teamId: awayTeamId,
            statKey: key,
            statValue: awayValue,
          ),
        );
      }
    }

    final nested = root['teamStats'];
    if (nested is Map<String, dynamic>) {
      final home = nested['home'];
      final away = nested['away'];
      final homeTeamId = _readString(root, ['homeTeamId', 'home_team_id']);
      final awayTeamId = _readString(root, ['awayTeamId', 'away_team_id']);

      if (home is Map<String, dynamic> && homeTeamId != null) {
        for (final entry in home.entries) {
          final value = _asDouble(entry.value);
          if (value != null) {
            stats.add(
              ParsedMatchTeamStat(
                matchId: matchId,
                teamId: homeTeamId,
                statKey: entry.key,
                statValue: value,
              ),
            );
          }
        }
      }

      if (away is Map<String, dynamic> && awayTeamId != null) {
        for (final entry in away.entries) {
          final value = _asDouble(entry.value);
          if (value != null) {
            stats.add(
              ParsedMatchTeamStat(
                matchId: matchId,
                teamId: awayTeamId,
                statKey: entry.key,
                statValue: value,
              ),
            );
          }
        }
      }
    }

    return stats;
  }

  List<dynamic> _extractList(Map<String, dynamic> root, List<String> keys) {
    for (final key in keys) {
      final value = root[key];
      if (value is List) {
        return value;
      }
    }
    return const [];
  }

  String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
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

  double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = _asDouble(map[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final cleaned = value.replaceAll('%', '').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }
}