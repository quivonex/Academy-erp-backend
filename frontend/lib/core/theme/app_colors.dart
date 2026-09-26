import 'package:flutter/material.dart';

/// Every color value here is copied verbatim from DESIGN.md so the app and
/// the original Stitch mockups never drift. Access via:
///   final colors = Theme.of(context).extension<AppColors>()!;
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

  final Color canvas; // #F8FAFC — app canvas / Layer 0
  final Color surface; // #FFFFFF — cards, modals, toolbars
  final Color borderSubtle; // #E2E8F0 — card/table borders
  final Color textPrimary; // #0F172A — headers, primary metrics
  final Color textMuted; // #64748B — metadata, descriptors
  final Color textSubtle; // #94A3B8 — placeholders, inactive icons

  final Color primary; // #4F46E5 — focal actions, active states
  final Color primaryHover; // #4338CA
  final Color secondary; // #3B82F6 — links, multi-tenant badges
  final Color accentPurple; // #8B5CF6 — cross-campus governance metrics

  final Color success; // #10B981
  final Color successBg; // #ECFDF5
  final Color warning; // #F59E0B
  final Color warningBg; // #FEF3C7
  final Color danger; // #EF4444
  final Color dangerBg; // #FEF2F2
  final Color info; // #3B82F6
  final Color infoBg; // #EFF6FF

  static const light = AppColors(
    canvas: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    textSubtle: Color(0xFF94A3B8),
    primary: Color(0xFF4F46E5),
    primaryHover: Color(0xFF4338CA),
    secondary: Color(0xFF3B82F6),
    accentPurple: Color(0xFF8B5CF6),
    success: Color(0xFF10B981),
    successBg: Color(0xFFECFDF5),
    warning: Color(0xFFF59E0B),
    warningBg: Color(0xFFFEF3C7),
    danger: Color(0xFFEF4444),
    dangerBg: Color(0xFFFEF2F2),
    info: Color(0xFF3B82F6),
    infoBg: Color(0xFFEFF6FF),
  );

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
    return AppColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
    );
  }
}

/// Convenience accessor: `context.colors.primary` instead of the full
/// `Theme.of(context).extension<AppColors>()!` every time.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
