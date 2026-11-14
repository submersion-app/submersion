import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/counterdiffusion_analysis.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart'
    show IcdSeverity;

/// Colour of an ICD band, also its legend swatch and tooltip bullet: a
/// warning orange, so it never reads as the error red of the O2 cell bands a
/// CCR dive on a trimix diluent can show beside it.
const Color counterdiffusionIcdColor = Colors.orange;

/// Fill of an opposing band: neutral, since that exchange is normal.
Color counterdiffusionOpposingColor(ColorScheme scheme) =>
    scheme.onSurfaceVariant;

/// Colour of a rule-of-fifths marker, matching the ICD calculator: orange for
/// a caution, the error colour for a violation.
Color icdSwitchMarkerColor(IcdSeverity severity, ColorScheme scheme) =>
    severity == IcdSeverity.violation ? scheme.error : Colors.orange;

/// Bands for [analysis] inside the visible window: the opposing spans first
/// when [showAll], then the ICD spans on top (issue #4530).
List<VerticalRangeAnnotation> counterdiffusionBands(
  CounterdiffusionAnalysis? analysis, {
  required bool showAll,
  required ColorScheme scheme,
  required double visibleMinX,
  required double visibleMaxX,
}) {
  if (analysis == null) return const [];
  VerticalRangeAnnotation? band(CounterdiffusionRange range, Color color) {
    final span = visibleHighlightSpan(
      ProfileHighlightRange(
        startTimestamp: range.startSeconds,
        endTimestamp: range.endSeconds,
        color: color,
      ),
      visibleMinX: visibleMinX,
      visibleMaxX: visibleMaxX,
    );
    if (span == null || span.x1 == span.x2) return null;
    return VerticalRangeAnnotation(x1: span.x1, x2: span.x2, color: color);
  }

  final opposingFill = counterdiffusionOpposingColor(
    scheme,
  ).withValues(alpha: 0.08);
  final icdFill = counterdiffusionIcdColor.withValues(alpha: 0.18);
  return [
    if (showAll)
      for (final range in analysis.opposingRanges) ?band(range, opposingFill),
    for (final range in analysis.icdRanges) ?band(range, icdFill),
  ];
}

/// Dashed vertical lines at the rule-of-fifths switches inside the visible
/// window. fl_chart asserts on lines outside it, so those are left out.
List<VerticalLine> icdSwitchMarkerLines(
  CounterdiffusionAnalysis? analysis, {
  required ColorScheme scheme,
  required double visibleMinX,
  required double visibleMaxX,
}) {
  if (analysis == null) return const [];
  return [
    for (final marker in analysis.switchMarkers)
      if (marker.timestamp >= visibleMinX && marker.timestamp <= visibleMaxX)
        VerticalLine(
          x: marker.timestamp.toDouble(),
          color: icdSwitchMarkerColor(marker.severity, scheme),
          strokeWidth: 2,
          dashArray: [6, 3],
        ),
  ];
}

/// The span of [kind] under [timestamp], or null.
CounterdiffusionRange? counterdiffusionRangeAt(
  CounterdiffusionAnalysis? analysis,
  int timestamp, {
  required bool showAll,
}) {
  if (analysis == null) return null;
  for (final range in analysis.icdRanges) {
    if (range.contains(timestamp)) return range;
  }
  if (!showAll) return null;
  for (final range in analysis.opposingRanges) {
    if (range.contains(timestamp)) return range;
  }
  return null;
}

/// Compartment numbers as compact runs, e.g. `[3, 4, 5, 7]` as "3-5, 7".
String formatCompartmentRuns(List<int> numbers) {
  if (numbers.isEmpty) return '';
  final sorted = [...numbers]..sort();
  final parts = <String>[];
  var start = sorted.first;
  var previous = start;
  for (final n in sorted.skip(1)) {
    if (n == previous + 1) {
      previous = n;
      continue;
    }
    parts.add(start == previous ? '$start' : '$start-$previous');
    start = n;
    previous = n;
  }
  parts.add(start == previous ? '$start' : '$start-$previous');
  return parts.join(', ');
}
