import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'tabular_number_text.dart';

/// "Wrapped in 12px radius white cards... micro-label title, main metric
/// in metric-xl, and an inline delta pill" — DESIGN.md § Stat Cards & Metric
/// Tiles. Used for the Multi-Academy Executive Overview and every other
/// KPI row across the app.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.deltaLabel,
    this.deltaIsPositive = true,
    this.icon,
  });

  final String label;
  final String value;
  final String? deltaLabel;
  final bool deltaIsPositive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, size: 18, color: colors.textSubtle),
            ],
          ),
          const SizedBox(height: 8),
          TabularNumberText(value, style: textTheme.headlineLarge),
          if (deltaLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deltaIsPositive ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: deltaIsPositive ? colors.success : colors.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  deltaLabel!,
                  style: textTheme.bodySmall?.copyWith(
                    color: deltaIsPositive ? colors.success : colors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
