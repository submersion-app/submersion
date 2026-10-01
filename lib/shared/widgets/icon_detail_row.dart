import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A detail-page row: a leading icon, a label, and a bold value at the
/// trailing edge, read by screen readers as one "label: value" node.
///
/// The value wraps instead of squeezing the label (issue #2695): the label
/// keeps its natural width whenever it fits beside the value. When the two
/// cannot share one line, the label wraps too, but it never takes more than
/// [_crowdedLabelShare] of the text width, so a long localized label (the
/// Spanish "Also Recognized" is 23 characters) cannot squeeze the value in
/// turn or overflow the row at a large text size.
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
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    TextPainter measure(String text, TextStyle style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();

    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final valuePainter = measure(value, valueStyle);
            final labelPainter = measure(label, labelStyle);
            final valueWidth = valuePainter.width;
            final lineHeight = labelPainter.preferredLineHeight;
            valuePainter.dispose();
            labelPainter.dispose();

            final textWidth = constraints.maxWidth - _iconSize - _iconGap;
            final labelMaxWidth = math.max(
              textWidth - _valueGap - valueWidth,
              textWidth * _crowdedLabelShare,
            );

            // Top-aligned so a wrapped label or value keeps the others on its
            // first line; the icon is centred on that first line.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    height: math.max(lineHeight, _iconSize),
                    child: Center(
                      child: Icon(
                        icon,
                        size: _iconSize,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: _iconGap),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelMaxWidth),
                  child: Text(label, style: labelStyle),
                ),
                const SizedBox(width: _valueGap),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: valueStyle,
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
