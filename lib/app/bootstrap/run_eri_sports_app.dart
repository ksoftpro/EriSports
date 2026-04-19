import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/config/app_product_variant.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> runEriSportsApp(AppProductVariant variant) async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  final services = await AppServices.create(
    sharedPreferences: sharedPreferences,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        appServicesProvider.overrideWithValue(services),
        appProductVariantProvider.overrideWithValue(variant),
      ],
      child: const EriSportsApp(),
    ),
  );
}
