import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// See dev_notes.md §5 "Visual design direction" for the reasoning behind
/// these choices (palette, why two font widths, why a separate
/// primary/primaryStrong).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryStrong,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.charcoal,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.primaryTint,
      onSecondaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.line,
    );

    final baseText = ThemeData(brightness: Brightness.light).textTheme;
    final condensed = GoogleFonts.barlowCondensedTextTheme(baseText);
    final textTheme = GoogleFonts.barlowTextTheme(baseText).copyWith(
      displayLarge: condensed.displayLarge?.copyWith(fontWeight: FontWeight.w800),
      displayMedium: condensed.displayMedium?.copyWith(fontWeight: FontWeight.w800),
      displaySmall: condensed.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: condensed.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: condensed.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: condensed.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: condensed.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: condensed.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 19,
      ),
      titleSmall: condensed.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: condensed.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 21,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0.5,
        shadowColor: AppColors.ink.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryTint,
        labelStyle: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.inkSoft),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryStrong,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.inkSoft,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line),
    );
  }
}
