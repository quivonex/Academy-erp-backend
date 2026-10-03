import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Single light ThemeData for the whole app, built on the premium
/// "Material Indigo EdTech" system (Inter, deep indigo, tonal surfaces).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const colors = AppColors.light;

    final font = GoogleFonts.inter();

    TextStyle s(
      double size,
      FontWeight weight,
      double lineHeight, {
      double tracking = 0,
      Color? color,
    }) =>
        font.copyWith(
          fontSize: size,
          fontWeight: weight,
          height: lineHeight / size,
          letterSpacing: tracking * size,
          color: color ?? colors.textPrimary,
        );

    final textTheme = TextTheme(
      displayLarge: s(32, FontWeight.w700, 40, tracking: -0.02),
      displayMedium: s(26, FontWeight.w700, 34, tracking: -0.015),
      displaySmall: s(24, FontWeight.w600, 32, tracking: -0.01),
      headlineLarge: s(28, FontWeight.w700, 34, tracking: -0.02),
      headlineMedium: s(24, FontWeight.w700, 32, tracking: -0.015),
      headlineSmall: s(22, FontWeight.w600, 28, tracking: -0.01),
      titleLarge: s(18, FontWeight.w600, 24, tracking: -0.005),
      titleMedium: s(16, FontWeight.w600, 22),
      titleSmall: s(14, FontWeight.w600, 20),
      bodyLarge: s(16, FontWeight.w400, 24),
      bodyMedium: s(14, FontWeight.w400, 20),
      bodySmall: s(12, FontWeight.w400, 16, color: colors.textMuted),
      labelLarge: s(14, FontWeight.w600, 20, tracking: 0.01),
      labelMedium: s(12, FontWeight.w500, 16,
          tracking: 0.02, color: colors.textMuted),
      labelSmall: s(11, FontWeight.w600, 14, tracking: 0.03),
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: colors.primary,
      onPrimary: Colors.white,
      primaryContainer: colors.primaryTonal,
      onPrimaryContainer: colors.primaryDeep,
      secondary: colors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: colors.primaryTonal,
      onSecondaryContainer: colors.primaryDeep,
      tertiary: colors.success,
      tertiaryContainer: colors.successBg,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textMuted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF4F3FF),
      surfaceContainer: const Color(0xFFEEF0FF),
      surfaceContainerHigh: const Color(0xFFE6E9FF),
      surfaceContainerHighest: const Color(0xFFDDE2FD),
      outline: const Color(0xFFCBD5E1),
      outlineVariant: colors.borderSubtle,
      error: colors.danger,
      errorContainer: colors.dangerBg,
    );

    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      textTheme: textTheme,
      extensions: const [colors],
      dividerColor: colors.borderSubtle,
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: const Color(0x1A4F46E5),
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x140F172A),
        margin: const EdgeInsets.symmetric(vertical: 5),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0x334F46E5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textMuted,
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: const Color(0xFFE2E8F0),
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primaryTonal
                : colors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primary
                : colors.textMuted,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFFE2E8F0)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: colors.surface,
        collapsedBackgroundColor: colors.surface,
        iconColor: colors.primary,
        textColor: colors.textPrimary,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.transparent),
        ),
        collapsedShape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.transparent),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textSubtle),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? colors.primary
              : colors.textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.primaryTonal,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderSubtle),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: textTheme.labelLarge,
          shape: roundedMd,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: colors.borderSubtle)),
        side: BorderSide(color: colors.borderSubtle),
        backgroundColor: colors.surface,
        selectedColor: colors.primaryTonal,
        checkmarkColor: colors.primary,
        labelStyle: textTheme.labelLarge?.copyWith(color: colors.textMuted),
        secondaryLabelStyle:
            textTheme.labelLarge?.copyWith(color: colors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.primaryTonal,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.textMuted,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? colors.primary : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.primaryTonal,
        circularTrackColor: colors.primaryTonal,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF283044),
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: const Color(0xFFEEF0FF)),
        shape: roundedMd,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: const Color(0x334F46E5),
        shape: roundedMd,
        textStyle: textTheme.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.primary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        minVerticalPadding: 12,
        horizontalTitleGap: 14,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: const Color(0xFF0F172A),
        ),
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: colors.textMuted),
        leadingAndTrailingTextStyle:
            textTheme.labelMedium?.copyWith(color: colors.textMuted),
        selectedColor: colors.primary,
        selectedTileColor: colors.primaryTonal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
        headingTextStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: const Color(0xFF475569),
        ),
        dataTextStyle: textTheme.bodyMedium,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        dividerThickness: 1,
        horizontalMargin: 20,
        columnSpacing: 28,
      ),
    );
  }
}
