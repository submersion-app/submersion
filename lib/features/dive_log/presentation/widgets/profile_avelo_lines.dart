import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_buoyancy_line.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_line_builders.dart';

/// The three lines for the values Shearwater's Avelo mode logs (issue
/// #4664), in the order the legend and the chart draw them.
const aveloLineMetrics = [
  ProfileRightAxisMetric.aveloBuoyancy,
  ProfileRightAxisMetric.aveloGasRemaining,
  ProfileRightAxisMetric.computerRmv,
];

/// [metric]'s value on each sample of [profile], null where the computer
/// logged none: kilograms for buoyancy, percent for gas remaining, litres
/// per minute for RMV. [metric] is one of [aveloLineMetrics].
List<double?> aveloCurve(
  ProfileRightAxisMetric metric,
  List<DiveProfilePoint> profile,
) => [
  for (final p in profile)
    switch (metric) {
      ProfileRightAxisMetric.aveloBuoyancy => p.aveloBuoyancy,
      ProfileRightAxisMetric.aveloGasRemaining =>
        p.aveloGasRemaining?.toDouble(),
      ProfileRightAxisMetric.computerRmv => p.computerRmv,
      _ => throw ArgumentError.value(metric, 'metric', 'not an Avelo line'),
    },
];

/// The range [metric]'s line and right axis are drawn over, or null when
/// [profile] has nothing to draw: gas remaining 0 to 100 percent, RMV from 0
/// to a fifth above its peak, buoyancy spanning neutral like the modelled
/// buoyancy line.
({double min, double max})? aveloLineRange(
  ProfileRightAxisMetric metric,
  List<DiveProfilePoint> profile,
) => aveloCurveRange(metric, aveloCurve(metric, profile));

/// [aveloLineRange] for a [curve] already read by [aveloCurve], so a caller
/// that draws the line too reads the samples once.
({double min, double max})? aveloCurveRange(
  ProfileRightAxisMetric metric,
  List<double?> curve,
) {
  if (!curve.any((v) => v != null)) return null;
  return switch (metric) {
    ProfileRightAxisMetric.aveloBuoyancy => buoyancyAxisRange(curve),
    ProfileRightAxisMetric.aveloGasRemaining => (min: 0.0, max: 100.0),
    _ => (min: 0.0, max: [for (final v in curve) ?v].reduce(math.max) * 1.2),
  };
}

/// One Avelo line: [curve] on [band] over [range], at each sample's time in
/// [profile]. [indices] are the samples to draw, in order (the chart's
/// decimation of [curve]); without them every sample with a value is drawn.
/// Where the computer logged nothing between two drawn samples the line
/// breaks rather than bridging or dropping to zero, as the computer's GTR
/// line does; a value left out by decimation is no break.
LineChartBarData buildAveloLine({
  required Color color,
  required MetricBand band,
  required List<double?> curve,
  required ({double min, double max}) range,
  required List<DiveProfilePoint> profile,
  Iterable<int>? indices,
}) {
  final length = math.min(curve.length, profile.length);
  final drawn =
      indices ??
      [
        for (var i = 0; i < length; i++)
          if (curve[i] != null) i,
      ];
  final spots = <FlSpot>[];
  var previous = -1;
  for (final i in drawn) {
    final v = i < length ? curve[i] : null;
    if (v == null) continue;
    if (previous >= 0 && gtrGapBetween(curve, previous, i)) {
      spots.add(FlSpot.nullSpot);
    }
    final y = band.map(v.clamp(range.min, range.max), range.min, range.max);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -y));
    previous = i;
  }
  return LineChartBarData(
    spots: spots,
    // Straight segments: the computer's values step (a pump-in, a purge),
    // and a curve would overshoot each step with a reading it never logged.
    isCurved: false,
    color: color,
    barWidth: 1.5,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
  );
}
