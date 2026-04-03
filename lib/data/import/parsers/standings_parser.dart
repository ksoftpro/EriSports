import 'dart:convert';

import 'package:eri_sports/data/import/parsers/teams_parser.dart';

class ParsedStandingsRow {
  const ParsedStandingsRow({
    required this.competitionId,
    required this.seasonId,
    required this.teamId,
    required this.position,
    required this.played,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required this.form,
  });

  final String competitionId;
  final String? seasonId;
  final String teamId;
  final int position;
  final int played;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final String? form;
}

class StandingsParseResult {
  const StandingsParseResult({
    required this.competitions,
    required this.teams,
    required this.rows,
  });

  final List<ParsedCompetition> competitions;
  final List<ParsedTeam> teams;
  final List<ParsedStandingsRow> rows;
}

class StandingsParser {
  StandingsParseResult parse(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    final rows = _extractRows(decoded);
    final rootMap = decoded is Map<String, dynamic> ? decoded : null;

    final competitions = <String, ParsedCompetition>{};
    final teams = <String, ParsedTeam>{};
    final parsedRows = <ParsedStandingsRow>[];

    final fallbackCompetitionId = _readString(
          rootMap,
          ['competitionId', 'leagueId', 'tournamentId'],
        ) ??
        'unknown_competition';
    final fallbackCompetitionName = _readString(
      rootMap,
      ['competitionName', 'leagueName', 'tournamentName'],
    );
    final fallbackCountry =
        _readString(rootMap, ['country', 'countryName', 'competitionCountry']);
    final fallbackSeasonId = _readString(rootMap, ['seasonId', 'season']);

    if (fallbackCompetitionName != null) {
      competitions[fallbackCompetitionId] = ParsedCompetition(
        id: fallbackCompetitionId,
        name: fallbackCompetitionName,
        country: fallbackCountry,
      );
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final competitionId = _readString(
            row,
            ['competitionId', 'leagueId', 'tournamentId'],
          ) ??
          fallbackCompetitionId;
      final competitionName = _readString(
            row,
            ['competitionName', 'leagueName', 'tournamentName'],
          ) ??
          fallbackCompetitionName;
      final country = _readString(
            row,
            ['country', 'countryName', 'competitionCountry'],
          ) ??
          fallbackCountry;

      if (competitionName != null) {
        competitions[competitionId] = ParsedCompetition(
          id: competitionId,
          name: competitionName,
          country: country,
        );
      }

      final teamId = _nestedString(
            row,
            parentKeys: ['team', 'club'],
            childKeys: ['id', 'teamId', 'team_id'],
          ) ??
          _readString(row, ['teamId', 'team_id', 'clubId']);
      if (teamId == null) {
        continue;
      }

      final teamName = _nestedString(
            row,
            parentKeys: ['team', 'club'],
            childKeys: ['name', 'teamName'],
          ) ??
          _readString(row, ['teamName', 'name']);

      if (teamName != null) {
        teams[teamId] = ParsedTeam(
          id: teamId,
          name: teamName,
          shortName: _nestedString(
                row,
                parentKeys: ['team', 'club'],
                childKeys: ['shortName', 'abbr', 'code'],
              ) ??
              _readString(row, ['shortName', 'abbr', 'code']),
          competitionId: competitionId,
        );
      }

      final goalsFor = _readInt(row, ['goalsFor', 'gf']) ?? 0;
      final goalsAgainst = _readInt(row, ['goalsAgainst', 'ga']) ?? 0;
      final goalDiff =
          _readInt(row, ['goalDiff', 'gd']) ?? (goalsFor - goalsAgainst);

      parsedRows.add(
        ParsedStandingsRow(
          competitionId: competitionId,
          seasonId: _readString(row, ['seasonId', 'season']) ?? fallbackSeasonId,
          teamId: teamId,
          position: _readInt(row, ['position', 'rank', 'pos']) ?? (i + 1),
          played: _readInt(row, ['played', 'mp', 'pld']) ?? 0,
          won: _readInt(row, ['won', 'w']) ?? 0,
          draw: _readInt(row, ['draw', 'd']) ?? 0,
          lost: _readInt(row, ['lost', 'l']) ?? 0,
          goalsFor: goalsFor,
          goalsAgainst: goalsAgainst,
          goalDiff: goalDiff,
          points: _readInt(row, ['points', 'pts']) ?? 0,
          form: _readString(row, ['form']),
        ),
      );
    }

    return StandingsParseResult(
      competitions: competitions.values.toList(),
      teams: teams.values.toList(),
      rows: parsedRows,
    );
  }

  List<dynamic> _extractRows(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      const candidateKeys = ['standings', 'table', 'rows', 'data', 'items'];
      for (final key in candidateKeys) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }
      }
    }

    return const [];
  }

  String? _readString(Map<String, dynamic>? row, List<String> keys) {
    if (row == null) {
      return null;
    }

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