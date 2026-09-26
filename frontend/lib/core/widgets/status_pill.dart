import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum PillTone { success, warning, danger, info, neutral }

/// "Rendered in full pill shape with a 20px or 24px height, a solid 6px
/// circular dot indicator followed by label text" — DESIGN.md § Status
/// Badges & Pills.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone, this.compact = false});

  final String label;
  final PillTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (fg, bg) = switch (tone) {
      PillTone.success => (colors.success, colors.successBg),
      PillTone.warning => (colors.warning, colors.warningBg),
      PillTone.danger => (colors.danger, colors.dangerBg),
      PillTone.info => (colors.info, colors.infoBg),
      PillTone.neutral => (colors.textMuted, colors.canvas),
    };

    return Container(
      height: compact ? 20 : 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
