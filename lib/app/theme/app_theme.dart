import 'package:eri_sports/app/theme/color_tokens.dart';
import 'package:eri_sports/app/theme/typography_tokens.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get darkTheme {
    final scheme = const ColorScheme.dark(
      primary: AppColorTokens.accent,
      onPrimary: AppColorTokens.textPrimary,
      secondary: AppColorTokens.surfaceAlt,
      onSecondary: AppColorTokens.textPrimary,
      error: AppColorTokens.danger,
      onError: AppColorTokens.textPrimary,
      surface: AppColorTokens.surface,
      onSurface: AppColorTokens.textPrimary,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorTokens.base,
      colorScheme: scheme,
      textTheme: AppTypographyTokens.textTheme.apply(
        bodyColor: AppColorTokens.textPrimary,
        displayColor: AppColorTokens.textPrimary,
      ),
      cardColor: AppColorTokens.surface,
      dividerColor: AppColorTokens.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorTokens.base,
        foregroundColor: AppColorTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColorTokens.surface,
        indicatorColor: AppColorTokens.surfaceAlt,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColorTokens.accent);
          }
          return const IconThemeData(color: AppColorTokens.textSecondary);
        }),
      ),
    );
  }
}