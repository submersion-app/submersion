import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The axes around the Tissue Loading card's heat map (issue #4503): which
/// row is which compartment, and when in the dive each column falls.
///
/// The heat map's painter always runs time left to right and compartment 1 at
/// the top, whatever the text direction, so the card lays these out left to
/// right too. Both are left out of semantics: the strip speaks for itself.

TextStyle? _axisStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.labelSmall?.copyWith(
    fontSize: 11,
    color: theme.colorScheme.onSurfaceVariant,
  );
}

/// Labels the first, middle and last compartment rows of a heat map that
/// paints [compartmentCount] equal rows, fast at the top. Fills its parent's
/// height, so it stays on its rows when the strip stretches.
class TissueHeatMapCompartmentAxis extends StatelessWidget {
  const TissueHeatMapCompartmentAxis({
    super.key,
    required this.compartmentCount,
  });

  final int compartmentCount;

  /// The axis's fixed width beside the strip.
  static const double width = 18;

  @override
  Widget build(BuildContext context) {
    final style = _axisStyle(context);
    final rows = {0, (compartmentCount + 1) ~/ 2 - 1, compartmentCount - 1}
      ..removeWhere((row) => row < 0);
    final ordered = rows.toList()..sort();
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        // A Flow places the labels at paint time from the height it is
        // given, and reports no intrinsic height of its own, so the card
        // still sizes inside the detail page's IntrinsicHeight pairs.
        child: Flow(
          delegate: _RowLabelsDelegate(
            rows: ordered,
            compartmentCount: compartmentCount,
          ),
          clipBehavior: Clip.none,
          children: [
            for (final row in ordered)
              Text('${row + 1}', style: style, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

/// Centres each label on its row and right-aligns it beside the strip. A
/// label is taller than a 72 px strip's rows, so the first and last stand a
/// few pixels past the strip's edges.
class _RowLabelsDelegate extends FlowDelegate {
  const _RowLabelsDelegate({
    required this.rows,
    required this.compartmentCount,
  });

  final List<int> rows;
  final int compartmentCount;

  static const double _gap = 3;

  @override
  void paintChildren(FlowPaintingContext context) {
    final size = context.size;
    final rowHeight = size.height / compartmentCount;
    for (var i = 0; i < context.childCount; i++) {
      final child = context.getChildSize(i)!;
      context.paintChild(
        i,
        transform: Matrix4.translationValues(
          size.width - _gap - child.width,
          (rows[i] + 0.5) * rowHeight - child.height / 2,
          0,
        ),
      );
    }
  }

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  bool shouldRepaint(_RowLabelsDelegate oldDelegate) =>
      oldDelegate.compartmentCount != compartmentCount ||
      !listEquals(oldDelegate.rows, rows);
}

/// Dive time under a heat map whose columns are the samples in [timestamps]
/// (seconds), at the start, middle and end of the strip.
class TissueHeatMapTimeAxis extends StatelessWidget {
  const TissueHeatMapTimeAxis({super.key, required this.timestamps});

  final List<int> timestamps;

  /// Whether [timestamps] can label a heat map of [sampleCount] columns: one
  /// time per sample, and at least two of them. A mismatch happens while the
  /// dive details page still shows an earlier analysis of a changed profile,
  /// and a guessed timeline would mislabel it.
  static bool fits(List<int>? timestamps, int sampleCount) =>
      timestamps != null &&
      sampleCount >= 2 &&
      timestamps.length == sampleCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = _axisStyle(context);
    String at(int index) {
      final minutes = ((timestamps[index] - timestamps.first) / 60).round();
      return l10n.diveLog_deco_minutesValue('$minutes');
    }

    return ExcludeSemantics(
      child: Stack(
        children: [
          for (final (alignment, index) in [
            (Alignment.centerLeft, 0),
            (Alignment.center, timestamps.length ~/ 2),
            (Alignment.centerRight, timestamps.length - 1),
          ])
            Align(
              alignment: alignment,
              child: Text(at(index), style: style, maxLines: 1),
            ),
        ],
      ),
    );
  }
}
