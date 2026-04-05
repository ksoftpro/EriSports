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
      useMaterial3: true,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.62)),
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.25),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.82)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFFEFF3FC),
        selectedColor: const Color(0xFF0E6BFF),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.68),
        indicatorColor: scheme.primary,
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
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface.withValues(alpha: 0.84),
        textColor: scheme.onSurface,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        textStyle: TextStyle(color: scheme.onSurface),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
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
      useMaterial3: true,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151D28),
        hintStyle: TextStyle(
          color: AppColorTokens.textSecondary.withValues(alpha: 0.86),
        ),
        labelStyle: TextStyle(
          color: AppColorTokens.textSecondary.withValues(alpha: 0.86),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.85)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.25),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1B5FCC),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorTokens.textPrimary,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColorTokens.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF202A38),
        selectedColor: const Color(0xFF1E4FA3),
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColorTokens.textPrimary,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColorTokens.textPrimary,
        unselectedLabelColor: AppColorTokens.textSecondary,
        indicatorColor: AppColorTokens.accent,
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
      listTileTheme: const ListTileThemeData(
        iconColor: AppColorTokens.textSecondary,
        textColor: AppColorTokens.textPrimary,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColorTokens.surface,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorTokens.surface,
      ),
    );
  }
}