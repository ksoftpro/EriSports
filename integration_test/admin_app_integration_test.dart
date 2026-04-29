import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/config/app_product_variant.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/features/admin/presentation/admin_login_screen.dart';
import 'package:eri_sports/features/more/presentation/secure_content_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/test_helpers/sqlite_test_helper.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'admin app supports setup, user management, password rotation, and protected login',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1900);
      tester.view.devicePixelRatio = 1.0;

      final harness = await _AdminIntegrationHarness.create();
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await harness.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(harness.preferences),
            appServicesProvider.overrideWithValue(harness.services),
            appProductVariantProvider.overrideWithValue(
              AppProductVariant.admin,
            ),
          ],
          child: const EriSportsApp(),
        ),
      );
        testWidgets(
          'admin app generates a session-bound verification QR from a pasted client request code',
          (tester) async {
      await _pumpForUi(tester, frames: 18);

      expect(find.text('Initialize Admin Access'), findsOneWidget);
      expect(find.byKey(adminLoginDisplayNameFieldKey), findsOneWidget);

      await tester.enterText(
        find.byKey(adminLoginDisplayNameFieldKey),
        'Lead Operations',
      );
      await tester.enterText(find.byKey(adminLoginUsernameFieldKey), 'opslead');
      await tester.enterText(
        find.byKey(adminLoginPasswordFieldKey),
        'Secure123',
      );
      await tester.enterText(
        find.byKey(adminLoginConfirmPasswordFieldKey),
        'Secure123',
      );
      await tester.tap(find.byKey(adminLoginSubmitButtonKey).hitTestable());
      await _pumpForUi(tester, frames: 28);

      expect(find.text('Secure Content Operations'), findsOneWidget);
      expect(find.byKey(adminDashboardOverviewKey), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);

      await tester.tap(find.byKey(adminDashboardCoverageTabKey).hitTestable());
      await _pumpForUi(tester, frames: 8);

      await tester.tap(find.byKey(adminDashboardHomeTabKey).hitTestable());
      await _pumpForUi(tester, frames: 8);

      await tester.tap(find.byKey(adminDashboardMenuButtonKey).hitTestable());
      await _pumpForUi(tester, frames: 8);
      await tester.tap(find.text('Create admin user').last.hitTestable());
      await _pumpForUi(tester, frames: 8);

      await tester.enterText(
        find.byKey(adminCreateUserDisplayNameFieldKey),
        'Night Shift',
      );
      await tester.enterText(
        find.byKey(adminCreateUserUsernameFieldKey),
        'nightshift',
      );
      await tester.enterText(
        find.byKey(adminCreateUserPasswordFieldKey),
        'Night123',
      );
      await tester.enterText(
        find.byKey(adminCreateUserConfirmPasswordFieldKey),
        'Night123',
      );
      await tester.tap(
        find.byKey(adminCreateUserSubmitButtonKey).hitTestable(),
      );
      await _pumpForUi(tester, frames: 18);

      expect(find.textContaining('Admin user created.'), findsOneWidget);
      expect(find.textContaining('Night Shift'), findsWidgets);

      await tester.tap(find.byKey(adminDashboardMenuButtonKey).hitTestable());
      await _pumpForUi(tester, frames: 8);
      await tester.tap(find.text('Change password').last.hitTestable());
      await _pumpForUi(tester, frames: 8);

      await tester.enterText(
        find.byKey(adminChangePasswordCurrentFieldKey),
        'Secure123',
      );
      await tester.enterText(
        find.byKey(adminChangePasswordNewFieldKey),
        'Secure456',
      );
      await tester.enterText(
        find.byKey(adminChangePasswordConfirmFieldKey),
        'Secure456',
      );
      await tester.tap(
        find.byKey(adminChangePasswordSubmitButtonKey).hitTestable(),
      );
      await _pumpForUi(tester, frames: 18);

      expect(find.text('Password updated successfully.'), findsOneWidget);

      await tester.tap(
        find.byKey(adminDashboardOperationsTabKey).hitTestable(),
      );
      await _pumpForUi(tester, frames: 8);
      await tester.tap(find.text('Warm secure caches').first.hitTestable());
      await _pumpForUi(tester, frames: 18);
      expect(
        find.text(
          'Secure runtime caches are ready for JSON, images, and video.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Logout').first.hitTestable());
      await _pumpForUi(tester, frames: 18);

      expect(find.text('Admin Secure Content Console'), findsOneWidget);
      await tester.enterText(find.byKey(adminLoginUsernameFieldKey), 'opslead');
      await tester.enterText(
        find.byKey(adminLoginPasswordFieldKey),
        'Secure123',
      );
      await tester.tap(find.byKey(adminLoginSubmitButtonKey).hitTestable());
      await _pumpForUi(tester, frames: 18);

      expect(find.text('Invalid username or password.'), findsOneWidget);

      await tester.enterText(
        find.byKey(adminLoginPasswordFieldKey),
        'Secure456',
      );
      await tester.tap(find.byKey(adminLoginSubmitButtonKey).hitTestable());
      await _pumpForUi(tester, frames: 18);

      expect(find.text('Secure Content Operations'), findsOneWidget);
      expect(find.textContaining('Lead Operations'), findsWidgets);

      await tester.tap(find.text('Logout').first.hitTestable());
      await _pumpForUi(tester, frames: 18);

      await tester.enterText(
        find.byKey(adminLoginUsernameFieldKey),
        'nightshift',
      );
      await tester.enterText(
        find.byKey(adminLoginPasswordFieldKey),
        'Night123',
      );
      await tester.tap(find.byKey(adminLoginSubmitButtonKey).hitTestable());
      await _pumpForUi(tester, frames: 18);

      expect(find.text('Secure Content Operations'), findsOneWidget);
      expect(
        find.textContaining('Signed in as Night Shift (nightshift).'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(adminDashboardActivityTabKey).hitTestable());
      await _pumpForUi(tester, frames: 8);
      expect(find.byKey(adminDashboardRecentActivityKey), findsOneWidget);
      expect(find.text('Real-time logs'), findsOneWidget);
    },
  );

  testWidgets(
    'admin app generates a session-bound verification QR from a pasted client request code',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1900);
      tester.view.devicePixelRatio = 1.0;

      final harness = await _AdminIntegrationHarness.create();
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await harness.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(harness.preferences),
            appServicesProvider.overrideWithValue(harness.services),
            appProductVariantProvider.overrideWithValue(
              AppProductVariant.admin,
            ),
          ],
          child: const EriSportsApp(),
        ),
      );
      await _pumpForUi(tester, frames: 18);

      expect(find.text('Initialize Admin Access'), findsOneWidget);
      await tester.enterText(
        find.byKey(adminLoginDisplayNameFieldKey),
        'Lead Operations',
      );
      await tester.enterText(find.byKey(adminLoginUsernameFieldKey), 'opslead');
      await tester.enterText(
        find.byKey(adminLoginPasswordFieldKey),
        'Secure123',
      );
      await tester.enterText(
        find.byKey(adminLoginConfirmPasswordFieldKey),
        'Secure123',
      );
      await tester.tap(find.byKey(adminLoginSubmitButtonKey).hitTestable());
      await _pumpForUi(tester, frames: 28);

      expect(find.text('Secure Content Operations'), findsOneWidget);

      await tester.tap(
        find.byKey(adminDashboardOperationsTabKey).hitTestable(),
      );
      await _pumpForUi(tester, frames: 8);

      final verificationService = ContentVerificationService(
        cacheStore: harness.services.cacheStore,
      );
      final request = verificationService.createClientVerificationRecord(
        identity: const DeviceVerificationIdentity(
          seed: 'integration-client-device',
          source: VerificationSeedSource.hostnameFallback,
        ),
        pendingCounts: const ContentVerificationPendingCounts(
          reels: 1,
          videoHighlights: 2,
          videoNews: 0,
          videoUpdates: 0,
          newsImages: 1,
        ),
        now: DateTime.utc(2026, 4, 29, 12),
      );

      expect(find.text('Verification QR operations'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), request.requestCode);
      await tester.tap(find.text('Generate from pasted code').hitTestable());
      await _pumpForUi(tester, frames: 18);

      expect(
        find.text('Scan this session-bound QR from the client app'),
        findsOneWidget,
      );
      expect(find.text('Session-bound admin approval'), findsOneWidget);
      expect(find.text('Valid until'), findsOneWidget);
    },
  );
}

