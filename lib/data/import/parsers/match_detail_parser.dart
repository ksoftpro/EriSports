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

    final general = _readMap(decoded, ['general']);
    final summary = _readMap(decoded, ['summary']);

    final matchId =
        _readString(decoded, ['matchId', 'id', 'fixtureId']) ??
        _readString(general, ['matchId', 'id', 'fixtureId']) ??
        _readString(summary, ['matchId', 'id', 'fixtureId']);
    if (matchId == null) {
      return null;
    }

    final homeTeam =
        _readMap(decoded, ['homeTeam']) ??
        _readMap(summary, ['homeTeam']) ??
        _readMap(general, ['homeTeam']);
    final awayTeam =
        _readMap(decoded, ['awayTeam']) ??
        _readMap(summary, ['awayTeam']) ??
        _readMap(general, ['awayTeam']);

    final homeTeamId =
        _readString(decoded, ['homeTeamId', 'home_team_id']) ??
        _readString(homeTeam, ['id', 'teamId', 'team_id']);
    final awayTeamId =
        _readString(decoded, ['awayTeamId', 'away_team_id']) ??
        _readString(awayTeam, ['id', 'teamId', 'team_id']);

    final events = _parseEvents(
      decoded,
      matchId,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
    );
    final stats = _parseStats(
      decoded,
      matchId,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
    );
    return MatchDetailParseResult(
      matchId: matchId,
      events: events,
      stats: stats,
    );
  }

  List<ParsedMatchEvent> _parseEvents(
    Map<String, dynamic> root,
    String matchId, {
    required String? homeTeamId,
    required String? awayTeamId,
  }) {
    final rawList = <dynamic>[
      ..._extractList(root, ['events', 'timeline', 'incidents']),
      ..._extractListAtPath(root, [
        'content',
        'matchFacts',
        'events',
        'events',
      ]),
      ..._extractListAtPath(root, ['matchFacts', 'events', 'events']),
    ];

    final events = <ParsedMatchEvent>[];

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final minute = _parseMinute(item);
      final type =
          _readString(item, ['type', 'eventType', 'incidentType']) ?? 'event';

      var teamId =
          _readString(item, ['teamId', 'team_id']) ??
          _readString(_readMap(item, ['team']), ['id', 'teamId', 'team_id']);

      final isHome = _readBool(item, ['isHome', 'homeTeam']);
      if (teamId == null && isHome != null) {
        teamId = isHome ? homeTeamId : awayTeamId;
      }

      final player = _readMap(item, ['player']);
      final playerId =
          _readString(item, ['playerId', 'player_id']) ??
          _readString(player, ['id', 'playerId', 'player_id']);
      final playerName =
          _readString(item, ['playerName', 'name', 'participantName']) ??
          _readString(player, ['name']);

      final detail =
          _readString(item, ['detail', 'description', 'text', 'assistStr']) ??
          _readString(_readMap(item, ['assist']), ['name']);

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
    String matchId, {
    required String? homeTeamId,
    required String? awayTeamId,
  }) {
    final stats = <ParsedMatchTeamStat>[];

    final statsList = <dynamic>[
      ..._extractList(root, ['stats', 'statistics']),
      ..._extractListAtPath(root, ['content', 'stats']),
    ];

    for (final stat in statsList) {
      if (stat is! Map<String, dynamic>) {
        continue;
      }

      final key = _readString(stat, ['key', 'name', 'statKey']);
      if (key == null) {
        continue;
      }

      final statHomeTeamId =
          _readString(stat, ['homeTeamId', 'home_team_id']) ?? homeTeamId;
      final statAwayTeamId =
          _readString(stat, ['awayTeamId', 'away_team_id']) ?? awayTeamId;

      var homeValue = _readDouble(stat, ['homeValue', 'home', 'valueHome']);
      var awayValue = _readDouble(stat, ['awayValue', 'away', 'valueAway']);

      final pair = stat['stats'];
      if ((homeValue == null || awayValue == null) &&
          pair is List &&
          pair.length >= 2) {
        homeValue ??= _asDouble(pair[0]);
        awayValue ??= _asDouble(pair[1]);
      }

      if (statHomeTeamId != null && homeValue != null) {
        stats.add(
          ParsedMatchTeamStat(
            matchId: matchId,
            teamId: statHomeTeamId,
            statKey: key,
            statValue: homeValue,
          ),
        );
      }

      if (statAwayTeamId != null && awayValue != null) {
        stats.add(
          ParsedMatchTeamStat(
            matchId: matchId,
            teamId: statAwayTeamId,
            statKey: key,
            statValue: awayValue,
          ),
        );
      }
    }

    final periods = _extractListAtPath(root, [
      'content',
      'matchFacts',
      'stats',
      'Periods',
    ]);
    for (final period in periods) {
      if (period is! Map<String, dynamic>) {
        continue;
      }

      final periodStats = _extractList(period, ['stats', 'items']);
      for (final item in periodStats) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final key = _readString(item, [
          'key',
          'name',
          'title',
          'label',
          'statKey',
        ]);
        if (key == null) {
          continue;
        }

        var homeValue = _readDouble(item, ['homeValue', 'home', 'valueHome']);
        var awayValue = _readDouble(item, ['awayValue', 'away', 'valueAway']);

        final pair = item['stats'];
        if ((homeValue == null || awayValue == null) &&
            pair is List &&
            pair.length >= 2) {
          homeValue ??= _asDouble(pair[0]);
          awayValue ??= _asDouble(pair[1]);
        }

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
    }

    final nested = root['teamStats'];
    if (nested is Map<String, dynamic>) {
      final home = nested['home'];
      final away = nested['away'];

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

    final deduped = <String, ParsedMatchTeamStat>{};
    for (final stat in stats) {
      deduped['${stat.teamId}|${stat.statKey.toLowerCase()}'] = stat;
    }
    return deduped.values.toList();
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

  List<dynamic> _extractListAtPath(
    Map<String, dynamic> root,
    List<String> path,
  ) {
    dynamic current = root;
    for (final segment in path) {
      if (current is! Map<String, dynamic>) {
        return const [];
      }
      current = current[segment];
    }
    if (current is List) {
      return current;
    }
    return const [];
  }

  Map<String, dynamic>? _readMap(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }
    return null;
  }

  String? _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
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

  bool? _readBool(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }

  int _parseMinute(Map<String, dynamic> item) {
    final direct = _readInt(item, ['minute', 'matchMinute', 'elapsed']);
    if (direct != null) {
      return direct;
    }

    final timeMap = item['time'];
    if (timeMap is Map<String, dynamic>) {
      final normal =
          _asInt(timeMap['minute']) ?? _asInt(timeMap['normalTime']) ?? 0;
      final added = _asInt(timeMap['addedTime']) ?? 0;
      if (normal > 0 || added > 0) {
        return normal + added;
      }
    }

    final raw = _readString(item, ['time']);
    if (raw == null) {
      return 0;
    }

    final normalized = raw.replaceAll("'", '').trim();
    if (normalized.contains('+')) {
      final parts = normalized.split('+');
      if (parts.length == 2) {
        final base = int.tryParse(parts[0].trim()) ?? 0;
        final added = int.tryParse(parts[1].trim()) ?? 0;
        return base + added;
      }
    }

    final match = RegExp(r'\d+').firstMatch(normalized);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(0) ?? '') ?? 0;
  }

  int? _readInt(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
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

  double? _readDouble(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
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

  int? _asInt(dynamic value) {
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
}
