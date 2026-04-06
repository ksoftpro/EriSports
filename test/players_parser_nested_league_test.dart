import 'dart:convert';

import 'package:eri_sports/data/import/parsers/players_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayersParser nested league payload', () {
    test('maps league -> team -> player IDs and skips team placeholder rows', () {
      final payload = {
        'leagues': {
          'premier_league': {
            'meta': {
              'leagueId': 47,
              'slug': 'premier-league',
            },
            'selectedTeams': [
              {
                'teamId': 9825,
                'teamName': 'Arsenal',
                'players': [
                  {
                    'playerId': 9825,
                    'name': 'Arsenal',
                    'teamId': 9825,
                    'teamName': 'Arsenal',
                  },
                  {
                    'playerId': 961995,
                    'name': 'Bukayo Saka',
                    'teamId': 9825,
                    'teamName': 'Arsenal',
                    'leagueId': 47,
                    'shirtNo': '7',
                    'position': {
                      'label': 'RW',
                    },
                  },
                ],
              },
            ],
          },
        },
      };

      final parser = PlayersParser();
      final result = parser.parse(jsonEncode(payload));

      expect(result.competitions, hasLength(1));
      expect(result.competitions.first.id, '47');
      expect(result.competitions.first.name, 'Premier League');

      expect(result.teams, hasLength(1));
      expect(result.teams.first.id, '9825');
      expect(result.teams.first.competitionId, '47');

      expect(result.players, hasLength(1));
      final player = result.players.first;
      expect(player.id, '961995');
      expect(player.teamId, '9825');
      expect(player.competitionId, '47');
      expect(player.teamName, 'Arsenal');
      expect(player.name, 'Bukayo Saka');
      expect(player.position, 'RW');
      expect(player.jerseyNumber, 7);
    });
  });
}
