import 'package:flutter/material.dart';

/// Premium "Material Indigo EdTech" palette, taken from the Stitch DESIGN.md.
/// Access via `context.colors.primary` etc.
///
/// Field names are unchanged from the previous palette so every existing
/// screen keeps compiling; a few new tonal tokens were added for the
/// student-portal redesign.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.primaryHover,
    required this.primaryDeep,
    required this.primaryTonal,
    required this.primaryTonalBorder,
    required this.secondary,
    required this.accentPurple,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
  });

  final Color canvas; // #F8F7FF — lavender-tinted canvas
  final Color surface; // #FFFFFF — cards, bars, sheets
  final Color borderSubtle; // #E6E8F2 — hairline card borders
  final Color textPrimary; // #131B2E — headings, primary text
  final Color textMuted; // #525469 — metadata, descriptors
  final Color textSubtle; // #8E90A6 — placeholders, inactive icons

  final Color primary; // #4F46E5 — deep indigo
  final Color primaryHover; // #4338CA
  final Color primaryDeep; // #3525CD — gradient start, strong CTAs
  final Color primaryTonal; // #EEF0FF — tonal pills, icon tiles
  final Color primaryTonalBorder; // #C7D2FE — selected chip border
  final Color secondary; // #6366F1 — electric periwinkle
  final Color accentPurple; // #8B5CF6

  final Color success; // #047857 — emerald (text-safe)
  final Color successBg; // #E3F8EF
  final Color warning; // #B45309 — amber (text-safe)
  final Color warningBg; // #FEF3C7
  final Color danger; // #BA1A1A
  final Color dangerBg; // #FFE4E1
  final Color info; // #2563EB
  final Color infoBg; // #EFF6FF

  static const light = AppColors(
    canvas: Color(0xFFF8F7FF),
    surface: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFE6E8F2),
    textPrimary: Color(0xFF131B2E),
    textMuted: Color(0xFF525469),
    textSubtle: Color(0xFF8E90A6),
    primary: Color(0xFF4F46E5),
    primaryHover: Color(0xFF4338CA),
    primaryDeep: Color(0xFF3525CD),
    primaryTonal: Color(0xFFEEF0FF),
    primaryTonalBorder: Color(0xFFC7D2FE),
    secondary: Color(0xFF6366F1),
    accentPurple: Color(0xFF8B5CF6),
    success: Color(0xFF047857),
    successBg: Color(0xFFE3F8EF),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFEF3C7),
    danger: Color(0xFFBA1A1A),
    dangerBg: Color(0xFFFFE4E1),
    info: Color(0xFF2563EB),
    infoBg: Color(0xFFEFF6FF),
  );

  /// Signature indigo gradient used on hero cards and live banners.
  LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryDeep, primary, secondary],
      );

  /// Soft ambient shadow for Level-1 cards (DESIGN.md § Elevation).
  List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  /// Indigo-tinted glow for hero surfaces.
  List<BoxShadow> get heroShadow => const [
        BoxShadow(
          color: Color(0x404F46E5),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ];

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textMuted,
    Color? textSubtle,
    Color? primary,
    Color? primaryHover,
    Color? primaryDeep,
    Color? primaryTonal,
    Color? primaryTonalBorder,
    Color? secondary,
    Color? accentPurple,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? danger,
    Color? dangerBg,
    Color? info,
    Color? infoBg,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      primaryTonal: primaryTonal ?? this.primaryTonal,
      primaryTonalBorder: primaryTonalBorder ?? this.primaryTonalBorder,
      secondary: secondary ?? this.secondary,
      accentPurple: accentPurple ?? this.accentPurple,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      borderSubtle: l(borderSubtle, other.borderSubtle),
      textPrimary: l(textPrimary, other.textPrimary),
      textMuted: l(textMuted, other.textMuted),
      textSubtle: l(textSubtle, other.textSubtle),
      primary: l(primary, other.primary),
      primaryHover: l(primaryHover, other.primaryHover),
      primaryDeep: l(primaryDeep, other.primaryDeep),
      primaryTonal: l(primaryTonal, other.primaryTonal),
      primaryTonalBorder: l(primaryTonalBorder, other.primaryTonalBorder),
      secondary: l(secondary, other.secondary),
      accentPurple: l(accentPurple, other.accentPurple),
      success: l(success, other.success),
      successBg: l(successBg, other.successBg),
      warning: l(warning, other.warning),
      warningBg: l(warningBg, other.warningBg),
      danger: l(danger, other.danger),
      dangerBg: l(dangerBg, other.dangerBg),
      info: l(info, other.info),
      infoBg: l(infoBg, other.infoBg),
    );
  }
}

/// Convenience accessor: `context.colors.primary` instead of the full
/// `Theme.of(context).extension<AppColors>()!` every time.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
