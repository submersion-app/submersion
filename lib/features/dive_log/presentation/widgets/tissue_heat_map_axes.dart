import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The axes around the Tissue Loading card's heat map (issue #4503): which
/// row is which compartment, and when in the dive each column falls.
///
/// The heat map's painter always runs time left to right and compartment 1 at
/// the top, whatever the text direction, so the card lays these out left to
/// right too. Both are left out of semantics: the card describes the heat map
/// to a screen reader in one label instead (see [tissueHeatMapSemantics]).

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

  /// The largest text scale the axis numbers follow.
  static const double maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    // Nothing to name: the strip paints no rows either.
    if (compartmentCount <= 0) return const SizedBox(width: width);
    final style = _axisStyle(context);
    final rows = {0, (compartmentCount + 1) ~/ 2 - 1, compartmentCount - 1}
      ..removeWhere((row) => row < 0);
    final ordered = rows.toList()..sort();
    // Three labels share a strip as short as 72 px, so their text grows only
    // so far with the diver's text size before they would overlap.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: ExcludeSemantics(
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${row + 1}', style: style, maxLines: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centres each label on its row and right-aligns it beside the strip. A
/// label is taller than a 72 px strip's rows, so each is kept inside the
/// axis: the first and last sit flush with the strip's edges rather than
/// standing past them into the legend above or the time axis below.
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
      final centred = (rows[i] + 0.5) * rowHeight - child.height / 2;
      context.paintChild(
        i,
        transform: Matrix4.translationValues(
          size.width - _gap - child.width,
          centred.clamp(0.0, math.max(0.0, size.height - child.height)),
          0,
        ),
      );
    }
  }

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(0.0, constraints.maxWidth - _gap));

  @override
  bool shouldRepaint(_RowLabelsDelegate oldDelegate) =>
      oldDelegate.compartmentCount != compartmentCount ||
      !listEquals(oldDelegate.rows, rows);
}

/// Dive time under a heat map whose columns are the samples in [timestamps]
/// (seconds on the profile chart's clock), at the start, middle and end of
/// the strip.
class TissueHeatMapTimeAxis extends StatelessWidget {
  const TissueHeatMapTimeAxis({super.key, required this.timestamps});

  final List<int> timestamps;

  /// Whether [timestamps] can label a heat map of [sampleCount] columns: one
  /// time per sample, and at least two of them. A mismatch happens while the
  /// dive details page still shows an earlier analysis of a changed profile,
  /// and a guessed timeline would mislabel it. Only the count is compared: a
  /// retained analysis with the same count but different times would pass,
  /// and no profile edit is known to produce one.
  /// [seconds] on the profile chart's clock as the axis reads it: whole
  /// minutes, part minutes dropped, and below zero for a computer that
  /// started logging before the dive's zero point.
  static String timeLabel(AppLocalizations l10n, int seconds) =>
      l10n.diveLog_deco_minutesValue('${seconds ~/ 60}');

  static bool fits(List<int>? timestamps, int sampleCount) =>
      timestamps != null &&
      sampleCount >= 2 &&
      timestamps.length == sampleCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = _axisStyle(context);
    String at(int index) => timeLabel(l10n, timestamps[index]);

    final start = at(0);
    final middle = at(timestamps.length ~/ 2);
    final end = at(timestamps.length - 1);
    // Each time is named once: a short timeline's middle or end can round to
    // the same minute as its neighbour, and a repeat reads as a stuck clock.
    final labels = [
      (Alignment.centerLeft, start),
      (Alignment.center, middle == start || middle == end ? null : middle),
      (Alignment.centerRight, end == start ? null : end),
    ];

    // Each label owns a third of the width and shrinks to fit it, so the
    // three never run into each other at large text.
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (alignment, text) in labels)
            Expanded(
              child: text == null
                  ? const SizedBox.shrink()
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: alignment,
                      child: Text(text, style: style, maxLines: 1),
                    ),
            ),
        ],
      ),
    );
  }
}

/// What the heat map shows, for a screen reader: its rows and, when [timestamps]
/// label it, the dive time it covers. The strip and both axes are left out of
/// semantics, so this label is the heat map's only description.
String tissueHeatMapSemantics(
  AppLocalizations l10n, {
  required int compartmentCount,
  List<int>? timestamps,
}) {
  final stamps = timestamps;
  if (stamps == null || stamps.length < 2) {
    return l10n.diveLog_deco_heatMapSemantics(1, compartmentCount);
  }
  return l10n.diveLog_deco_heatMapTimedSemantics(
    1,
    compartmentCount,
    TissueHeatMapTimeAxis.timeLabel(l10n, stamps.first),
    TissueHeatMapTimeAxis.timeLabel(l10n, stamps.last),
  );
}
