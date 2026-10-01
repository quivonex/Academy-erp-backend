import 'package:flutter/material.dart';

enum PillTone { success, warning, danger, info, neutral }

/// Status badge from the "Luminous Enterprise" design: full pill, 6px dot,
/// tinted fill with a matching hairline border, 11px semibold label.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.compact = false,
  });

  final String label;
  final PillTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border) = switch (tone) {
      PillTone.success => (
          const Color(0xFF059669),
          const Color(0xFFECFDF5),
          const Color(0xFFA7F3D0),
        ),
      PillTone.warning => (
          const Color(0xFFD97706),
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
        ),
      PillTone.danger => (
          const Color(0xFFE11D48),
          const Color(0xFFFFF1F2),
          const Color(0xFFFECDD3),
        ),
      PillTone.info => (
          const Color(0xFF0284C7),
          const Color(0xFFF0F9FF),
          const Color(0xFFBAE6FD),
        ),
      PillTone.neutral => (
          const Color(0xFF64748B),
          const Color(0xFFF8FAFC),
          const Color(0xFFE2E8F0),
        ),
    };

    return Container(
      height: compact ? 22 : 26,
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.45,
                ),
          ),
        ],
      ),
    );
  }
}

/// Maps a firm/admin status string to a pill tone.
PillTone toneForStatus(String status) {
  return switch (status.toUpperCase()) {
    'ACTIVE' => PillTone.success,
    'SUSPENDED' => PillTone.danger,
    'PENDING' => PillTone.warning,
    _ => PillTone.neutral,
  };
}
