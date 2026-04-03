import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final services = await AppServices.create();
  final startupReport =
      await services.importCoordinator.runLocalImport(triggerType: 'startup');

  runApp(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        startupImportReportProvider.overrideWithValue(startupReport),
      ],
      child: const EriSportsApp(),
    ),
  );
}
