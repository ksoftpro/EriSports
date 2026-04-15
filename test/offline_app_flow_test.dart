import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/bootstrap/startup_controller.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_file_discovery_service.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';
import 'package:eri_sports/data/local_files/json_data_version_tracker.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_image_service.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/sync/daylysport_sync_coordinator.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:eri_sports/features/team/data/team_raw_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers/daylysport_db_seed_helper.dart';
import 'test_helpers/sqlite_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline startup imports and match center renders timeline/stats',
    (tester) async {
      final harness = await _WidgetHarness.create(tester);
      addTearDown(() => harness.dispose(tester));

      expect(find.text('Arsenal'), findsWidgets);
      expect(find.text('Liverpool'), findsWidgets);

      await tester.tap(find.text('2 - 1').first.hitTestable());
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
    addTearDown(() => harness.dispose(tester));

    await tester.tap(find.text('Leagues').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Premier League'), findsWidgets);

    await tester.tap(find.text('Premier League').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Arsenal').first, findsOneWidget);
    expect(find.text('Overall'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Away'), findsOneWidget);
    expect(find.text('Form'), findsOneWidget);
    expect(find.text('XG'), findsOneWidget);

    await tester.tap(find.text('XG').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('xPts'), findsOneWidget);
    expect(find.text('73.4'), findsOneWidget);

    await tester.tap(find.text('Form').first.hitTestable());
    await _pumpForStability(tester);

    expect(find.text('Form'), findsWidgets);

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

    final tempRoot = Directory(
      p.join(
        Directory.systemTemp.path,
        'erisports_wt_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    tempRoot.createSync(recursive: true);
    await _installPathProviderMock(tempRoot);
    final daylySportDir = Directory(p.join(tempRoot.path, 'daylySport'));
    daylySportDir.createSync(recursive: true);

    await _seedOfflineJson(daylySportDir);

    final locator = _TestDaylySportLocator(daylySportDir);
    final logger = AppLogger();
    final scanner = FileInventoryScanner();
    initSqlite3ForTests();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final cacheStore = DaylySportCacheStore(sharedPreferences: preferences);
    final fileResolver = const EncryptedFileResolver();
    final fingerprintCache = FileFingerprintCache(cacheStore: cacheStore);
    final encryptedJsonService = EncryptedJsonService(
      fingerprintCache: fingerprintCache,
    );
    final encryptedImageService = EncryptedImageService(
      fingerprintCache: fingerprintCache,
    );
    final encryptedMediaService = EncryptedMediaService(
      fingerprintCache: fingerprintCache,
    );
    final versionTracker = JsonDataVersionTracker(cacheStore: cacheStore);
    final importCoordinator = ImportCoordinator(
      database: database,
      daylySportLocator: locator,
      scanner: scanner,
      logger: logger,
      encryptedJsonService: encryptedJsonService,
    );
    final assetResolver = LocalAssetResolver(
      daylySportLocator: locator,
      cacheStore: cacheStore,
      encryptedJsonService: encryptedJsonService,
    );
    final leagueStandingsSource = LeagueStandingsSource(
      daylySportLocator: locator,
      cacheStore: cacheStore,
      encryptedJsonService: encryptedJsonService,
    );
    final teamRawSource = TeamRawSource(
      daylySportLocator: locator,
      cacheStore: cacheStore,
      encryptedJsonService: encryptedJsonService,
    );
    final syncCoordinator = DaylysportSyncCoordinator(
      discoveryService: DaylysportFileDiscoveryService(
        daylySportLocator: locator,
        scanner: scanner,
        versionTracker: versionTracker,
        fileResolver: fileResolver,
      ),
      versionTracker: versionTracker,
      importCoordinator: importCoordinator,
    );
    final secureContentCoordinator = DaylysportSecureContentCoordinator(
      fileResolver: fileResolver,
      encryptedJsonService: encryptedJsonService,
      encryptedImageService: encryptedImageService,
      encryptedMediaService: encryptedMediaService,
    );

    final services = AppServices(
      database: database,
      daylySportLocator: locator,
      importCoordinator: importCoordinator,
      assetResolver: assetResolver,
      encryptedMediaService: encryptedMediaService,
      encryptedJsonService: encryptedJsonService,
      encryptedImageService: encryptedImageService,
      secureContentCoordinator: secureContentCoordinator,
      leagueStandingsSource: leagueStandingsSource,
      teamRawSource: teamRawSource,
      daylysportSyncCoordinator: syncCoordinator,
      logger: logger,
    );

    final startupReport = await seedOfflineDbForTests(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          daylysportAutoMonitoringEnabledProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(preferences),
          startupControllerProvider.overrideWith(
            () => _SeededStartupController(startupReport),
          ),
        ],
        child: const EriSportsApp(),
      ),
    );
    await _pumpForStability(tester);

    return _WidgetHarness(database: database, tempRoot: tempRoot);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await _clearPathProviderMock();
    await database.close();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }

  static Future<void> _seedOfflineJson(Directory daylySportDir) {
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

    void writeJson(String filename, Map<String, dynamic> data) {
      final file = File(p.join(daylySportDir.path, filename));
      file.writeAsStringSync(jsonEncode(data));
    }

    writeJson('teams_2026_04_03.json', teamsJson);
    writeJson('fixtures_2026_04_03.json', fixturesJson);
    writeJson('standings_2026_04_03.json', standingsJson);
    writeJson(
      'top_standings_full_data_2026_04_03.json',
      topStandingsFullJson,
    );
    writeJson('players_2026_04_03.json', playersJson);
    writeJson('match_detail_1001.json', matchDetailJson);
    return Future<void>.value();
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

Future<void> _pumpForStability(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (tester.binding.transientCallbackCount == 0) {
      break;
    }
  }
}

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Future<void> _installPathProviderMock(Directory tempRoot) {
  final tempPath = tempRoot.path;
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        switch (call.method) {
          case 'getTemporaryDirectory':
          case 'getApplicationDocumentsDirectory':
          case 'getApplicationSupportDirectory':
          case 'getLibraryDirectory':
          case 'getDownloadsDirectory':
          case 'getExternalStorageDirectory':
            return tempPath;
          case 'getExternalCacheDirectories':
          case 'getExternalStorageDirectories':
            return <String>[tempPath];
        }
        return tempPath;
      });
  return Future<void>.value();
}

Future<void> _clearPathProviderMock() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, null);
  return Future<void>.value();
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
