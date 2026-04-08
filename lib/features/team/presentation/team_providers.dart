import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const List<String> _preferredTableModes = ['all', 'home', 'away', 'form', 'xg'];

@immutable
class TeamTabSpec {
  const TeamTabSpec({required this.key, required this.label});

  final String key;
  final String label;
}

@immutable
class TeamIdentityInfo {
  const TeamIdentityInfo({
    required this.teamId,
    required this.name,
    required this.shortName,
    required this.country,
    required this.primaryLeagueId,
    required this.primaryLeagueName,
    required this.latestSeason,
    required this.venue,
    required this.city,
  });

  final String teamId;
  final String name;
  final String? shortName;
  final String? country;
  final String? primaryLeagueId;
  final String? primaryLeagueName;
  final String? latestSeason;
  final String? venue;
  final String? city;
}

@immutable
class TeamColorPalette {
  const TeamColorPalette({
    this.darkMode,
    this.lightMode,
    this.fontDarkMode,
    this.fontLightMode,
  });

  final String? darkMode;
  final String? lightMode;
  final String? fontDarkMode;
  final String? fontLightMode;
}

@immutable
class TeamTableLegendItem {
  const TeamTableLegendItem({
    required this.title,
    required this.colorHex,
    required this.positions,
  });

  final String title;
  final String colorHex;
  final List<int> positions;
}

