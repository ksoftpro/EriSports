import 'dart:convert';

class ParsedCompetition {
  const ParsedCompetition({
    required this.id,
    required this.name,
    this.country,
  });

  final String id;
  final String name;
  final String? country;
}

class ParsedTeam {
  const ParsedTeam({
    required this.id,
    required this.name,
    this.shortName,
    this.competitionId,
  });

  final String id;
  final String name;
  final String? shortName;
  final String? competitionId;
}

class TeamsParseResult {
  const TeamsParseResult({
    required this.competitions,
    required this.teams,
  });

  final List<ParsedCompetition> competitions;
  final List<ParsedTeam> teams;
}

class TeamsParser {
  TeamsParseResult parse(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    final rows = _extractRows(decoded);

    final competitions = <String, ParsedCompetition>{};
    final teams = <ParsedTeam>[];

    for (final rawRow in rows) {
      if (rawRow is! Map<String, dynamic>) {
        continue;
      }

      final teamId = _readString(rawRow, ['id', 'teamId', 'team_id']);
      final teamName = _readString(rawRow, ['name', 'teamName', 'team_name']);
      if (teamId == null || teamName == null) {
        continue;
      }

      final competitionId = _readString(
        rawRow,
        ['competitionId', 'leagueId', 'tournamentId', 'competition_id'],
      );
      final competitionName = _readString(
        rawRow,
        ['competitionName', 'leagueName', 'tournamentName', 'competition_name'],
      );
      final competitionCountry =
          _readString(rawRow, ['country', 'countryName', 'competitionCountry']);

      if (competitionId != null && competitionName != null) {
        competitions[competitionId] = ParsedCompetition(
          id: competitionId,
          name: competitionName,
          country: competitionCountry,
        );
      }

      teams.add(
        ParsedTeam(
          id: teamId,
          name: teamName,
          shortName:
              _readString(rawRow, ['shortName', 'short_name', 'abbr', 'code']),
          competitionId: competitionId,
        ),
      );
    }

    return TeamsParseResult(
      competitions: competitions.values.toList(),
      teams: teams,
    );
  }

  List<dynamic> _extractRows(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      const candidateKeys = [
        'teams',
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
}