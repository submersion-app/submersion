import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Layout helpers for [TideChart], the site page's tide chart.

/// Room either side of the Now label, inside its pill.
const double tideChartNowPillPadding = 6;

/// How far a label drawn beside its line stands off it: past the radius of
/// the extreme's dot and its ring.
const double tideChartSideLabelGap = 9;

/// The left edge of a [width] wide pill centred on [centre], moved inward as
/// needed to stay within 0 to [maxWidth].
double tideChartPillLeft(double centre, double width, double maxWidth) {
  final maxLeft = maxWidth - width;
  if (maxLeft <= 0) return 0;
  return (centre - width / 2).clamp(0.0, maxLeft);
}

/// The width [text] lays out at in [style], at the ambient text scale.
double tideChartTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Whether [value] is one of the axis's own steps rather than the chart's
/// minimum or maximum, which fl_chart labels too even when they fall between
/// steps, printing them over their neighbours.
bool isOnAxisStep(double value, TitleMeta meta) {
  if (value != meta.min && value != meta.max) return true;
  final steps = value / meta.appliedInterval;
  return (steps - steps.round()).abs() < 1e-6;
}

/// The height gridline step for a tide [range] in metres.
double tideChartHeightInterval(double range) {
  if (range <= 0.5) return 0.1;
  if (range <= 1.0) return 0.2;
  if (range <= 2.0) return 0.5;
  if (range <= 5.0) return 1.0;
  return 2.0;
}

/// The time gridline step, in hours, for a window [maxHours] long.
double tideChartTimeInterval(double maxHours) {
  if (maxHours <= 6) return 1;
  if (maxHours <= 12) return 2;
  if (maxHours <= 24) return 4;
  if (maxHours <= 48) return 6;
  return 12;
}