Future<void> _pumpForUi(WidgetTester tester, {int frames = 10}) async {
  await tester.pump();
  for (var index = 0; index < frames; index += 1) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

class _AdminIntegrationHarness {
  _AdminIntegrationHarness({
    required this.tempRoot,
    required this.preferences,
    required this.services,
  });

  final Directory tempRoot;
  final SharedPreferences preferences;
  final AppServices services;

  static Future<_AdminIntegrationHarness> create() async {
    initSqlite3ForTests();

    final tempRoot = await Directory.systemTemp.createTemp('eri_admin_it_');
    await _installPathProviderMock(tempRoot);

    final daylySportDir = Directory(
      '${tempRoot.path}${Platform.pathSeparator}daylySport',
    )..createSync(recursive: true);
    final sourceDir = Directory(
      '${tempRoot.path}${Platform.pathSeparator}source',
    )..createSync(recursive: true);

    final jsonFile = File(
      '${sourceDir.path}${Platform.pathSeparator}table.json',
    )..writeAsStringSync(
      jsonEncode(<String, Object>{'league': 'Premier League'}),
    );
    final imageFile = File(
      '${sourceDir.path}${Platform.pathSeparator}badge.png',
    )..writeAsBytesSync(<int>[137, 80, 78, 71, 1, 2, 3, 4, 5, 6, 7, 8]);
    final videoFile = File('${sourceDir.path}${Platform.pathSeparator}goal.mp4')
      ..writeAsBytesSync(List<int>.generate(4096, (index) => index % 251));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'daylysport.custom_json_folder': daylySportDir.path,
    });
    final preferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: preferences);

    final result = await services.secureContentCoordinator.encryptImportedFiles(
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
    if (result.failedCount > 0) {
      throw StateError('Failed to seed encrypted admin fixture data.');
    }

    return _AdminIntegrationHarness(
      tempRoot: tempRoot,
      preferences: preferences,
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
