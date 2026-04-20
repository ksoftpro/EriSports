import 'dart:convert';
import 'dart:io';

import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/config/app_product_variant.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:eri_sports/features/admin/presentation/admin_login_screen.dart';
import 'package:eri_sports/features/more/presentation/secure_content_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/sqlite_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin dashboard stays protected until login and shows tracked stats', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;

    final harness = await _AdminDashboardHarness.create();
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
          appProductVariantProvider.overrideWithValue(AppProductVariant.admin),
        ],
        child: const EriSportsApp(),
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
    required this.preferences,
    required this.services,
  });

  final Directory tempRoot;
  final SharedPreferences preferences;
  final AppServices services;

  static Future<_AdminDashboardHarness> create() async {
    initSqlite3ForTests();

    final tempRoot = await Directory.systemTemp.createTemp('eri_admin_dashboard_');
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
    final services = await AppServices.create(sharedPreferences: preferences);

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
      preferences: preferences,
      services: services,
    );
  }

  Future<void> dispose() async {
    await services.database.close();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}