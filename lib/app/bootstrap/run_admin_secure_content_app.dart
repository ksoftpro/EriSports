import 'package:eri_sports/app/admin/admin_secure_content_app.dart';
import 'package:eri_sports/app/bootstrap/admin_app_services.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> runAdminSecureContentApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  final services = await AdminAppServices.create(
    sharedPreferences: sharedPreferences,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        adminAppServicesProvider.overrideWithValue(services),
      ],
      child: const AdminSecureContentApp(),
    ),
  );
}