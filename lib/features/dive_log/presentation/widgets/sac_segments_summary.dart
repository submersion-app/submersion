import 'package:flutter/material.dart';

/// One figure in a [SacSegmentsSummary].
class SacSummaryFigure {
  final String label;
  final String value;

  const SacSummaryFigure({required this.label, required this.value});
}

/// The whole-dive figures at the top of the Gas consumption by segment card,
/// such as the average rate, the peak and the gas used, each a small label
/// over its value. They wrap onto a second line where the card is narrow.
class SacSegmentsSummary extends StatelessWidget {
  final List<SacSummaryFigure> figures;

  const SacSegmentsSummary({super.key, required this.figures});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.titleSmall;
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        for (final figure in figures)
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(figure.label, style: labelStyle),
                Text(figure.value, style: valueStyle),
              ],
            ),
          ),
      ],
    );
  }
}
