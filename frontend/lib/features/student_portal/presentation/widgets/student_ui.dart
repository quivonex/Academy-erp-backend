import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Shared building blocks for the student portal, following the
/// "Material Indigo EdTech" Stitch design. Pure UI — no data access.

const double kStudentPagePadding = 16;
const double kStudentMaxWidth = 720;

/// Centers page content and caps its width on tablets / web.
class StudentPageFrame extends StatelessWidget {
  const StudentPageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kStudentMaxWidth),
        child: child,
      ),
    );
  }
}

/// Level-1 elevated card: white, 16px radius, hairline border, soft shadow.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(16);

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? colors.surface,
          borderRadius: radius,
          border: Border.all(color: colors.borderSubtle),
          boxShadow: colors.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Rounded tonal square holding an icon (course, stat, detail rows).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.background,
    this.foreground,
    this.radius = 12,
  });

  final IconData icon;
  final double size;
  final double radius;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? colors.primaryTonal,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: foreground ?? colors.primary,
      ),
    );
  }
}

/// Small rounded status / meta pill.
class TonalPill extends StatelessWidget {
  const TonalPill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.dot = false,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = foreground ?? colors.primary;

    // Bounded width so the inner Flexible never sees infinite constraints
    // (pills are often placed as non-flex children of a Row).
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? colors.primaryTonal,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Section title row with a leading icon and an optional trailing widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.iconColor,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: iconColor ?? colors.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Selectable filter pill (M3 filter chip look from the design).
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingDot,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? leadingDot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? colors.primaryDeep : colors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.primaryDeep : colors.borderSubtle,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                ] else if (leadingDot != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: leadingDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty / error block with an optional action.
class StudentStateMessage extends StatelessWidget {
  const StudentStateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          IconTile(
            icon: icon,
            size: 56,
            radius: 18,
            background: isError ? colors.dangerBg : colors.primaryTonal,
            foreground: isError ? colors.danger : colors.primary,
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center, style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primaryTonal,
                foregroundColor: colors.primary,
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centered spinner used while a list is loading.
class StudentLoading extends StatelessWidget {
  const StudentLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
    );
  }
}

/// Tonal "load more" button used at the end of paginated lists.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primaryTonal,
            foregroundColor: colors.primary,
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ),
    );
  }
}

/// Inline error line shown under a list when a later page fails.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Initials from a name, e.g. "Aarav Patil" -> "AP".
String initialsOf(String value, {String fallback = 'A'}) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Brand mark used in the student app bars.
class AcademyMark extends StatelessWidget {
  const AcademyMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: colors.heroGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: colors.heroShadow,
      ),
      child: Icon(
        Icons.auto_stories_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

/// Two-line app-bar title: small academy label above the page title.
class StudentBarTitle extends StatelessWidget {
  const StudentBarTitle({
    super.key,
    required this.title,
    this.eyebrow,
  });

  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final label = (eyebrow == null || eyebrow!.trim().isEmpty)
        ? 'Academy'
        : eyebrow!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Pill-indicator bottom navigation shared by the student shell and Explore.
class StudentBottomNav extends StatelessWidget {
  const StudentBottomNav({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const _routes = [
    '/explore',
    '/student/courses',
    '/student/live-classes',
    '/student/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => context.go(_routes[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'My Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv_rounded),
            label: 'Live Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Soft tonal text-field style from the sign-up design: filled lavender,
/// no outline at rest, indigo outline on focus.
InputDecoration premiumFieldDecoration(
  BuildContext context, {
  required String hint,
  IconData? icon,
  Widget? suffix,
}) {
  final colors = context.colors;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF2F3FF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    border: border(Colors.transparent),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(colors.primary, 2),
    errorBorder: border(colors.danger),
    focusedErrorBorder: border(colors.danger, 2),
  );
}

/// Large brand badge used on the sign-in and sign-up screens.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFA78BFA)],
            ),
            boxShadow: colors.heroShadow,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const AcademyMark(size: 60),
          ),
        ),
        Positioned(
          right: -6,
          bottom: -6,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: colors.cardShadow,
            ),
            child: Icon(Icons.school_rounded, size: 18, color: colors.primary),
          ),
        ),
      ],
    );
  }
}
