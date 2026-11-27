import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:submersion/features/dive_log/presentation/providers/species_profile_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';

/// The selected species on the profile chart (issue #5092): a band for each
/// stretch it was in view on video, and a line with a dot on the depth line
/// for each moment (a typed time or a photo). Drawn like a selected safety
/// finding, in the species' category colour.

/// Bands for [highlight]'s spans inside the visible window.
List<VerticalRangeAnnotation> speciesHighlightBands(
  SpeciesProfileHighlight? highlight, {
  required double visibleMinX,
  required double visibleMaxX,
}) {
  if (highlight == null) return const [];
  return [
    for (final span in highlight.positions.spans)
      if (visibleHighlightSpan(
            ProfileHighlightRange(
              startTimestamp: span.start,
              endTimestamp: span.end,
              color: highlight.color,
            ),
            visibleMinX: visibleMinX,
            visibleMaxX: visibleMaxX,
          )
          case final visible?)
        VerticalRangeAnnotation(
          x1: visible.x1,
          x2: visible.x2,
          color: highlight.color.withValues(alpha: 0.12),
        ),
  ];
}

/// A thin line at each of [highlight]'s moments, and at the start of each
/// span, inside the visible window: the start edge is drawn as a finding's
/// window and the strip's band are, so a pale category colour still reads.
List<VerticalLine> speciesMomentLines(
  SpeciesProfileHighlight? highlight, {
  required double visibleMinX,
  required double visibleMaxX,
}) {
  if (highlight == null) return const [];
  final positions = highlight.positions;
  return [
    for (final x in [
      for (final m in positions.moments) m.seconds,
      for (final s in positions.spans) s.start,
    ])
      if (x >= visibleMinX && x <= visibleMaxX)
        VerticalLine(
          x: x.toDouble(),
          color: highlight.color.withValues(alpha: 0.7),
          strokeWidth: 1,
        ),
  ];
}

/// A zero-width bar that draws a ringed dot at each of [highlight]'s
/// moments, at [y] of its depth (the chart's negated display depth), or
/// null when there is none. The chart windows its bars, so moments outside
/// the view drop out there.
LineChartBarData? speciesMomentDots(
  SpeciesProfileHighlight? highlight, {
  required double Function(double meters) y,
  required Color ring,
}) {
  final moments = highlight?.positions.moments ?? const [];
  if (highlight == null || moments.isEmpty) return null;
  return LineChartBarData(
    spots: [
      for (final m in moments) FlSpot(m.seconds.toDouble(), y(m.depthMeters)),
    ],
    isCurved: false,
    color: Colors.transparent,
    barWidth: 0,
    dotData: FlDotData(
      show: true,
      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
        radius: 5,
        color: highlight.color,
        strokeWidth: 2,
        strokeColor: ring,
      ),
    ),
  );
}