@immutable
class TeamTableRowItem {
  const TeamTableRowItem({
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
    required this.goalDiff,
    required this.points,
    required this.form,
    required this.qualColor,
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
  final int goalDiff;
  final int points;
  final String? form;
  final String? qualColor;

  String get displayName {
    final short = shortName.trim();
    if (short.isNotEmpty) {
      return short;
    }
    return teamName;
  }
}

@immutable
class TeamTableData {
  const TeamTableData({
    required this.modes,
    required this.legend,
    required this.highlightedTeamId,
    this.tableTitle,
  });

  final Map<String, List<TeamTableRowItem>> modes;
  final List<TeamTableLegendItem> legend;
  final String highlightedTeamId;
  final String? tableTitle;

  bool get hasRows {
    for (final rows in modes.values) {
      if (rows.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<String> get orderedModeKeys {
    final keys = modes.keys.toList(growable: false);
    final preferred = <String>[];
    for (final mode in _preferredTableModes) {
      if (keys.contains(mode)) {
        preferred.add(mode);
      }
    }
    final custom = keys.where((key) => !preferred.contains(key)).toList()
      ..sort();
    return [...preferred, ...custom];
  }

  List<TeamTableRowItem> rowsForMode(String modeKey) {
    final normalized = _normalizeTabKey(modeKey);
    final direct = modes[normalized];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final all = modes['all'];
    if (all != null && all.isNotEmpty) {
      return all;
    }

    for (final key in orderedModeKeys) {
      final rows = modes[key];
      if (rows != null && rows.isNotEmpty) {
        return rows;
      }
    }

    return const [];
  }
}

@immutable
class TeamFixtureItem {
  const TeamFixtureItem({
    required this.matchId,
    required this.kickoffUtc,
    required this.status,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.homeScore,
    required this.awayScore,
    required this.roundLabel,
  });

  final String? matchId;
  final DateTime kickoffUtc;
  final String status;
  final String? homeTeamId;
  final String homeTeamName;
  final String? awayTeamId;
  final String awayTeamName;
  final int? homeScore;
  final int? awayScore;
  final String? roundLabel;
}

@immutable
class TeamSquadItem {
  const TeamSquadItem({
    required this.playerId,
    required this.playerName,
    required this.position,
    required this.shirtNumber,
    required this.teamId,
  });

  final String? playerId;
  final String playerName;
  final String? position;
  final int? shirtNumber;
  final String? teamId;
}

@immutable
class TeamStatHighlight {
  const TeamStatHighlight({
    required this.id,
    required this.title,
    required this.value,
    this.subtitle,
    this.playerId,
    this.teamId,
  });

  final String id;
  final String title;
  final String value;
  final String? subtitle;
  final String? playerId;
  final String? teamId;
}

@immutable
class TeamHistoryItem {
  const TeamHistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

@immutable
class TeamTransferItem {
  const TeamTransferItem({
    required this.playerId,
    required this.playerName,
    required this.position,
    required this.fromTeamId,
    required this.fromTeamName,
    required this.toTeamId,
    required this.toTeamName,
    required this.fee,
    required this.transferDateUtc,
  });

  final String? playerId;
  final String playerName;
  final String? position;
  final String? fromTeamId;
  final String? fromTeamName;
  final String? toTeamId;
  final String? toTeamName;
  final String? fee;
  final DateTime transferDateUtc;
}

class TeamDetailState {
  const TeamDetailState({
    required this.team,
    required this.competition,
    required this.matches,
    required this.players,
    required this.rawTeam,
    required this.rawDetails,
    required this.rawTabs,
    required this.tabs,
    required this.identity,
    required this.availableSeasonLabels,
    required this.teamColors,
    required this.tableData,
    required this.fixtureItems,
    required this.squadItems,
    required this.statHighlights,
    required this.historyItems,
    required this.transferItems,
    required this.formTokens,
  });

  final TeamRow team;
  final CompetitionRow? competition;
  final List<HomeMatchView> matches;
  final List<PlayerRow> players;
  final Map<String, dynamic>? rawTeam;
  final Map<String, dynamic>? rawDetails;
  final List<String> rawTabs;
  final List<TeamTabSpec> tabs;
  final TeamIdentityInfo identity;
  final List<String> availableSeasonLabels;
  final TeamColorPalette? teamColors;
  final TeamTableData? tableData;
  final List<TeamFixtureItem> fixtureItems;
  final List<TeamSquadItem> squadItems;
  final List<TeamStatHighlight> statHighlights;
  final List<TeamHistoryItem> historyItems;
  final List<TeamTransferItem> transferItems;
  final List<String> formTokens;
}

final teamHeaderFollowingProvider = StateProvider.family<bool, String>(
  (ref, _) => false,
);

final teamDetailProvider = FutureProvider.family<TeamDetailState, String>((
  ref,
  teamId,
) async {
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.catalog));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.matches));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.playerStats));
  ref.watch(daylysportRefreshTokenProvider(DaylysportDataDomain.standings));
  final services = ref.read(appServicesProvider);

  final rawEntry = await services.teamRawSource.readTeamById(teamId);
  final rawTeam = rawEntry?.raw;
  final rawDetails = _asMap(rawTeam?['details']);

  final team = await services.database.readTeamById(teamId);
  if (team == null) {
    throw StateError('Team not found: $teamId');
  }

  final competition =
      team.competitionId == null
          ? null
          : await services.database.readCompetitionById(team.competitionId!);
  final matches = await services.database.readTeamMatches(teamId);
  final players = await services.database.readPlayersByTeam(teamId);

  final rawTabs = _stringList(rawTeam?['tabs'])
      .map(_normalizeTabKey)
      .where((key) => key.isNotEmpty)
      .toList(growable: false);

  final tableData = _extractTeamTableData(rawTeam, team.id);
  final fixtureItems = _extractFixtureItems(rawTeam, team.id, matches);
  final squadItems = _extractSquadItems(rawTeam, team.id, players);
  final statHighlights = _extractStatHighlights(rawTeam);
  final historyItems = _extractHistoryItems(rawTeam);
  final transferItems = _extractTransferItems(rawTeam);
  final formTokens = _extractFormTokens(rawTeam, team.id, tableData);

  final tabs = _resolveTeamTabs(
    rawTabs,
    hasTable: tableData?.hasRows ?? false,
    hasFixtures: fixtureItems.isNotEmpty,
    hasSquad: squadItems.isNotEmpty,
    hasStats: statHighlights.isNotEmpty,
    hasHistory: historyItems.isNotEmpty,
    hasTransfers: transferItems.isNotEmpty,
  );

  final identity = _buildIdentityInfo(
    team: team,
    competition: competition,
    rawDetails: rawDetails,
  );

  final seasons = _deriveSeasonLabels(rawTeam, rawDetails, matches, fixtureItems);
  final teamColors = _extractTeamColors(rawTeam);

  return TeamDetailState(
    team: team,
    competition: competition,
    matches: matches,
    players: players,
    rawTeam: rawTeam,
    rawDetails: rawDetails,
    rawTabs: rawTabs,
    tabs: tabs,
    identity: identity,
    availableSeasonLabels: seasons,
    teamColors: teamColors,
    tableData: tableData,
    fixtureItems: fixtureItems,
    squadItems: squadItems,
    statHighlights: statHighlights,
    historyItems: historyItems,
    transferItems: transferItems,
    formTokens: formTokens,
  );
});

TeamIdentityInfo _buildIdentityInfo({
  required TeamRow team,
  required CompetitionRow? competition,
  required Map<String, dynamic>? rawDetails,
}) {
  final venue =
      _stringValue(rawDetails?['venue']) ??
      _stringValue(rawDetails?['stadium']) ??
      _stringValue(rawDetails?['venueName']) ??
      _stringValue(rawDetails?['stadiumName']);

  final city =
      _stringValue(rawDetails?['city']) ??
      _stringValue(rawDetails?['location']) ??
      _stringValue(rawDetails?['area']) ??
      _stringValue(rawDetails?['homeCity']);

  return TeamIdentityInfo(
    teamId: team.id,
    name: _stringValue(rawDetails?['name']) ?? team.name,
    shortName: _stringValue(rawDetails?['shortName']) ?? team.shortName,
    country:
        _stringValue(rawDetails?['country']) ??
        _stringValue(rawDetails?['countryName']) ??
        competition?.country,
    primaryLeagueId: _stringValue(rawDetails?['primaryLeagueId']),
    primaryLeagueName:
        _stringValue(rawDetails?['primaryLeagueName']) ?? competition?.name,
    latestSeason: _stringValue(rawDetails?['latestSeason']),
    venue: venue,
    city: city,
  );
}

