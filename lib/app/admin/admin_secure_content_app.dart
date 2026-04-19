import 'dart:async';

import 'package:eri_sports/app/bootstrap/admin_app_services.dart';
import 'package:eri_sports/app/theme/app_theme.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/features/more/presentation/secure_content_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminSecureContentApp extends ConsumerStatefulWidget {
  const AdminSecureContentApp({super.key});

  @override
  ConsumerState<AdminSecureContentApp> createState() =>
      _AdminSecureContentAppState();
}

class _AdminSecureContentAppState extends ConsumerState<AdminSecureContentApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      unawaited(ref.read(adminAppServicesProvider).secureContentCoordinator.warmUp());
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EriSports Admin',
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SecureContentScreen(),
    );
  }
}