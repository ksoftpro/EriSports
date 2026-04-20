import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/config/app_product_variant.dart';
import 'package:eri_sports/app/navigation/router.dart';
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
import 'package:eri_sports/features/admin/presentation/admin_login_screen.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:eri_sports/features/more/presentation/secure_content_screen.dart';
import 'package:eri_sports/features/team/data/team_raw_source.dart';
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

  testWidgets('admin dashboard stays protected until login and shows tracked stats', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;

    final harness = await _AdminDashboardHarness.create();
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(harness.services),
        appProductVariantProvider.overrideWithValue(AppProductVariant.admin),
      ],
    );
    addTearDown(() async {
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await harness.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await _pumpForUi(tester);

    expect(find.byKey(adminLoginUsernameFieldKey), findsOneWidget);
    expect(find.byKey(adminDashboardOverviewKey), findsNothing);

    await tester.enterText(find.byKey(adminLoginUsernameFieldKey), 'opslead');
    await tester.enterText(find.byKey(adminLoginPasswordFieldKey), 'Wrong123');
    await tester.tap(find.byKey(adminLoginSubmitButtonKey).hitTestable());
    await _pumpForUi(tester);

    expect(find.text('Invalid username or password.'), findsOneWidget);

    await tester.enterText(find.byKey(adminLoginPasswordFieldKey), 'Secure123');
    await tester.tap(find.byKey(adminLoginSubmitButtonKey).hitTestable());
    await _pumpForUi(tester, frames: 20);

    expect(find.byKey(adminDashboardOverviewKey), findsOneWidget);
    expect(find.byKey(adminDashboardUserActivityKey), findsOneWidget);
    expect(find.byKey(adminDashboardRecentActivityKey), findsOneWidget);
    expect(find.text('Category coverage'), findsOneWidget);
    expect(find.text('Date and size trends'), findsOneWidget);
    expect(find.text('User activity'), findsWidgets);
    expect(find.textContaining('Lead Operations'), findsWidgets);
    expect(find.textContaining('Night Shift'), findsWidgets);
  });
}

Future<void> _pumpForUi(WidgetTester tester, {int frames = 8}) async {
  await tester.pump();
  for (var index = 0; index < frames; index += 1) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

class _AdminDashboardHarness {
  _AdminDashboardHarness({
    required this.tempRoot,
    required this.services,
  });

  final Directory tempRoot;
  final AppServices services;

  static Future<_AdminDashboardHarness> create() async {
    initSqlite3ForTests();

    final tempRoot = await Directory.systemTemp.createTemp('eri_admin_dashboard_');
    await _installPathProviderMock(tempRoot);
    final daylySportDir = Directory('${tempRoot.path}${Platform.pathSeparator}daylySport')
      ..createSync(recursive: true);
    final sourceDir = Directory('${tempRoot.path}${Platform.pathSeparator}source')
      ..createSync(recursive: true);

    final jsonFile = File('${sourceDir.path}${Platform.pathSeparator}table.json')
      ..writeAsStringSync(jsonEncode(<String, Object>{'league': 'Premier League'}));
    final imageFile = File('${sourceDir.path}${Platform.pathSeparator}badge.png')
      ..writeAsBytesSync(<int>[137, 80, 78, 71, 1, 2, 3, 4, 5, 6, 7, 8]);
    final videoFile = File('${sourceDir.path}${Platform.pathSeparator}goal.mp4')
      ..writeAsBytesSync(List<int>.generate(4096, (index) => index % 251));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'daylysport.custom_json_folder': daylySportDir.path,
    });
    final preferences = await SharedPreferences.getInstance();
    final cacheStore = DaylySportCacheStore(sharedPreferences: preferences);
    final logger = AppLogger();
    final database = AppDatabase();
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

    await services.secureContentCoordinator.encryptImportedFiles(
      requests: [
        SecureContentEncryptionRequest(
          sourcePath: jsonFile.path,
          relativeOutputPath: 'imports/table.json',
        ),
        SecureContentEncryptionRequest(
          sourcePath: imageFile.path,
          relativeOutputPath: 'news/badge.png',
        ),
        SecureContentEncryptionRequest(
          sourcePath: videoFile.path,
          relativeOutputPath: 'reels/goal.mp4',
        ),
      ],
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

    return _AdminDashboardHarness(
      tempRoot: tempRoot,
      services: services,
    );
  }

  Future<void> dispose() async {
    await services.database.close();
    await _clearPathProviderMock();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
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