List<TeamTabSpec> _resolveTeamTabs(
  List<String> rawTabs, {
  required bool hasTable,
  required bool hasFixtures,
  required bool hasSquad,
  required bool hasStats,
  required bool hasHistory,
  required bool hasTransfers,
}) {
  const labelsByKey = {
    'overview': 'Overview',
    'table': 'Table',
    'fixtures': 'Fixtures',
    'squad': 'Squad',
    'stats': 'Stats',
    'history': 'History',
    'transfers': 'Transfers',
  };

  final tabs = <TeamTabSpec>[];
  if (rawTabs.isNotEmpty) {
    for (final raw in rawTabs) {
      final key = _normalizeTabKey(raw);
      final label = labelsByKey[key];
      if (label == null) {
        continue;
      }
      tabs.add(TeamTabSpec(key: key, label: label));
    }
  }

  if (tabs.isNotEmpty) {
    return tabs;
  }

  tabs.add(const TeamTabSpec(key: 'overview', label: 'Overview'));
  if (hasTable) {
    tabs.add(const TeamTabSpec(key: 'table', label: 'Table'));
  }
  if (hasFixtures) {
    tabs.add(const TeamTabSpec(key: 'fixtures', label: 'Fixtures'));
  }
  if (hasSquad) {
    tabs.add(const TeamTabSpec(key: 'squad', label: 'Squad'));
  }
  if (hasStats) {
    tabs.add(const TeamTabSpec(key: 'stats', label: 'Stats'));
  }
  if (hasHistory) {
    tabs.add(const TeamTabSpec(key: 'history', label: 'History'));
  }
  if (hasTransfers) {
    tabs.add(const TeamTabSpec(key: 'transfers', label: 'Transfers'));
  }

  return tabs;
}

TeamTableData? _extractTeamTableData(Map<String, dynamic>? rawTeam, String teamId) {
  if (rawTeam == null) {
    return null;
  }

  final candidates = _collectTableCandidates(rawTeam['table']);
  TeamTableData? fallback;

  for (final candidate in candidates) {
    final tableMap = _asMap(candidate['table']);
    if (tableMap == null) {
      continue;
    }

    final modes = _parseTeamTableModes(tableMap);
    if (modes.isEmpty) {
      continue;
    }

    final parsed = TeamTableData(
      modes: modes,
      legend: _parseTeamTableLegend(candidate['legend']),
      highlightedTeamId: teamId,
      tableTitle:
          _stringValue(candidate['leagueName']) ??
          _stringValue(candidate['name']) ??
          _stringValue(candidate['title']),
    );

    if (_boolValue(candidate['isCurrentSeason']) == true) {
      return parsed;
    }

    fallback ??= parsed;
  }

  return fallback;
}

List<Map<String, dynamic>> _collectTableCandidates(dynamic value) {
  final candidates = <Map<String, dynamic>>[];

  void addCandidate(dynamic rawCandidate) {
    final map = _asMap(rawCandidate);
    if (map == null) {
      return;
    }

    final table = _asMap(map['table']);
    if (table != null && table.isNotEmpty) {
      candidates.add(map);
    }

    final data = map['data'];
    if (data is List) {
      for (final item in data) {
        addCandidate(item);
      }
    } else if (data is Map) {
      addCandidate(data);
    }
  }

  if (value is List) {
    for (final item in value) {
      addCandidate(item);
    }
  } else {
    addCandidate(value);
  }

  return candidates;
}

Map<String, List<TeamTableRowItem>> _parseTeamTableModes(
  Map<String, dynamic> tableMap,
) {
  final modes = <String, List<TeamTableRowItem>>{};
  for (final entry in tableMap.entries) {
    final modeKey = _normalizeTabKey(entry.key);
    final rowsList = _asList(entry.value);
    if (modeKey.isEmpty || rowsList.isEmpty) {
      continue;
    }

    final rows = <TeamTableRowItem>[];
    for (final row in rowsList) {
      final parsed = _parseTeamTableRow(_asMap(row));
      if (parsed != null) {
        rows.add(parsed);
      }
    }
    if (rows.isEmpty) {
      continue;
    }

    rows.sort((a, b) => a.position.compareTo(b.position));
    modes[modeKey] = List.unmodifiable(rows);
  }
  return modes;
}

