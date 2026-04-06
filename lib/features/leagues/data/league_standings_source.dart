import 'dart:convert';

import 'package:flutter/services.dart';

const List<String> kPreferredStandingsModeOrder = [
  'all',
  'home',
  'away',
  'form',
  'xg',
];

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
    AssetBundle? assetBundle,
    this.assetPath = 'assets/manifest/top_standings_full_data.json',
  }) : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final String assetPath;

  LeagueStandingsBundle? _cachedBundle;

  Future<LeagueStandingsBundle> loadBundle() async {
    final cached = _cachedBundle;
    if (cached != null) {
      return cached;
    }

    try {
      final raw = await _assetBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      final parsed = LeagueStandingsBundle.fromJson(decoded);
      _cachedBundle = parsed;
      return parsed;
    } catch (_) {
      const empty = LeagueStandingsBundle.empty();
      _cachedBundle = empty;
      return empty;
    }
  }

  Future<LeagueStandingsLeague?> readLeagueByCompetitionId(
    String competitionId,
  ) async {
    final bundle = await loadBundle();
    return bundle.resolveLeague(competitionId);
  }

  void invalidateCache() {
    _cachedBundle = null;
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

    final table = standings['table'];
    if (table is! Map<String, dynamic>) {
      return null;
    }

    final parsedModes = <String, LeagueStandingsModeData>{};

    for (final entry in table.entries) {
      final modeKey = _normalizeKey(entry.key);
      final rawRows = entry.value;
      if (rawRows is! List) {
        continue;
      }

      final rows = <LeagueStandingsRow>[];
      for (var i = 0; i < rawRows.length; i++) {
        final rawRow = rawRows[i];
        if (rawRow is! Map<String, dynamic>) {
          continue;
        }

        rows.add(LeagueStandingsRow.fromJson(rawRow, fallbackPosition: i + 1));
      }

      parsedModes[modeKey] = LeagueStandingsModeData(
        key: modeKey,
        label: standingsModeLabel(modeKey),
        rows: List.unmodifiable(rows),
      );
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
