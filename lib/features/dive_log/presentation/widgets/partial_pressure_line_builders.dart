import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_line_builders.dart'
    show
        DecimatedCurveIndices,
        SeriesGetsLeadIn,
        SurfaceValueOf,
        WithSurfaceLeadIn;

/// Build ppO2 (partial pressure of oxygen) line
/// Values typically range from 0.21 (surface air) to 1.6+ (critical)
/// Shared shape behind [buildPpO2Line], [buildPpN2Line] and [buildPpHeLine]:
/// a partial-pressure curve is drawn the same way regardless of gas --
/// mapped through [band] between 0 (a partial pressure is never negative)
/// and [maxScale], with a computed (not flat) surface lead-in, since a
/// partial pressure at 1 bar is simply that gas's fraction. [filterAtOrBelow]
/// drops samples at or below it (ppHe is 0 for the entire dive on a
/// non-trimix profile, and drawing a flat zero line for that is worse than
/// drawing nothing).
LineChartBarData _buildPartialPressureLine({
  required MetricBand band,
  required List<double> curve,
  required double maxScale,
  required Color color,
  required List<DiveProfilePoint> profile,
  required DecimatedCurveIndices decimatedCurveIndices,
  required WithSurfaceLeadIn withSurfaceLeadIn,
  required SurfaceValueOf surfaceValueOf,
  required SeriesGetsLeadIn seriesGetsLeadIn,
  double? filterAtOrBelow,
}) {
  const min = 0.0;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(curve)) {
    final value = curve[i];
    if (filterAtOrBelow != null && value <= filterAtOrBelow) continue;
    final clamped = value.clamp(min, maxScale);
    final yValue = band.map(clamped, min, maxScale);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    spots: withSurfaceLeadIn(
      spots,
      -band.map(
        surfaceValueOf(curve.first).clamp(min, maxScale),
        min,
        maxScale,
      ),
    ),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: color,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

LineChartBarData buildPpO2Line(
  MetricBand band,
  List<double> ppO2Curve,
  double ppO2MaxScale,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithSurfaceLeadIn withSurfaceLeadIn,
  SurfaceValueOf surfaceValueOf,
  SeriesGetsLeadIn seriesGetsLeadIn,
) => _buildPartialPressureLine(
  band: band,
  curve: ppO2Curve,
  maxScale: ppO2MaxScale,
  color: ProfileMetricColors.ppO2,
  profile: profile,
  decimatedCurveIndices: decimatedCurveIndices,
  withSurfaceLeadIn: withSurfaceLeadIn,
  surfaceValueOf: surfaceValueOf,
  seriesGetsLeadIn: seriesGetsLeadIn,
);

/// Build ppN2 (partial pressure of nitrogen) line
LineChartBarData buildPpN2Line(
  MetricBand band,
  List<double> ppN2Curve,
  double ppN2MaxScale,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithSurfaceLeadIn withSurfaceLeadIn,
  SurfaceValueOf surfaceValueOf,
  SeriesGetsLeadIn seriesGetsLeadIn,
) => _buildPartialPressureLine(
  band: band,
  curve: ppN2Curve,
  maxScale: ppN2MaxScale,
  color: ProfileMetricColors.ppN2,
  profile: profile,
  decimatedCurveIndices: decimatedCurveIndices,
  withSurfaceLeadIn: withSurfaceLeadIn,
  surfaceValueOf: surfaceValueOf,
  seriesGetsLeadIn: seriesGetsLeadIn,
);

/// Build ppHe (partial pressure of helium) line for trimix dives. The
/// filterAtOrBelow 0.001 means a non-trimix dive (ppHe ~0 throughout) draws
/// nothing at all, and the lead-in is skipped with it.
LineChartBarData buildPpHeLine(
  MetricBand band,
  List<double> ppHeCurve,
  double ppHeMaxScale,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithSurfaceLeadIn withSurfaceLeadIn,
  SurfaceValueOf surfaceValueOf,
  SeriesGetsLeadIn seriesGetsLeadIn,
) => _buildPartialPressureLine(
  band: band,
  curve: ppHeCurve,
  maxScale: ppHeMaxScale,
  color: ProfileMetricColors.ppHe,
  profile: profile,
  decimatedCurveIndices: decimatedCurveIndices,
  withSurfaceLeadIn: withSurfaceLeadIn,
  surfaceValueOf: surfaceValueOf,
  seriesGetsLeadIn: seriesGetsLeadIn,
  filterAtOrBelow: 0.001,
);