TeamTableRowItem? _parseTeamTableRow(Map<String, dynamic>? row) {
  if (row == null) {
    return null;
  }

  final teamId = _stringValue(row['id']) ?? _stringValue(row['teamId']);
  final teamName = _stringValue(row['name']) ?? _stringValue(row['teamName']);
  if (teamName == null) {
    return null;
  }

  final shortName = _stringValue(row['shortName']) ?? teamName;
  final position = _intValue(row['idx']) ?? _intValue(row['position']) ?? 0;
  final played = _intValue(row['played']) ?? 0;
  final wins = _intValue(row['wins']) ?? _intValue(row['won']) ?? 0;
  final draws = _intValue(row['draws']) ?? _intValue(row['draw']) ?? 0;
  final losses = _intValue(row['losses']) ?? _intValue(row['lost']) ?? 0;
  final score = _stringValue(row['scoresStr']) ?? '0-0';
  final parsedScore = _parseScore(score);
  final goalsFor = _intValue(row['goalsFor']) ?? parsedScore.$1 ?? 0;
  final goalsAgainst = _intValue(row['goalsAgainst']) ?? parsedScore.$2 ?? 0;
  final goalDiff =
      _intValue(row['goalConDiff']) ??
      _intValue(row['goalDiff']) ??
      (goalsFor - goalsAgainst);
  final points = _intValue(row['pts']) ?? _intValue(row['points']) ?? 0;

  return TeamTableRowItem(
    teamId: teamId ?? teamName.toLowerCase().replaceAll(' ', '_'),
    teamName: teamName,
    shortName: shortName,
    position: position,
    played: played,
    wins: wins,
    draws: draws,
    losses: losses,
    scoresStr: score,
    goalsFor: goalsFor,
    goalsAgainst: goalsAgainst,
    goalDiff: goalDiff,
    points: points,
    form: _stringValue(row['form']) ?? _stringValue(row['formStr']),
    qualColor: _stringValue(row['qualColor']),
  );
}

List<TeamTableLegendItem> _parseTeamTableLegend(dynamic rawLegend) {
  final items = <TeamTableLegendItem>[];
  for (final item in _asList(rawLegend)) {
    final map = _asMap(item);
    if (map == null) {
      continue;
    }

    final title = _stringValue(map['title']);
    final color = _stringValue(map['color']);
    if (title == null || color == null) {
      continue;
    }

    final positions = <int>[];
    final indices = _stringValue(map['indices']);
    if (indices != null) {
      for (final token in indices.split(RegExp(r'\s+'))) {
        final parsed = int.tryParse(token.trim());
        if (parsed != null) {
          positions.add(parsed + 1);
        }
      }
    }

    items.add(
      TeamTableLegendItem(
        title: title,
        colorHex: color,
        positions: List.unmodifiable(positions),
      ),
    );
  }
  return List.unmodifiable(items);
}

List<TeamFixtureItem> _extractFixtureItems(
  Map<String, dynamic>? rawTeam,
  String teamId,
  List<HomeMatchView> fallback,
) {
  final fromRaw = _extractFixtureItemsFromRaw(rawTeam?['fixtures']);
  if (fromRaw.isNotEmpty) {
    return fromRaw;
  }

  final fromDb = <TeamFixtureItem>[];
  for (final item in fallback) {
    fromDb.add(
      TeamFixtureItem(
        matchId: item.match.id,
        kickoffUtc: item.match.kickoffUtc,
        status: item.match.status,
        homeTeamId: item.match.homeTeamId,
        homeTeamName: item.homeTeamName,
        awayTeamId: item.match.awayTeamId,
        awayTeamName: item.awayTeamName,
        homeScore: item.match.homeScore,
        awayScore: item.match.awayScore,
        roundLabel: item.match.roundLabel,
      ),
    );
  }

  fromDb.sort((a, b) => b.kickoffUtc.compareTo(a.kickoffUtc));
  return List.unmodifiable(fromDb);
}

List<TeamFixtureItem> _extractFixtureItemsFromRaw(dynamic fixturesRoot) {
  if (fixturesRoot == null) {
    return const [];
  }

  final parsedByKey = <String, TeamFixtureItem>{};

  void visit(dynamic node, int depth) {
    if (depth > 8) {
      return;
    }

    final map = _asMap(node);
    if (map != null) {
      final parsed = _parseFixtureItem(map);
      if (parsed != null) {
        final key =
            parsed.matchId ??
            '${parsed.kickoffUtc.millisecondsSinceEpoch}|${parsed.homeTeamName}|${parsed.awayTeamName}';
        parsedByKey[key] = parsed;
      }

      for (final value in map.values) {
        visit(value, depth + 1);
      }
      return;
    }

    if (node is List) {
      for (final item in node) {
        visit(item, depth + 1);
      }
    }
  }

  visit(fixturesRoot, 0);

  final rows = parsedByKey.values.toList(growable: false)
    ..sort((a, b) => b.kickoffUtc.compareTo(a.kickoffUtc));
  return List.unmodifiable(rows);
}

