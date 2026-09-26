import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds the single light ThemeData used across both the Enterprise ERP
/// shell and the Faculty Workspace shell. DESIGN.md specifies a light-mode
/// only interface ("optimized for daylight campus operations"), so there is
/// intentionally no dark theme here yet.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const colors = AppColors.light;

    final headingFont = GoogleFonts.plusJakartaSans();
    final bodyFont = GoogleFonts.inter();

    final textTheme = TextTheme(
      // display-lg: 30px / 700 / -0.02em
      displayLarge: headingFont.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 38 / 30,
        letterSpacing: -0.02 * 30,
        color: colors.textPrimary,
      ),
      // display-md: 24px / 600 / -0.015em
      displayMedium: headingFont.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.015 * 24,
        color: colors.textPrimary,
      ),
      // headline-sm: 18px / 600 / -0.01em
      titleLarge: headingFont.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 26 / 18,
        letterSpacing: -0.01 * 18,
        color: colors.textPrimary,
      ),
      // metric-xl: 28px / 700 / -0.025em — stat card headline numbers
      headlineLarge: headingFont.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
        letterSpacing: -0.025 * 28,
        color: colors.textPrimary,
      ),
      // body-lg: 15px / 400
      bodyLarge: bodyFont.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        color: colors.textPrimary,
      ),
      // body-md: 14px / 400
      bodyMedium: bodyFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: colors.textPrimary,
      ),
      // body-md-medium: 14px / 500
      titleMedium: bodyFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: colors.textPrimary,
      ),
      // body-sm: 13px / 400
      bodySmall: bodyFont.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: colors.textMuted,
      ),
      // label-md: 12px / 600 / 0.01em — nav labels, table headers
      labelLarge: bodyFont.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.01 * 12,
        color: colors.textMuted,
      ),
      // label-sm: 11px / 500 / 0.02em — status pills, micro labels
      labelSmall: bodyFont.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 14 / 11,
        letterSpacing: 0.02 * 11,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        primary: colors.primary,
        secondary: colors.secondary,
        surface: colors.surface,
        error: colors.danger,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      extensions: const [colors],
      dividerColor: colors.borderSubtle,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Cards & Data Panels: 12px
          side: BorderSide(color: colors.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // Inputs/buttons: 8px
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textSubtle),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderSubtle),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(), // Badges/status pills: fully rounded
        side: BorderSide.none,
        labelStyle: textTheme.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: MaterialStateProperty.all(colors.canvas),
        headingTextStyle: textTheme.labelLarge,
        dataRowMinHeight: 44, // Dense Data Tables: 44px rows
        dataRowMaxHeight: 44,
        dividerThickness: 1,
      ),
    );
  }
}
