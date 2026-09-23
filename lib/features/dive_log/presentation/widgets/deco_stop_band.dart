import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/deco_stop_curve.dart';

/// Red 700, matching the ceiling line so the band and the curve read as one
/// decompression concept. Green was rejected because it already denotes NDL.
const Color decoStopBandColor = Color(0xFFD32F2F);

/// Opacity of the shaded region between the stop depth and the surface. Public
/// so the legend swatch can render the same translucent block the chart draws.
const double decoStopFillAlpha = 0.18;

/// Stroke width of the band's own step edge. Thin, matching the rest of the
/// profile chart's data lines, so the step reads as a line rather than a bar.
const double _decoStopStrokeWidth = 1.0;

/// Build the stepped deco stop band for the profile chart.
///
/// Draws its own thin step-line stroke along the upper edge, not just the
/// fill: a computer that reports raw stop depths but no separately computed
/// ceiling curve would otherwise show only a flat shaded region with no line
/// at all (issue #2228 follow-up).
///
/// The curve is piecewise constant, so it is compressed to its transitions
/// rather than run through the generic profile decimator, which could drop the
/// exact sample where a step occurs and slant the edge.
///
/// Depths are negated because the chart's Y axis is inverted, and the fill
/// runs up to `cutOffY: 0` (the surface). Samples with no obligation sit at 0,
/// so the band collapses to zero height on its own.
///
/// The shaded region is an `aboveBarData`, not a `belowBarData`. Negated depths
/// put the surface (y = 0) above the stop depth (y = -6), so the band occupies
/// the area above the bar. A below-bar fill cannot express this: fl_chart's
/// painter draws the below-bar area and then erases the entire above-line
/// region to clean up the cut-off overdraw, which wipes exactly the area the
/// band needs.
/// [fillColor] overrides [decoStopBandColor] for an overlaid source's own
/// band, so two computers' deco-stop obligations read as distinct washes
/// instead of stacking identically.
LineChartBarData buildDecoStopBand({
  required List<double> decoStopCurve,
  required List<int> timestamps,
  required UnitFormatter units,
  Color? fillColor,
}) {
  final length = decoStopCurve.length < timestamps.length
      ? decoStopCurve.length
      : timestamps.length;
  final curve = decoStopCurve.sublist(0, length);

  final spots = [
    for (final i in stepTransitionIndices(curve))
      FlSpot(timestamps[i].toDouble(), -units.convertDepth(curve[i])),
  ];

  return LineChartBarData(
    spots: spots,
    isCurved: false,
    isStepLineChart: true,
    // 0 holds each stop value forward from its sample until the next
    // transition, so the vertical edge lands where the level actually changes.
    lineChartStepData: const LineChartStepData(stepDirection: 0),
    color: fillColor ?? decoStopBandColor,
    barWidth: _decoStopStrokeWidth,
    isStrokeCapRound: false,
    dotData: const FlDotData(show: false),
    aboveBarData: BarAreaData(
      show: true,
      color: (fillColor ?? decoStopBandColor).withValues(
        alpha: decoStopFillAlpha,
      ),
      cutOffY: 0, // Fill from the stop depth up to the surface
      applyCutOffY: true,
    ),
  );
}