TeamFixtureItem? _parseFixtureItem(Map<String, dynamic> map) {
  final kickoff =
      _dateTimeValue(map['kickoffUtc']) ??
      _dateTimeValue(map['utcTime']) ??
      _dateTimeValue(map['startDate']) ??
      _dateTimeValue(map['date']) ??
      _dateTimeValue(map['time']) ??
      _dateTimeValue(map['timestamp']) ??
      _dateTimeValue(map['startTimestamp']);
  if (kickoff == null) {
    return null;
  }

  final homeNode =
      _asMap(map['homeTeam']) ?? _asMap(map['home']) ?? _asMap(map['team1']);
  final awayNode =
      _asMap(map['awayTeam']) ?? _asMap(map['away']) ?? _asMap(map['team2']);

  final homeTeamName =
      _stringValue(map['homeTeamName']) ??
      _stringValue(homeNode?['name']) ??
      _stringValue(homeNode?['teamName']);
  final awayTeamName =
      _stringValue(map['awayTeamName']) ??
      _stringValue(awayNode?['name']) ??
      _stringValue(awayNode?['teamName']);
  if (homeTeamName == null || awayTeamName == null) {
    return null;
  }

  final scoreRoot = _asMap(map['score']);
  final homeScore =
      _intValue(map['homeScore']) ??
      _intValue(scoreRoot?['home']) ??
      _intValue(scoreRoot?['homeScore']);
  final awayScore =
      _intValue(map['awayScore']) ??
      _intValue(scoreRoot?['away']) ??
      _intValue(scoreRoot?['awayScore']);

  return TeamFixtureItem(
    matchId: _stringValue(map['id']) ?? _stringValue(map['matchId']),
    kickoffUtc: kickoff,
    status: _stringValue(map['status']) ?? _stringValue(map['shortStatus']) ?? '-',
    homeTeamId:
        _stringValue(map['homeTeamId']) ??
        _stringValue(homeNode?['id']) ??
        _stringValue(homeNode?['teamId']),
    homeTeamName: homeTeamName,
    awayTeamId:
        _stringValue(map['awayTeamId']) ??
        _stringValue(awayNode?['id']) ??
        _stringValue(awayNode?['teamId']),
    awayTeamName: awayTeamName,
    homeScore: homeScore,
    awayScore: awayScore,
    roundLabel:
        _stringValue(map['round']) ??
        _stringValue(map['roundName']) ??
        _stringValue(map['stage']),
  );
}

List<TeamSquadItem> _extractSquadItems(
  Map<String, dynamic>? rawTeam,
  String teamId,
  List<PlayerRow> fallback,
) {
  final squadMap = _asMap(rawTeam?['squad']);
  final deduped = <String, TeamSquadItem>{};

  void addItem(TeamSquadItem item) {
    final key =
        (item.playerId != null && item.playerId!.trim().isNotEmpty)
            ? 'id:${item.playerId!.trim()}'
            : 'name:${item.playerName.toLowerCase()}';
    deduped[key] = item;
  }

  if (squadMap != null) {
    final nodes = <Map<String, dynamic>>[];
    _collectPlayerNodes(squadMap, nodes, 0);

    for (final map in nodes) {
      final name = _stringValue(map['name']) ?? _stringValue(map['playerName']);
      if (name == null) {
        continue;
      }

      final positionMap = _asMap(map['position']);
      final position =
          _stringValue(positionMap?['label']) ??
          _stringValue(positionMap?['key']) ??
          _stringValue(map['position']) ??
          _stringValue(map['role']);

      addItem(
        TeamSquadItem(
          playerId: _stringValue(map['id']) ?? _stringValue(map['playerId']),
          playerName: name,
          position: position,
          shirtNumber:
              _intValue(map['shirtNumber']) ??
              _intValue(map['shirtNo']) ??
              _intValue(map['number']) ??
              _intValue(map['jerseyNumber']),
          teamId:
              _stringValue(map['teamId']) ??
              _stringValue(map['clubId']) ??
              teamId,
        ),
      );
    }
  }

  if (deduped.isEmpty) {
    for (final row in fallback) {
      addItem(
        TeamSquadItem(
          playerId: row.id,
          playerName: row.name,
          position: row.position,
          shirtNumber: row.jerseyNumber,
          teamId: row.teamId,
        ),
      );
    }
  }

  final items = deduped.values.toList(growable: false)
    ..sort((a, b) {
      final pos = _positionRank(a.position).compareTo(_positionRank(b.position));
      if (pos != 0) {
        return pos;
      }
      final numberA = a.shirtNumber ?? 999;
      final numberB = b.shirtNumber ?? 999;
      if (numberA != numberB) {
        return numberA.compareTo(numberB);
      }
      return a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase());
    });

  return List.unmodifiable(items);
}

void _collectPlayerNodes(
  dynamic node,
  List<Map<String, dynamic>> output,
  int depth,
) {
  if (depth > 8) {
    return;
  }

  final map = _asMap(node);
  if (map != null) {
    if (_looksLikePlayerMap(map)) {
      output.add(map);
    }

    for (final value in map.values) {
      _collectPlayerNodes(value, output, depth + 1);
    }
    return;
  }

  if (node is List) {
    for (final item in node) {
      _collectPlayerNodes(item, output, depth + 1);
    }
  }
}

bool _looksLikePlayerMap(Map<String, dynamic> map) {
  final name = _stringValue(map['name']) ?? _stringValue(map['playerName']);
  if (name == null) {
    return false;
  }

  if (_stringValue(map['id']) != null || _stringValue(map['playerId']) != null) {
    return true;
  }

  if (_stringValue(map['position']) != null || _asMap(map['position']) != null) {
    return true;
  }

  if (_intValue(map['shirtNumber']) != null || _intValue(map['number']) != null) {
    return true;
  }

  return false;
}

