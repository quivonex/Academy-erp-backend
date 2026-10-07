// lib/core/widgets/back_button.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A premium-styled back button that matches the "Luminous Enterprise" design.
/// Automatically pops if possible, otherwise navigates to the fallback route.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.fallbackRoute = '/student/courses',
    this.color = const Color(0xFF1E293B),
    this.iconSize = 26,
    this.tooltip = 'Go back',
  });

  /// Route to navigate to if there's nothing to pop.
  final String fallbackRoute;

  /// Icon color.
  final Color color;

  /// Icon size.
  final double iconSize;

  /// Tooltip message.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.arrow_back_rounded,
        color: color,
        size: iconSize,
      ),
      tooltip: tooltip,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackRoute);
        }
      },
    );
  }
}