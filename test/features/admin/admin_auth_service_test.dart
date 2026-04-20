import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/admin/data/admin_activity_service.dart';
import 'package:eri_sports/features/admin/data/admin_auth_service.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AdminAuthService', () {
    late SharedPreferences preferences;
    late DaylySportCacheStore cacheStore;
    late AdminActivityService activityService;
    late AdminAuthService authService;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();
      cacheStore = DaylySportCacheStore(sharedPreferences: preferences);
      activityService = AdminActivityService(cacheStore: cacheStore);
      authService = AdminAuthService(
        cacheStore: cacheStore,
        activityService: activityService,
      );
    });

    test('requires setup until first admin is created and enforces login', () async {
      expect(authService.requiresSetup, isTrue);

      final setupResult = await authService.createInitialAdmin(
        username: 'Lead.Admin',
        displayName: 'Lead Admin',
        password: 'Secure123',
        confirmPassword: 'Secure123',
        persistSession: false,
      );

      expect(setupResult.success, isTrue);
      expect(authService.requiresSetup, isFalse);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentSession?.username, 'lead.admin');

      await authService.logout();
      expect(authService.isAuthenticated, isFalse);

      final failedLogin = await authService.login(
        username: 'lead.admin',
        password: 'Wrong123',
        persistSession: false,
      );

      expect(failedLogin.success, isFalse);
      expect(failedLogin.message, 'Invalid username or password.');

      final successfulLogin = await authService.login(
        username: 'lead.admin',
        password: 'Secure123',
        persistSession: false,
      );

      expect(successfulLogin.success, isTrue);
      expect(authService.currentSession?.displayName, 'Lead Admin');
      expect(
        activityService.records.any(
          (record) => record.type == AdminActivityType.loginFailure,
        ),
        isTrue,
      );
    });

    test('supports multiple admin users and password updates', () async {
      final setupResult = await authService.createInitialAdmin(
        username: 'opslead',
        displayName: 'Ops Lead',
        password: 'Secure123',
        confirmPassword: 'Secure123',
        persistSession: false,
      );
      expect(setupResult.success, isTrue);

      final createUserResult = await authService.createUser(
        username: 'nightshift',
        displayName: 'Night Shift',
        password: 'Night123',
        confirmPassword: 'Night123',
      );

      expect(createUserResult.success, isTrue);
      expect(authService.users.length, 2);
      expect(
        authService.users.map((user) => user.username),
        containsAll(<String>['opslead', 'nightshift']),
      );

      final passwordChangeResult = await authService.changeCurrentPassword(
        currentPassword: 'Secure123',
        newPassword: 'Secure456',
        confirmPassword: 'Secure456',
      );

      expect(passwordChangeResult.success, isTrue);

      await authService.logout();

      final oldPasswordLogin = await authService.login(
        username: 'opslead',
        password: 'Secure123',
        persistSession: false,
      );
      expect(oldPasswordLogin.success, isFalse);

      final newPasswordLogin = await authService.login(
        username: 'opslead',
        password: 'Secure456',
        persistSession: false,
      );
      expect(newPasswordLogin.success, isTrue);

      await authService.logout();

      final secondUserLogin = await authService.login(
        username: 'nightshift',
        password: 'Night123',
        persistSession: false,
      );
      expect(secondUserLogin.success, isTrue);
    });
  });
}