List<TeamStatHighlight> _extractStatHighlights(Map<String, dynamic>? rawTeam) {
  if (rawTeam == null) {
    return const [];
  }

  final items = <String, TeamStatHighlight>{};

  void addItem(TeamStatHighlight item) {
    items[item.id] = item;
  }

  final overview = _asMap(rawTeam['overview']);
  final topPlayers =
      _asMap(overview?['topPlayers']) ?? _asMap(rawTeam['topPlayers']);

  if (topPlayers != null) {
    for (final entry in topPlayers.entries) {
      final category = _asMap(entry.value);
      final players = _asList(category?['players']);
      if (players.isEmpty) {
        continue;
      }

      final first = _asMap(players.first);
      if (first == null) {
        continue;
      }

      final playerName =
          _stringValue(first['name']) ?? _stringValue(first['playerName']);
      if (playerName == null) {
        continue;
      }

      final value =
          _stringValue(_asMap(first['statValue'])?['value']) ??
          _stringValue(first['statValue']) ??
          _stringValue(first['value']) ??
          _stringValue(first['rating']) ??
          '-';

      addItem(
        TeamStatHighlight(
          id: 'top:${entry.key}:$playerName',
          title: _humanizeKey(entry.key),
          value: value,
          subtitle: playerName,
          playerId: _stringValue(first['id']) ?? _stringValue(first['playerId']),
          teamId: _stringValue(first['teamId']),
        ),
      );
    }
  }

  final statsRoot = rawTeam['stats'];
  final numericLeaves = <MapEntry<String, String>>[];
  _collectNumericStatLeaves(statsRoot, '', numericLeaves, 0);

  for (final leaf in numericLeaves.take(8)) {
    addItem(
      TeamStatHighlight(
        id: 'numeric:${leaf.key}',
        title: _humanizeKey(leaf.key.split('.').last),
        value: leaf.value,
        subtitle: _humanizeKey(leaf.key.replaceAll('.', ' ')),
      ),
    );
  }

  return List.unmodifiable(items.values.toList(growable: false));
}

void _collectNumericStatLeaves(
  dynamic node,
  String prefix,
  List<MapEntry<String, String>> output,
  int depth,
) {
  if (depth > 6 || output.length >= 30) {
    return;
  }

  final map = _asMap(node);
  if (map != null) {
    for (final entry in map.entries) {
      final key = entry.key;
      final nextPrefix = prefix.isEmpty ? key : '$prefix.$key';
      final value = entry.value;

      if (_isInterestingStatKey(key)) {
        final asString = _stringValue(value);
        if (asString != null) {
          output.add(MapEntry(nextPrefix, asString));
        } else if (value is num) {
          output.add(MapEntry(nextPrefix, value.toString()));
        }
      }

      _collectNumericStatLeaves(value, nextPrefix, output, depth + 1);
    }
    return;
  }

  if (node is List) {
    for (var i = 0; i < node.length && i < 10; i++) {
      _collectNumericStatLeaves(node[i], '$prefix[$i]', output, depth + 1);
    }
  }
}

bool _isInterestingStatKey(String rawKey) {
  final key = rawKey.toLowerCase();
  const tokens = [
    'goal',
    'assist',
    'xg',
    'shot',
    'chance',
    'pass',
    'possession',
    'rating',
    'wins',
    'losses',
    'draw',
    'clean',
    'point',
  ];
  for (final token in tokens) {
    if (key.contains(token)) {
      return true;
    }
  }
  return false;
}

List<TeamHistoryItem> _extractHistoryItems(Map<String, dynamic>? rawTeam) {
  final history = _asMap(rawTeam?['history']);
  if (history == null) {
    return const [];
  }

  final items = <TeamHistoryItem>[];
  var index = 0;

  final tables = _asMap(history['tables']);
  for (final phase in const ['current', 'historic']) {
    final entries = _asList(tables?[phase]);
    for (final entry in entries) {
      final map = _asMap(entry);
      if (map == null) {
        continue;
      }

      final title =
          _stringValue(map['title']) ??
          _stringValue(map['leagueName']) ??
          _stringValue(map['name']) ??
          _humanizeKey(phase);
      final links = _asList(map['link']);

      if (links.isNotEmpty) {
        for (final link in links) {
          final linkMap = _asMap(link);
          if (linkMap == null) {
            continue;
          }

          final seasons = _stringList(linkMap['season']);
          if (seasons.isEmpty) {
            continue;
          }

          for (final season in seasons) {
            items.add(
              TeamHistoryItem(
                id: 'history-$phase-${index++}',
                title: title,
                subtitle: season,
              ),
            );
          }
          continue;
        }
      }

      final season =
          _stringValue(map['season']) ??
          _stringValue(map['latestSeason']) ??
          _stringValue(map['year']);
      if (season != null) {
        items.add(
          TeamHistoryItem(
            id: 'history-$phase-${index++}',
            title: title,
            subtitle: season,
          ),
        );
      }
    }
  }

  if (items.isNotEmpty) {
    return List.unmodifiable(items);
  }

  final seasons = _stringList(rawTeam?['allAvailableSeasons']);
  return List.unmodifiable([
    for (var i = 0; i < seasons.length; i++)
      TeamHistoryItem(
        id: 'history-seasons-$i',
        title: 'Season',
        subtitle: seasons[i],
      ),
  ]);
}

