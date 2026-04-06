import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/shared/widgets/match_card_compact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline startup imports and match center renders timeline/stats',
    (tester) async {
      final harness = await _WidgetHarness.create(tester);
      addTearDown(harness.dispose);

      expect(find.textContaining('Local data import: success'), findsOneWidget);
      expect(find.text('Arsenal'), findsWidgets);

      await tester.tap(find.byType(MatchCardCompact).first.hitTestable());
      await _pumpForStability(tester);

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
    final harness = await _WidgetHarness.create(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.text('Leagues').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Premier League'), findsWidgets);

    await tester.tap(find.text('Premier League').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Standings'), findsOneWidget);
    expect(find.text('Arsenal').first, findsOneWidget);

    await tester.tap(find.text('Arsenal').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Recent Matches'), findsOneWidget);
    expect(find.text('Squad'), findsOneWidget);

    await tester.tap(find.text('Bukayo Saka').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Position'), findsOneWidget);
    expect(find.text('MID'), findsOneWidget);

    await tester.pageBack();
    await _pumpForStability(tester);
    await tester.pageBack();
    await _pumpForStability(tester);
    await tester.pageBack();
    await _pumpForStability(tester);

    await tester.tap(find.text('Search').first.hitTestable());
    await _pumpForStability(tester);

    await tester.enterText(find.byType(EditableText).first, 'Saka');
    await tester.pump(const Duration(milliseconds: 220));
    await _pumpForStability(tester);

    expect(find.text('Players'), findsOneWidget);
    await tester.tap(find.text('Bukayo Saka').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Position'), findsOneWidget);
  });
}

class _WidgetHarness {
  _WidgetHarness({required this.database, required this.tempRoot});

  final AppDatabase database;
  final Directory tempRoot;

  static Future<_WidgetHarness> create(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    final tempRoot = await Directory.systemTemp.createTemp('erisports_wt_');
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
      leagueStandingsSource: LeagueStandingsSource(),
      logger: logger,
    );

    final startupReport = await services.importCoordinator.runLocalImport(
      triggerType: 'startup',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          startupImportReportProvider.overrideWithValue(startupReport),
        ],
        child: const EriSportsApp(),
      ),
    );
    await _pumpForStability(tester);

    return _WidgetHarness(database: database, tempRoot: tempRoot);
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
    await writeJson('players_2026_04_03.json', playersJson);
    await writeJson('match_detail_1001.json', matchDetailJson);
  }
}

Future<void> _pumpForStability(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
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
