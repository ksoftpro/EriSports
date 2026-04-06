import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/bootstrap/startup_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline startup imports and match center renders timeline/stats',
    (tester) async {
      final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
      final harness = await _TestHarness.create(tester, binding);
      addTearDown(harness.dispose);

      expect(find.text('Arsenal'), findsWidgets);
      expect(find.text('Liverpool'), findsWidgets);

      await tester.tap(find.text('2 - 1').first.hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Match Detail'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.textContaining('Goal'), findsWidgets);
      expect(find.text('Possession'), findsOneWidget);
    },
  );

  testWidgets('offline leagues, team, player, and search navigation works', (
    tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    final harness = await _TestHarness.create(tester, binding);
    addTearDown(harness.dispose);

    await tester.tap(find.text('Leagues').first.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Premier League'), findsWidgets);

    await tester.tap(find.text('Premier League').first.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Standings'), findsOneWidget);
    expect(find.text('Arsenal').first, findsOneWidget);

    await tester.tap(find.text('Arsenal').first.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Recent Matches'), findsOneWidget);
    expect(find.text('Squad'), findsOneWidget);

    await tester.tap(find.text('Bukayo Saka').first.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Position'), findsOneWidget);
    expect(find.text('MID'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search').first.hitTestable());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, 'Saka');
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(find.text('Players'), findsOneWidget);
    await tester.tap(find.text('Bukayo Saka').first.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Position'), findsOneWidget);
  });
}

class _TestHarness {
  _TestHarness({required this.database, required this.tempRoot});

  final AppDatabase database;
  final Directory tempRoot;

  static Future<_TestHarness> create(
    WidgetTester tester,
    IntegrationTestWidgetsFlutterBinding binding,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    final tempRoot = await Directory.systemTemp.createTemp('erisports_it_');
    final daylySportDir = Directory(p.join(tempRoot.path, 'daylySport'));
    await daylySportDir.create(recursive: true);

    await _seedOfflineJson(daylySportDir);

    final locator = _TestDaylySportLocator(daylySportDir);
    final logger = AppLogger();
    final scanner = FileInventoryScanner();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final importCoordinator = ImportCoordinator(
      database: database,
      daylySportLocator: locator,
      scanner: scanner,
      logger: logger,
    );
    final assetResolver = LocalAssetResolver(daylySportLocator: locator);

    final services = AppServices(
      database: database,
      importCoordinator: importCoordinator,
      assetResolver: assetResolver,
      leagueStandingsSource: LeagueStandingsSource(daylySportLocator: locator),
      logger: logger,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    final startupReport = await services.importCoordinator.runLocalImport(
      triggerType: 'startup',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          sharedPreferencesProvider.overrideWithValue(preferences),
          startupControllerProvider.overrideWith(
            () => _SeededStartupController(startupReport),
          ),
        ],
        child: const EriSportsApp(),
      ),
    );
    await tester.pumpAndSettle();

    return _TestHarness(database: database, tempRoot: tempRoot);
  }

  Future<void> dispose() async {
    await database.close();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }

  static Future<void> _seedOfflineJson(Directory daylySportDir) async {
    final teamsJson = {
      'teams': [
        {
          'id': '9825',
          'name': 'Arsenal',
          'shortName': 'ARS',
          'competitionId': '47',
          'competitionName': 'Premier League',
          'country': 'England',
        },
        {
          'id': '8650',
          'name': 'Liverpool',
          'shortName': 'LIV',
          'competitionId': '47',
          'competitionName': 'Premier League',
          'country': 'England',
        },
      ],
    };

    final fixturesJson = {
      'matches': [
        {
          'id': '1001',
          'competitionId': '47',
          'competitionName': 'Premier League',
          'country': 'England',
          'kickoffUtc': DateTime.now().toUtc().toIso8601String(),
          'status': 'live',
          'homeScore': 2,
          'awayScore': 1,
          'homeTeam': {'id': '9825', 'name': 'Arsenal'},
          'awayTeam': {'id': '8650', 'name': 'Liverpool'},
          'round': 'Matchday 30',
        },
      ],
    };

    final standingsJson = {
      'competitionId': '47',
      'competitionName': 'Premier League',
      'country': 'England',
      'standings': [
        {
          'position': 1,
          'played': 30,
          'won': 22,
          'draw': 5,
          'lost': 3,
          'goalsFor': 68,
          'goalsAgainst': 25,
          'goalDiff': 43,
          'points': 71,
          'team': {'id': '9825', 'name': 'Arsenal', 'shortName': 'ARS'},
        },
        {
          'position': 2,
          'played': 30,
          'won': 21,
          'draw': 6,
          'lost': 3,
          'goalsFor': 66,
          'goalsAgainst': 28,
          'goalDiff': 38,
          'points': 69,
          'team': {'id': '8650', 'name': 'Liverpool', 'shortName': 'LIV'},
        },
      ],
    };

    final topStandingsFullJson = {
      'premier_league': {
        'meta': {
          'leagueId': '47',
          'slug': 'premier_league',
          'season': '2025/2026',
        },
        'standings': {
          'tableType': 'league',
          'table': {
            'all': [
              {
                'id': '9825',
                'name': 'Arsenal',
                'shortName': 'ARS',
                'idx': 1,
                'played': 30,
                'wins': 25,
                'draws': 4,
                'losses': 1,
                'scoresStr': '72-20',
                'goalConDiff': 52,
                'pts': 79,
                'qualColor': '#2E7D32',
                'form': 'WWDWW',
              },
              {
                'id': '8650',
                'name': 'Liverpool',
                'shortName': 'LIV',
                'idx': 2,
                'played': 30,
                'wins': 22,
                'draws': 5,
                'losses': 3,
                'scoresStr': '68-28',
                'goalConDiff': 40,
                'pts': 71,
                'qualColor': '#1565C0',
                'form': 'WDWWW',
              },
            ],
            'home': [
              {
                'id': '9825',
                'name': 'Arsenal',
                'shortName': 'ARS',
                'idx': 1,
                'played': 15,
                'wins': 13,
                'draws': 2,
                'losses': 0,
                'scoresStr': '39-9',
                'goalConDiff': 30,
                'pts': 41,
                'qualColor': '#2E7D32',
              },
              {
                'id': '8650',
                'name': 'Liverpool',
                'shortName': 'LIV',
                'idx': 2,
                'played': 15,
                'wins': 11,
                'draws': 3,
                'losses': 1,
                'scoresStr': '34-12',
                'goalConDiff': 22,
                'pts': 36,
                'qualColor': '#1565C0',
              },
            ],
            'away': [
              {
                'id': '9825',
                'name': 'Arsenal',
                'shortName': 'ARS',
                'idx': 1,
                'played': 15,
                'wins': 12,
                'draws': 2,
                'losses': 1,
                'scoresStr': '33-11',
                'goalConDiff': 22,
                'pts': 38,
                'qualColor': '#2E7D32',
              },
              {
                'id': '8650',
                'name': 'Liverpool',
                'shortName': 'LIV',
                'idx': 2,
                'played': 15,
                'wins': 11,
                'draws': 2,
                'losses': 2,
                'scoresStr': '34-16',
                'goalConDiff': 18,
                'pts': 35,
                'qualColor': '#1565C0',
              },
            ],
            'form': [
              {
                'id': '9825',
                'name': 'Arsenal',
                'shortName': 'ARS',
                'idx': 1,
                'played': 5,
                'wins': 4,
                'draws': 1,
                'losses': 0,
                'scoresStr': '11-3',
                'goalConDiff': 8,
                'pts': 13,
                'qualColor': '#2E7D32',
                'form': 'WWDWW',
              },
              {
                'id': '8650',
                'name': 'Liverpool',
                'shortName': 'LIV',
                'idx': 2,
                'played': 5,
                'wins': 4,
                'draws': 0,
                'losses': 1,
                'scoresStr': '10-4',
                'goalConDiff': 6,
                'pts': 12,
                'qualColor': '#1565C0',
                'form': 'WDWWW',
              },
            ],
            'xg': [
              {
                'id': '9825',
                'name': 'Arsenal',
                'shortName': 'ARS',
                'idx': 1,
                'played': 30,
                'wins': 25,
                'draws': 4,
                'losses': 1,
                'scoresStr': '72-20',
                'goalConDiff': 52,
                'pts': 79,
                'qualColor': '#2E7D32',
                'xg': 61.8,
                'xgConceded': 24.1,
                'xPoints': 73.4,
                'xPosition': 1,
              },
              {
                'id': '8650',
                'name': 'Liverpool',
                'shortName': 'LIV',
                'idx': 2,
                'played': 30,
                'wins': 22,
                'draws': 5,
                'losses': 3,
                'scoresStr': '68-28',
                'goalConDiff': 40,
                'pts': 71,
                'qualColor': '#1565C0',
                'xg': 58.2,
                'xgConceded': 27.8,
                'xPoints': 68.7,
                'xPosition': 2,
              },
            ],
          },
        },
      },
    };

    final playersJson = {
      'players': [
        {
          'id': '961995',
          'name': 'Bukayo Saka',
          'position': 'MID',
          'jerseyNumber': 7,
          'teamId': '9825',
        },
      ],
    };

    final matchDetailJson = {
      'matchId': '1001',
      'homeTeamId': '9825',
      'awayTeamId': '8650',
      'events': [
        {
          'minute': 12,
          'type': 'goal',
          'teamId': '9825',
          'playerId': '961995',
          'playerName': 'Bukayo Saka',
          'detail': 'Left-footed finish',
        },
      ],
      'teamStats': {
        'home': {'possession': 56, 'shots_on_target': 7, 'corners': 5},
        'away': {'possession': 44, 'shots_on_target': 4, 'corners': 2},
      },
    };

    Future<void> writeJson(String filename, Map<String, dynamic> data) async {
      final file = File(p.join(daylySportDir.path, filename));
      await file.writeAsString(jsonEncode(data));
    }

    await writeJson('teams_2026_04_03.json', teamsJson);
    await writeJson('fixtures_2026_04_03.json', fixturesJson);
    await writeJson('standings_2026_04_03.json', standingsJson);
    await writeJson('top_standings_full_data_2026_04_03.json', topStandingsFullJson);
    await writeJson('players_2026_04_03.json', playersJson);
    await writeJson('match_detail_1001.json', matchDetailJson);
  }
}

class _SeededStartupController extends StartupController {
  _SeededStartupController(this._report);

  final ImportRunReport _report;

  @override
  StartupState build() {
    return StartupState(
      phase: StartupPhase.ready,
      hasCachedData: true,
      statusText: 'Offline data ready',
      latestReport: _report,
    );
  }

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> retry() async {}
}

class _TestDaylySportLocator extends DaylySportLocator {
  _TestDaylySportLocator(this.daylySportDirectory);

  final Directory daylySportDirectory;

  @override
  Future<Directory> getOrCreateDaylySportDirectory() async {
    if (!await daylySportDirectory.exists()) {
      await daylySportDirectory.create(recursive: true);
    }
    return daylySportDirectory;
  }
}
