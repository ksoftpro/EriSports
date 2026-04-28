import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:eri_sports/app/bootstrap/app_services.dart';
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
import 'package:eri_sports/data/secure_content/secure_content_encryption_job_manager.dart';
import 'package:eri_sports/data/sync/daylysport_sync_coordinator.dart';
import 'package:eri_sports/features/admin/data/admin_activity_service.dart';
import 'package:eri_sports/features/admin/data/admin_auth_service.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:eri_sports/features/more/presentation/secure_content_screen.dart';
import 'package:eri_sports/features/team/data/team_raw_source.dart';
import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/sqlite_test_helper.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('admin verification records are generated and can be cleared', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final cacheStore = DaylySportCacheStore(sharedPreferences: preferences);
    final activityService = AdminActivityService(cacheStore: cacheStore);
    final verificationService = ContentVerificationService(
      cacheStore: cacheStore,
    );

    final verificationQr = verificationService.generateVerificationQrPayload(
      now: DateTime.utc(2025, 1, 14, 10),
    );

    await activityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.verificationCodeGenerated,
        occurredAtUtc: DateTime.utc(2025, 1, 14, 10, 5),
        summary: 'Generated offline content direct verification QR approval.',
        category: 'verification',
        actorUserId: 'admin-1',
        actorUsername: 'opslead',
        metadata: <String, String>{
          'feature': verificationQr.feature,
          'contentCategory': verificationQr.feature,
          'verificationMode': 'direct_qr',
          'verificationCode': verificationQr.verificationCode,
        },
      ),
    );

    expect(
      activityService.records.single.type,
      AdminActivityType.verificationCodeGenerated,
    );
    expect(
      activityService.records.single.metadata?['verificationMode'],
      'direct_qr',
    );

    await activityService.clearVerificationCodeRecords(
      actorUserId: 'admin-1',
      actorUsername: 'opslead',
    );

    expect(
      activityService.records.any(
        (record) => record.type == AdminActivityType.verificationCodeGenerated,
      ),
      isFalse,
    );
    expect(
      activityService.records.any(
        (record) =>
            record.type == AdminActivityType.verificationCodeRecordsCleared,
      ),
      isTrue,
    );
  });

  testWidgets('admin dashboard stays protected while unauthenticated', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;

    final harness = await _AdminDashboardHarness.create();
    final container = ProviderContainer(
      overrides: [appServicesProvider.overrideWithValue(harness.services)],
    );
    addTearDown(() {
      container.dispose();
      harness.disposeForTest();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SecureContentScreen()),
      ),
    );
    await _pumpForUi(tester);

    expect(find.byKey(adminDashboardOverviewKey), findsNothing);
    expect(find.text('Secure Content Operations'), findsNothing);
  });

  testWidgets(
    'admin dashboard renders five tabs and keeps panels on the intended tab',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;

      final harness = await _AdminDashboardHarness.create();
      final container = ProviderContainer(
        overrides: [appServicesProvider.overrideWithValue(harness.services)],
      );
      addTearDown(() {
        container.dispose();
        harness.disposeForTest();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final loginResult = await harness.services.adminAuthService.login(
        username: 'opslead',
        password: 'Secure123',
        persistSession: false,
      );
      expect(loginResult.success, isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SecureContentScreen()),
        ),
      );

      await _pumpForUi(tester, frames: 12);

      expect(find.text('Secure Content Operations'), findsOneWidget);
      expect(find.byKey(adminDashboardHomeTabKey), findsOneWidget);
      expect(find.byKey(adminDashboardImportTabKey), findsOneWidget);
      expect(find.byKey(adminDashboardOperationsTabKey), findsOneWidget);
      expect(find.byKey(adminDashboardProfileTabKey), findsOneWidget);
      expect(find.byKey(adminDashboardStatsTabKey), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Operation'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);

      expect(
        find.text(
          'Professional control surface for encrypted daylySport operations',
        ),
        findsOneWidget,
      );
      expect(find.byKey(adminDashboardRecentActivityKey), findsNothing);
      expect(find.text('Import and encrypt'), findsNothing);
      expect(find.text('Verification QR operations'), findsNothing);
      expect(find.text('User and security management'), findsNothing);
      expect(find.text('Inventory and statistics'), findsNothing);

      await tester.tap(find.byKey(adminDashboardImportTabKey).hitTestable());
      await _pumpForUi(tester, frames: 8);

      expect(find.text('Import and encrypt'), findsOneWidget);
      expect(
        find.text(
          'Professional control surface for encrypted daylySport operations',
        ),
        findsNothing,
      );
      expect(find.byKey(adminDashboardRecentActivityKey), findsNothing);
      expect(find.text('Verification QR operations'), findsNothing);
      expect(find.text('User and security management'), findsNothing);
      expect(find.text('Inventory and statistics'), findsNothing);

      await tester.tap(
        find.byKey(adminDashboardOperationsTabKey).hitTestable(),
      );
      await _pumpForUi(tester, frames: 8);

      expect(find.text('Verification QR operations'), findsOneWidget);
      expect(find.text('Import and encrypt'), findsNothing);
      expect(
        find.text(
          'Professional control surface for encrypted daylySport operations',
        ),
        findsNothing,
      );
      expect(find.byKey(adminDashboardRecentActivityKey), findsNothing);

      await tester.tap(find.byKey(adminDashboardProfileTabKey).hitTestable());
      await _pumpForUi(tester, frames: 8);

      expect(find.byKey(adminDashboardRecentActivityKey), findsOneWidget);
      expect(find.text('User and security management'), findsOneWidget);
      expect(
        find.text(
          'Professional control surface for encrypted daylySport operations',
        ),
        findsNothing,
      );
      expect(find.text('Verification QR operations'), findsNothing);
      expect(find.text('Inventory and statistics'), findsNothing);

      await tester.tap(find.byKey(adminDashboardStatsTabKey).hitTestable());
      await _pumpForUi(tester, frames: 8);

      expect(find.text('Inventory and statistics'), findsOneWidget);
      expect(find.byKey(adminDashboardRecentActivityKey), findsNothing);
      expect(find.text('Import and encrypt'), findsNothing);
      expect(find.text('Verification QR operations'), findsNothing);
      expect(
        find.text(
          'Professional control surface for encrypted daylySport operations',
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(adminDashboardHomeTabKey).hitTestable());
      await _pumpForUi(tester, frames: 8);

      expect(
        find.text(
          'Professional control surface for encrypted daylySport operations',
        ),
        findsOneWidget,
      );
      expect(find.byKey(adminDashboardRecentActivityKey), findsNothing);
    },
  );
}

