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
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline asset diagnostics maps bundled team badges', (
    tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    final harness = await _TestHarness.create(tester, binding);
    addTearDown(harness.dispose);

    await tester.tap(find.text('More').first.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Run offline asset diagnostics'), findsOneWidget);

    await tester.tap(
      find.text('Run offline asset diagnostics').first.hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Asset diagnostics'), findsOneWidget);
    expect(find.text('Teams: 2/2 mapped'), findsOneWidget);
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

    final tempRoot = await Directory.systemTemp.createTemp(
      'erisports_it_diag_',
    );
    final daylySportDir = Directory(p.join(tempRoot.path, 'daylySport'));
    await daylySportDir.create(recursive: true);

    await _seedOfflineJson(daylySportDir);

    final locator = _TestDaylySportLocator(daylySportDir);
    final logger = AppLogger();
    final scanner = FileInventoryScanner();
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

    final startupReport = await services.importCoordinator.runLocalImport(
      triggerType: 'startup',
    );

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
          'status': 'scheduled',
          'homeScore': 0,
          'awayScore': 0,
          'homeTeam': {'id': '9825', 'name': 'Arsenal'},
          'awayTeam': {'id': '8650', 'name': 'Liverpool'},
          'round': 'Matchday 30',
        },
      ],
    };

    Future<void> writeJson(String filename, Map<String, dynamic> data) async {
      final file = File(p.join(daylySportDir.path, filename));
      await file.writeAsString(jsonEncode(data));
    }

    Future<void> writeBadge(String relativePath) async {
      final file = File(p.join(daylySportDir.path, relativePath));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(<int>[137, 80, 78, 71]);
    }

    await writeJson('teams_2026_04_03.json', teamsJson);
    await writeJson('fixtures_2026_04_03.json', fixturesJson);
    await writeBadge('teams/premier_league/team_Arsenal_9825_badge.png');
    await writeBadge('teams/premier_league/team_Liverpool_8650_badge.png');
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