List<TeamTransferItem> _extractTransferItems(Map<String, dynamic>? rawTeam) {
  final transferRoot = _asMap(rawTeam?['transfers']);
  if (transferRoot == null) {
    return const [];
  }

  final rows = _asList(transferRoot['data']);
  if (rows.isEmpty) {
    return const [];
  }

  final items = <TeamTransferItem>[];
  for (final row in rows) {
    final map = _asMap(row);
    if (map == null) {
      continue;
    }

    final playerName = _stringValue(map['name']) ?? _stringValue(map['playerName']);
    if (playerName == null) {
      continue;
    }

    final fee =
        _stringValue(_asMap(map['fee'])?['feeText']) ??
        _stringValue(_asMap(map['fee'])?['localizedFeeText']) ??
        _stringValue(map['transferText']);

    final position =
        _stringValue(_asMap(map['position'])?['label']) ??
        _stringValue(_asMap(map['position'])?['key']) ??
        _stringValue(map['position']);

    final transferDate =
        _dateTimeValue(map['transferDate']) ??
        _dateTimeValue(map['fromDate']) ??
        _dateTimeValue(map['toDate']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    items.add(
      TeamTransferItem(
        playerId: _stringValue(map['playerId']) ?? _stringValue(map['id']),
        playerName: playerName,
        position: position,
        fromTeamId: _sanitizeTeamId(_stringValue(map['fromClubId'])),
        fromTeamName: _stringValue(map['fromClub']),
        toTeamId: _sanitizeTeamId(_stringValue(map['toClubId'])),
        toTeamName: _stringValue(map['toClub']),
        fee: fee,
        transferDateUtc: transferDate,
      ),
    );
  }

  items.sort((a, b) => b.transferDateUtc.compareTo(a.transferDateUtc));
  return List.unmodifiable(items);
}

String? _sanitizeTeamId(String? value) {
  if (value == null || value.trim().isEmpty || value == '-1' || value == '0') {
    return null;
  }
  return value.trim();
}

List<String> _extractFormTokens(
  Map<String, dynamic>? rawTeam,
  String teamId,
  TeamTableData? tableData,
) {
  final teamForm = _asMap(rawTeam?['teamForm']);
  if (teamForm != null) {
    final direct = teamForm[teamId] ?? teamForm[_normalizeTeamId(teamId)];
    final directTokens = _parseFormTokens(direct);
    if (directTokens.isNotEmpty) {
      return directTokens;
    }

    if (teamForm.length == 1) {
      final firstTokens = _parseFormTokens(teamForm.values.first);
      if (firstTokens.isNotEmpty) {
        return firstTokens;
      }
    }
  }

  final rows = tableData?.rowsForMode('all') ?? const <TeamTableRowItem>[];
  final row = rows.where((item) => item.teamId == teamId).firstOrNull;
  if (row != null) {
    final fallback = _parseFormTokens(row.form);
    if (fallback.isNotEmpty) {
      return fallback;
    }
  }

  return const [];
}

List<String> _parseFormTokens(dynamic value) {
  final tokens = <String>[];

  void addToken(String token) {
    final upper = token.trim().toUpperCase();
    if (upper == 'W' || upper == 'D' || upper == 'L') {
      tokens.add(upper);
    }
  }

  void parseNode(dynamic node, int depth) {
    if (depth > 5 || tokens.length >= 5) {
      return;
    }

    if (node is String) {
      final compact = node.toUpperCase().replaceAll(RegExp('[^WDL]'), '');
      for (final rune in compact.runes) {
        addToken(String.fromCharCode(rune));
        if (tokens.length >= 5) {
          break;
        }
      }
      return;
    }

    if (node is List) {
      for (final item in node) {
        parseNode(item, depth + 1);
        if (tokens.length >= 5) {
          return;
        }
      }
      return;
    }

    final map = _asMap(node);
    if (map == null) {
      return;
    }

    for (final key in const [
      'form',
      'recentForm',
      'formStr',
      'result',
      'outcome',
      'status',
    ]) {
      if (map.containsKey(key)) {
        parseNode(map[key], depth + 1);
        if (tokens.length >= 5) {
          return;
        }
      }
    }

    for (final nested in map.values) {
      parseNode(nested, depth + 1);
      if (tokens.length >= 5) {
        return;
      }
    }
  }

  parseNode(value, 0);
  return List.unmodifiable(tokens.take(5));
}

TeamColorPalette? _extractTeamColors(Map<String, dynamic>? rawTeam) {
  if (rawTeam == null) {
    return null;
  }

  final candidates = <Map<String, dynamic>>[];

  void addCandidate(Map<String, dynamic>? value) {
    if (value != null && value.isNotEmpty) {
      candidates.add(value);
    }
  }

  addCandidate(_asMap(rawTeam['teamColors']));

  final squad = _asMap(rawTeam['squad']);
  addCandidate(_asMap(squad?['teamColors']));

  final overview = _asMap(rawTeam['overview']);
  addCandidate(_asMap(overview?['teamColors']));

  final topPlayers =
      _asMap(overview?['topPlayers']) ?? _asMap(rawTeam['topPlayers']);
  for (final key in const ['byGoals', 'byAssists', 'byRating']) {
    final category = _asMap(topPlayers?[key]);
    final players = _asList(category?['players']);
    if (players.isEmpty) {
      continue;
    }
    addCandidate(_asMap(_asMap(players.first)?['teamColors']));
  }

  final history = _asMap(rawTeam['history']);
  final historyMap = _asMap(history?['teamColorMap']);
  if (historyMap != null) {
    addCandidate({
      'lightMode': _stringValue(historyMap['color']),
      'darkMode':
          _stringValue(historyMap['colorAlternate']) ??
          _stringValue(historyMap['color']),
      'fontLightMode': null,
      'fontDarkMode': null,
    });
  }

  for (final candidate in candidates) {
    final darkMode = _stringValue(candidate['darkMode']);
    final lightMode = _stringValue(candidate['lightMode']);
    if (darkMode == null && lightMode == null) {
      continue;
    }

    return TeamColorPalette(
      darkMode: darkMode,
      lightMode: lightMode,
      fontDarkMode: _stringValue(candidate['fontDarkMode']),
      fontLightMode: _stringValue(candidate['fontLightMode']),
    );
  }

  return null;
}

List<String> _deriveSeasonLabels(
  Map<String, dynamic>? rawTeam,
  Map<String, dynamic>? rawDetails,
  List<HomeMatchView> matches,
  List<TeamFixtureItem> fixtureItems,
) {
  final labels = <String>{};

  labels.addAll(_stringList(rawTeam?['allAvailableSeasons']));

  final latestSeason = _stringValue(rawDetails?['latestSeason']);
  if (latestSeason != null) {
    labels.add(latestSeason);
  }

  final overview = _asMap(rawTeam?['overview']);
  final overviewSeason = _stringValue(overview?['season']);
  if (overviewSeason != null) {
    labels.add(overviewSeason);
  }

  final history = _asMap(rawTeam?['history']);
  final tables = _asMap(history?['tables']);
  for (final phase in const ['current', 'historic']) {
    final entries = _asList(tables?[phase]);
    for (final entry in entries) {
      final links = _asList(_asMap(entry)?['link']);
      for (final link in links) {
        final seasonValues = _asList(_asMap(link)?['season']);
        for (final season in seasonValues) {
          final label = _stringValue(season);
          if (label != null) {
            labels.add(label);
          }
        }
      }
    }
  }

  for (final item in matches) {
    final kickoff = item.match.kickoffUtc;
    final startYear = kickoff.month >= 7 ? kickoff.year : kickoff.year - 1;
    labels.add('$startYear/${startYear + 1}');
  }

  for (final item in fixtureItems) {
    final kickoff = item.kickoffUtc;
    final startYear = kickoff.month >= 7 ? kickoff.year : kickoff.year - 1;
    labels.add('$startYear/${startYear + 1}');
  }

  final sorted = labels.toList(growable: false)
    ..sort((a, b) {
      final aYear = int.tryParse(a.split('/').first) ?? 0;
      final bYear = int.tryParse(b.split('/').first) ?? 0;
      if (aYear != bYear) {
        return bYear.compareTo(aYear);
      }
      return b.compareTo(a);
    });

  return sorted;
}

int _positionRank(String? rawPosition) {
  final position = (rawPosition ?? '').trim().toUpperCase();
  if (position.startsWith('GK')) {
    return 0;
  }
  if (position.startsWith('CB') ||
      position.startsWith('LB') ||
      position.startsWith('RB') ||
      position.startsWith('DEF')) {
    return 1;
  }
  if (position.startsWith('DM') ||
      position.startsWith('CM') ||
      position.startsWith('AM') ||
      position.startsWith('MID')) {
    return 2;
  }
  if (position.startsWith('RW') ||
      position.startsWith('LW') ||
      position.startsWith('FW') ||
      position.startsWith('ST') ||
      position.startsWith('ATT')) {
    return 3;
  }
  return 9;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries) '${entry.key}': entry.value,
    };
  }
  return null;
}

bool? _boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const [];
}

List<String> _stringList(dynamic value) {
  final list = _asList(value);
  return [
    for (final item in list)
      if (_stringValue(item) case final text?) text,
  ];
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

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is int) {
    final epochMs = value > 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
  }
  if (value is num) {
    final intValue = value.toInt();
    final epochMs = intValue > 1000000000000 ? intValue : intValue * 1000;
    return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
  }
  if (value is String) {
    return DateTime.tryParse(value.trim())?.toUtc();
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

String _humanizeKey(String raw) {
  final clean = raw
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) {
    return raw;
  }

  final words = clean.split(' ');
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

String _normalizeTabKey(String value) => value.trim().toLowerCase();

String _normalizeTeamId(String value) => value.trim();
