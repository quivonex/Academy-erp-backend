import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Shared building blocks for the admin web console, following the
/// "Luminous Enterprise" Stitch design: white cards with hairline borders,
/// indigo→periwinkle gradient actions, Plus Jakarta Sans headlines.
/// Pure UI — no data access.

/// Plus Jakarta Sans applied on top of an existing text style.
TextStyle jakarta(TextStyle? base) =>
    GoogleFonts.plusJakartaSans(textStyle: base);

/// 135° indigo → periwinkle gradient used on primary actions and avatars.
const LinearGradient kAdminGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
);

/// Alternate avatar gradients so neighbouring rows look distinct.
const List<List<Color>> kAvatarGradients = [
  [Color(0xFF4F46E5), Color(0xFF6366F1)],
  [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  [Color(0xFF3B82F6), Color(0xFF6366F1)],
  [Color(0xFF0EA5E9), Color(0xFF4F46E5)],
];

List<Color> avatarGradientFor(String seed) {
  final sum = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return kAvatarGradients[sum % kAvatarGradients.length];
}

/// Two-letter initials, e.g. "ABC Academy Pune" -> "AP".
String adminInitials(String value, {String fallback = '?'}) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) {
    final word = parts.first;
    return (word.length >= 2 ? word.substring(0, 2) : word).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Level-1 card: white, 16px radius, hairline border, soft ambient shadow.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.gradientWash = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Faint indigo wash in the top-right corner (hero cards).
  final bool gradientWash;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(16);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        gradient: gradientWash
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.topRight,
                colors: [Colors.white, Colors.white, Color(0xFFF1F0FF)],
                stops: [0, 0.6, 1],
              )
            : null,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0D4F46E5),
            blurRadius: 15,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          hoverColor: const Color(0xFFF8FAFC),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Rounded square icon holder with a tonal background.
class AdminIconTile extends StatelessWidget {
  const AdminIconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final double size;
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
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: (foreground ?? colors.primary).withValues(alpha: 0.12),
        ),
      ),
      child: Icon(icon, size: size * 0.5, color: foreground ?? colors.primary),
    );
  }
}

/// Gradient initials avatar (firms, admins, profile).
class GradientAvatar extends StatelessWidget {
  const GradientAvatar({
    super.key,
    required this.label,
    this.size = 44,
    this.seed,
    this.statusDot,
    this.circle = false,
  });

  final String label;
  final double size;
  final String? seed;
  final Color? statusDot;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final gradient = avatarGradientFor(seed ?? label);

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: jakarta(
          TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );

    if (statusDot == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: statusDot,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small light initials badge used inside tables.
class InitialsBadge extends StatelessWidget {
  const InitialsBadge({super.key, required this.label, this.size = 32});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Primary action with the signature indigo gradient and glow.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(10);

    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: kAdminGradient,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D4F46E5),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else if (icon != null)
                      Icon(icon, size: 18, color: Colors.white),
                    if (loading || icon != null) const SizedBox(width: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White outline button from the design (secondary actions).
class AdminOutlineButton extends StatelessWidget {
  const AdminOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = danger ? const Color(0xFFE11D48) : const Color(0xFF334155);

    final style = OutlinedButton.styleFrom(
      backgroundColor: danger ? const Color(0xFFFFF7F8) : colors.surface,
      foregroundColor: fg,
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      side: BorderSide(
        color: danger ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );

    return SizedBox(
      height: height,
      child: icon == null
          ? OutlinedButton(
              style: style,
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
            ),
    );
  }
}

/// Small pill used for eyebrows / counters ("● 2 total academies").
class SoftBadge extends StatelessWidget {
  const SoftBadge({
    super.key,
    required this.label,
    this.dot = false,
    this.icon,
    this.background,
    this.foreground,
    this.monospace = false,
  });

  final String label;
  final bool dot;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = foreground ?? colors.primary;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background ?? colors.primaryTonal,
          borderRadius: BorderRadius.circular(monospace ? 6 : 999),
          border: Border.all(color: fg.withValues(alpha: 0.18)),
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
                style: monospace
                    ? TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      )
                    : Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page title block: optional eyebrow, Jakarta headline, subtitle, actions.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.titleTrailing = const [],
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? eyebrow;
  final List<Widget> titleTrailing;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 700;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[eyebrow!, const SizedBox(height: 10)],
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: jakarta(
                textTheme.headlineLarge?.copyWith(
                  fontSize: compact ? 24 : 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            ...titleTrailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );

    if (actions.isEmpty) return titleBlock;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
      ],
    );
  }
}

/// Filter pill with a count bubble ("ACTIVE 2").
class CountFilterPill extends StatelessWidget {
  const CountFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? colors.primary : colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.primary : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: textTheme.labelSmall?.copyWith(
                      color: selected ? Colors.white : colors.textMuted,
                    ),
                  ),
                ),
              ] else
                const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search box styled as a white card field.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: colors.surface,
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: border(const Color(0xFFE2E8F0)),
        enabledBorder: border(const Color(0xFFE2E8F0)),
        focusedBorder: border(const Color(0xFF6366F1), 1.5),
        suffixIcon: controller.text.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                  ),
                  child: const Text('Clear'),
                ),
              ),
      ),
    );
  }
}

/// Empty / error block for admin pages.
class AdminStateMessage extends StatelessWidget {
  const AdminStateMessage({
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

    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminIconTile(
                icon: icon,
                size: 56,
                background: isError ? colors.dangerBg : colors.primaryTonal,
                foreground: isError ? colors.danger : colors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: jakarta(textTheme.titleLarge),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style:
                    textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                GradientButton(
                  label: actionLabel!,
                  icon: Icons.refresh_rounded,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Label + field wrapper for dialog forms ("Firm Name *").
class FieldLabel extends StatelessWidget {
  const FieldLabel({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.trailing,
  });

  final String label;
  final Widget child;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: const Color(0xFF0F172A),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Input style for admin dialog forms.
InputDecoration adminFieldDecoration(
  BuildContext context, {
  String? hint,
  IconData? icon,
  Widget? suffix,
  String? helper,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );

  return InputDecoration(
    hintText: hint,
    helperText: helper,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon: suffix,
    counterText: '',
    border: border(const Color(0xFFCBD5E1)),
    enabledBorder: border(const Color(0xFFDCE1EA)),
    focusedBorder: border(const Color(0xFF6366F1), 1.5),
    errorBorder: border(context.colors.danger),
    focusedErrorBorder: border(context.colors.danger, 1.5),
  );
}

/// Modal shell used by every admin form dialog: icon header, scrollable body,
/// footer actions — matching the "Register New Firm" design.
class AdminFormDialog extends StatelessWidget {
  const AdminFormDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    this.onClose,
    this.maxWidth = 560,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x99FFFFFF)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 14, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8F9FF), Colors.white],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFEEF0F5))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminIconTile(icon: icon, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: jakarta(
                            textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: 'Close',
                      onPressed: onClose,
                      icon: Icon(Icons.close_rounded,
                          color: colors.textMuted),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: body,
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEF0F5))),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-column responsive form row (collapses to one column when narrow).
class FormRow extends StatelessWidget {
  const FormRow({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

/// Inline error banner used in dialogs.
class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
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
