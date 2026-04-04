import 'package:eri_sports/app/theme/color_tokens.dart';
import 'package:eri_sports/app/theme/typography_tokens.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final scheme = const ColorScheme.light(
      primary: Color(0xFF0E6BFF),
      onPrimary: Colors.white,
      secondary: Color(0xFFE9EEF8),
      onSecondary: Color(0xFF1B2436),
      error: Color(0xFFD93A4E),
      onError: Colors.white,
      surface: Color(0xFFF8FAFF),
      onSurface: Color(0xFF121826),
      outline: Color(0xFFD8E0EF),
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF2F5FC),
      colorScheme: scheme,
      textTheme: AppTypographyTokens.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      cardColor: Colors.white,
      dividerColor: scheme.outline,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF2F5FC),
        foregroundColor: Color(0xFF121826),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: const Color(0xFF0E6BFF),
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE7EEF9),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF0E6BFF));
          }
          return const IconThemeData(color: Color(0xFF6F7A92));
        }),
      ),
    );
  }

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
      outline: AppColorTokens.border,
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
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: const Color(0xFF1E4FA3),
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
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