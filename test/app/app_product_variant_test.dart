import 'package:eri_sports/app/config/app_product_variant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client variant is the default app product', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appProductVariantProvider), AppProductVariant.client);
  });

  test('admin variant exposes admin-only bootstrap settings', () {
    expect(AppProductVariant.admin.initialLocation, '/secure-content');
    expect(AppProductVariant.admin.runsStartupBootstrap, isFalse);
    expect(AppProductVariant.admin.supportsBackgroundMonitoring, isFalse);
    expect(AppProductVariant.admin.showsStartupUi, isFalse);
    expect(AppProductVariant.admin.appTitle, 'EriSports Admin');
  });
}
