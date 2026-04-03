import 'dart:convert';

import 'package:eri_sports/data/import/parsers/teams_parser.dart';

class ParsedMatch {
  const ParsedMatch({
    required this.id,
    required this.competitionId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.kickoffUtc,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    this.roundLabel,
  });

  final String id;
  final String competitionId;
  final String homeTeamId;
  final String awayTeamId;
  final DateTime kickoffUtc;
  final String status;
  final int homeScore;
  final int awayScore;
  final String? roundLabel;
}

class FixturesParseResult {
  const FixturesParseResult({
    required this.competitions,
    required this.teams,
    required this.matches,
  });

  final List<ParsedCompetition> competitions;
  final List<ParsedTeam> teams;
  final List<ParsedMatch> matches;
}

class FixturesParser {
  FixturesParseResult parse(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    final rows = _extractRows(decoded);

    final competitions = <String, ParsedCompetition>{};
    final teams = <String, ParsedTeam>{};
    final matches = <ParsedMatch>[];

    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final matchId = _readString(row, ['id', 'matchId', 'fixtureId']);
      final competitionId = _readString(
            row,
            ['competitionId', 'leagueId', 'tournamentId', 'competition_id'],
          ) ??
          'unknown_competition';

      final homeTeamId = _nestedString(
            row,
            parentKeys: ['homeTeam', 'home', 'home_team'],
            childKeys: ['id', 'teamId', 'team_id'],
          ) ??
          _readString(row, ['homeTeamId', 'home_id']) ??
          'home_unknown';

      final awayTeamId = _nestedString(
            row,
            parentKeys: ['awayTeam', 'away', 'away_team'],
            childKeys: ['id', 'teamId', 'team_id'],
          ) ??
          _readString(row, ['awayTeamId', 'away_id']) ??
          'away_unknown';

      final kickoffRaw = _readString(
            row,
            ['kickoffUtc', 'startTime', 'kickoff', 'utcDate', 'date'],
          ) ??
          '';
      final kickoff = DateTime.tryParse(kickoffRaw)?.toUtc();

      if (matchId == null || kickoff == null) {
        continue;
      }

      final competitionName = _readString(
        row,
        ['competitionName', 'leagueName', 'tournamentName'],
      );
      final competitionCountry =
          _readString(row, ['country', 'countryName', 'competitionCountry']);
      if (competitionName != null) {
        competitions[competitionId] = ParsedCompetition(
          id: competitionId,
          name: competitionName,
          country: competitionCountry,
        );
      }

      final homeTeamName = _nestedString(
            row,
            parentKeys: ['homeTeam', 'home', 'home_team'],
            childKeys: ['name', 'teamName'],
          ) ??
          _readString(row, ['homeTeamName']);
      final awayTeamName = _nestedString(
            row,
            parentKeys: ['awayTeam', 'away', 'away_team'],
            childKeys: ['name', 'teamName'],
          ) ??
          _readString(row, ['awayTeamName']);

      if (homeTeamName != null) {
        teams[homeTeamId] = ParsedTeam(id: homeTeamId, name: homeTeamName);
      }
      if (awayTeamName != null) {
        teams[awayTeamId] = ParsedTeam(id: awayTeamId, name: awayTeamName);
      }

      matches.add(
        ParsedMatch(
          id: matchId,
          competitionId: competitionId,
          homeTeamId: homeTeamId,
          awayTeamId: awayTeamId,
          kickoffUtc: kickoff,
          status: _readString(row, ['status', 'state']) ?? 'scheduled',
          homeScore: _readInt(row, ['homeScore', 'home_score']) ?? 0,
          awayScore: _readInt(row, ['awayScore', 'away_score']) ?? 0,
          roundLabel: _readString(row, ['round', 'stage', 'roundLabel']),
        ),
      );
    }

    return FixturesParseResult(
      competitions: competitions.values.toList(),
      teams: teams.values.toList(),
      matches: matches,
    );
  }

  List<dynamic> _extractRows(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      const candidateKeys = [
        'fixtures',
        'matches',
        'data',
        'items',
      ];

      for (final key in candidateKeys) {
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