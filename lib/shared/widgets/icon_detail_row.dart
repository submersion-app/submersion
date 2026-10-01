import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A detail-page row: a leading icon, a label, and a bold value at the
/// trailing edge, read by screen readers as one "label: value" node.
///
/// The value wraps instead of squeezing the label (issue #2695): the label
/// keeps its natural width whenever it fits beside the value. When the two
/// cannot share one line, the label wraps too, but it never takes more than
/// 40% of the text width, so a long localized label (the Spanish "Also
/// Recognized" is 23 characters) cannot squeeze the value in turn or
/// overflow the row at a large text size.
class IconDetailRow extends StatelessWidget {
  const IconDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Tints the value, e.g. an expiry date that has passed.
  final Color? valueColor;

  static const double _iconSize = 20;
  static const double _iconGap = 12;
  static const double _valueGap = 16;

  /// The share of the text width a label may take when it and the value
  /// both need more than one line.
  static const double _crowdedLabelShare = 0.4;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final labelStyle = base.merge(Theme.of(context).textTheme.bodyMedium);
    final valueStyle = labelStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: valueColor,
    );

    // Neither measurement depends on the row's width, so both are taken once
    // per build rather than on every layout pass.
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    TextPainter measure(String text, TextStyle style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final valuePainter = measure(value, valueStyle);
    final labelPainter = measure(label, labelStyle);
    final valueWidth = valuePainter.width;
    final lineHeight = labelPainter.preferredLineHeight;
    valuePainter.dispose();
    labelPainter.dispose();

    // The first line is as tall as the taller of the icon and a line of text;
    // whichever is shorter is centred on it, at any text size.
    final firstLine = math.max(lineHeight, _iconSize);
    final textTop = (firstLine - lineHeight) / 2;

    // The row reads as one "label: value" node; the texts are not read again.
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textWidth = constraints.maxWidth - _iconSize - _iconGap;
            // Never negative: a row narrower than its icon (a pane animating
            // open) still has to build valid constraints.
            final labelMaxWidth = math.max(
              0.0,
              math.max(
                textWidth - _valueGap - valueWidth,
                textWidth * _crowdedLabelShare,
              ),
            );

            // Top-aligned so a wrapped label or value keeps the others on its
            // first line.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: firstLine,
                  child: Center(
                    child: Icon(
                      icon,
                      size: _iconSize,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: _iconGap),
                Padding(
                  padding: EdgeInsets.only(top: textTop),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: labelMaxWidth),
                    child: Text(label, style: labelStyle),
                  ),
                ),
                const SizedBox(width: _valueGap),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: textTop),
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: valueStyle,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
