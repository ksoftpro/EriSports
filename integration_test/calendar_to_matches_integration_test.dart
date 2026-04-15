import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calendar date tap navigates to matches with correct date', (tester) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final services = await AppServices.create(sharedPreferences: sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appServicesProvider.overrideWithValue(services),
        ],
        child: const EriSportsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Open the menu and tap Calendar
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar').first.hitTestable());
    await tester.pumpAndSettle();

    // Find the CalendarDatePicker and tap a date
    final calendarFinder = find.byType(CalendarDatePicker);
    expect(calendarFinder, findsOneWidget);

    // Tap Today (should always exist in test data)
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    await tester.tap(find.text('${todayDay.day}').first);
    await tester.pumpAndSettle();

    // Should navigate to Matches and show Today as active tab
    expect(find.text('Today'), findsWidgets);
    // Should show at least one fixture for today
    expect(find.textContaining('Arsenal'), findsWidgets);
    expect(find.textContaining('Liverpool'), findsWidgets);
  });
}