Future<void> _pumpForUi(WidgetTester tester, {int frames = 8}) async {
  await tester.pump();
  for (var index = 0; index < frames; index += 1) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

class _AdminDashboardHarness {
  _AdminDashboardHarness({required this.tempRoot, required this.services});

  final Directory tempRoot;
  final AppServices services;

  static Future<_AdminDashboardHarness> create() async {
    initSqlite3ForTests();

    final tempRoot = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}eri_admin_dashboard_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await _installPathProviderMock(tempRoot);
    final daylySportDir = Directory(
      '${tempRoot.path}${Platform.pathSeparator}daylySport',
    )..createSync(recursive: true);
    final sourceDir = Directory(
      '${tempRoot.path}${Platform.pathSeparator}source',
    )..createSync(recursive: true);
    final importsDir = Directory(
      '${daylySportDir.path}${Platform.pathSeparator}imports',
    )..createSync(recursive: true);
    final newsDir = Directory(
      '${daylySportDir.path}${Platform.pathSeparator}news',
    )..createSync(recursive: true);
    final reelsDir = Directory(
      '${daylySportDir.path}${Platform.pathSeparator}reels',
    )..createSync(recursive: true);

    final jsonFile = File(
      '${sourceDir.path}${Platform.pathSeparator}table.json',
    );
    jsonFile.writeAsStringSync(
      jsonEncode(<String, Object>{'league': 'Premier League'}),
    );
    final imageFile = File(
      '${sourceDir.path}${Platform.pathSeparator}badge.png',
    );
    imageFile.writeAsBytesSync(<int>[137, 80, 78, 71, 1, 2, 3, 4, 5, 6, 7, 8]);
    final videoFile = File(
      '${sourceDir.path}${Platform.pathSeparator}goal.mp4',
    );
    videoFile.writeAsBytesSync(
      List<int>.generate(4096, (index) => index % 251),
    );
    final encryptedJsonFile = File(
      '${importsDir.path}${Platform.pathSeparator}table.json.esj',
    );
    encryptedJsonFile.writeAsBytesSync(
      List<int>.generate(128, (index) => (index * 13) % 251),
    );
    final encryptedImageFile = File(
      '${newsDir.path}${Platform.pathSeparator}badge.png.esi',
    );
    encryptedImageFile.writeAsBytesSync(
      List<int>.generate(96, (index) => (index * 17) % 251),
    );
    final encryptedVideoFile = File(
      '${reelsDir.path}${Platform.pathSeparator}goal.mp4.esv',
    );
    encryptedVideoFile.writeAsBytesSync(
      List<int>.generate(512, (index) => (index * 19) % 251),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'daylysport.custom_json_folder': daylySportDir.path,
    });
    final preferences = await SharedPreferences.getInstance();
    final cacheStore = DaylySportCacheStore(sharedPreferences: preferences);
    final logger = AppLogger();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final locator = DaylySportLocator(sharedPreferences: preferences);
    final fileResolver = const EncryptedFileResolver();
    final fingerprintCache = FileFingerprintCache(cacheStore: cacheStore);
    final contentKey = Uint8List.fromList(
      List<int>.generate(32, (index) => ((index * 17) + 11) % 255),
    );
    final keyBase64 = base64Encode(contentKey);
    final encryptedJsonService = EncryptedJsonService(
      fingerprintCache: fingerprintCache,
      keyBase64: keyBase64,
      cacheRootProvider: () async => tempRoot,
    );
    final encryptedImageService = EncryptedImageService(
      fingerprintCache: fingerprintCache,
      keyBase64: keyBase64,
      cacheRootProvider: () async => tempRoot,
    );
    final encryptedMediaService = EncryptedMediaService(
      fingerprintCache: fingerprintCache,
      mediaKeyBase64: keyBase64,
      cacheRootProvider: () async => tempRoot,
    );
    final scanner = FileInventoryScanner(cacheStore: cacheStore);
    final versionTracker = JsonDataVersionTracker(cacheStore: cacheStore);
    final assetResolver = LocalAssetResolver(
      daylySportLocator: locator,
      cacheStore: cacheStore,
      encryptedJsonService: encryptedJsonService,
      logger: logger,
    );
    final importCoordinator = ImportCoordinator(
      database: database,
      daylySportLocator: locator,
      scanner: scanner,
      logger: logger,
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
      daylySportLocator: locator,
      fileResolver: fileResolver,
      encryptedJsonService: encryptedJsonService,
      encryptedImageService: encryptedImageService,
      encryptedMediaService: encryptedMediaService,
      secureContentKeyBase64: keyBase64,
      mediaKeyBase64: keyBase64,
    );
    final secureContentEncryptionJobManager = SecureContentEncryptionJobManager(
      coordinator: secureContentCoordinator,
    );
    final adminActivityService = AdminActivityService(cacheStore: cacheStore);
    final adminAuthService = AdminAuthService(
      cacheStore: cacheStore,
      activityService: adminActivityService,
    );
    final services = AppServices(
      database: database,
      cacheStore: cacheStore,
      daylySportLocator: locator,
      importCoordinator: importCoordinator,
      assetResolver: assetResolver,
      encryptedMediaService: encryptedMediaService,
      encryptedJsonService: encryptedJsonService,
      encryptedImageService: encryptedImageService,
      secureContentCoordinator: secureContentCoordinator,
      secureContentEncryptionJobManager: secureContentEncryptionJobManager,
      adminActivityService: adminActivityService,
      adminAuthService: adminAuthService,
      leagueStandingsSource: leagueStandingsSource,
      teamRawSource: teamRawSource,
      daylysportSyncCoordinator: syncCoordinator,
      logger: logger,
    );

    final setupResult = await services.adminAuthService.createInitialAdmin(
      username: 'opslead',
      displayName: 'Lead Operations',
      password: 'Secure123',
      confirmPassword: 'Secure123',
      persistSession: false,
    );
    expect(setupResult.success, isTrue);

    final secondUserResult = await services.adminAuthService.createUser(
      username: 'nightshift',
      displayName: 'Night Shift',
      password: 'Night123',
      confirmPassword: 'Night123',
    );
    expect(secondUserResult.success, isTrue);

    final primaryUser = services.adminAuthService.users.firstWhere(
      (user) => user.username == 'opslead',
    );
    final totalBytes =
        jsonFile.lengthSync() + imageFile.lengthSync() + videoFile.lengthSync();
    await services.adminActivityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.encryptionBatch,
        occurredAtUtc: DateTime.now().toUtc(),
        summary: 'Processed 3 secure content items for encryption.',
        category: 'mixed',
        actorUserId: primaryUser.id,
        actorUsername: primaryUser.username,
        itemCount: 3,
        totalBytes: totalBytes,
      ),
    );

    await services.adminAuthService.logout();

    return _AdminDashboardHarness(tempRoot: tempRoot, services: services);
  }

  Future<void> dispose() async {
    services.secureContentEncryptionJobManager.dispose();
    await services.database.close();
    await _clearPathProviderMock();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }

  void disposeForTest() {
    services.secureContentEncryptionJobManager.dispose();
  }
}

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
