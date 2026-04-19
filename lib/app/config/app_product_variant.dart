import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppProductVariant { client, admin }

extension AppProductVariantX on AppProductVariant {
  String get appTitle {
    switch (this) {
      case AppProductVariant.client:
        return 'EriSports';
      case AppProductVariant.admin:
        return 'EriSports Admin';
    }
  }

  String get initialLocation {
    switch (this) {
      case AppProductVariant.client:
        return '/home';
      case AppProductVariant.admin:
        return '/secure-content';
    }
  }

  bool get runsStartupBootstrap => this == AppProductVariant.client;

  bool get supportsBackgroundMonitoring => this == AppProductVariant.client;

  bool get showsStartupUi => this == AppProductVariant.client;
}

final appProductVariantProvider = Provider<AppProductVariant>(
  (ref) => AppProductVariant.client,
);
