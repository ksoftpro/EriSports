import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/admin/data/admin_activity_service.dart';
import 'package:eri_sports/features/admin/data/admin_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminAuthServiceProvider = ChangeNotifierProvider<AdminAuthService>(
  (ref) => ref.read(appServicesProvider).adminAuthService,
);

final adminActivityServiceProvider = ChangeNotifierProvider<AdminActivityService>(
  (ref) => ref.read(appServicesProvider).adminActivityService,
);