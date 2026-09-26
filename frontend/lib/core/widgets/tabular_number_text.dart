import 'package:flutter/material.dart';

/// DESIGN.md requires `font-variant-numeric: tabular-nums` on every
/// numerical readout so columns of numbers align vertically. Use this
/// instead of a bare Text() anywhere a monetary value, headcount, or
/// percentage is rendered in a table or stat card.
class TabularNumberText extends StatelessWidget {
  const TabularNumberText(this.value, {super.key, this.style, this.textAlign});

  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return Text(
      value,
      textAlign: textAlign,
      style: baseStyle.copyWith(
        fontFeatures: [const FontFeature.tabularFigures()],
      ),
    );
  }
}
