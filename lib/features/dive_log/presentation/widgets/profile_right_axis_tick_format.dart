import 'dart:math' as math;

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// The most decimals a right-axis tick label is ever given.
const _maxTickDecimals = 3;

/// Formats a right-axis tick of the dive profile chart as a plain number
/// (the unit is shown in the axis name).
///
/// [value] is in the units `_getMetricRange` produces: storage units (bar,
/// metres, seconds ...) for every metric except temperature, which arrives
/// already converted to the diver's unit.
///
/// [tickStep] is the distance between adjacent ticks in those same units.
/// The right-axis ticks sit on the depth grid, so a narrow metric range is
/// cut into steps finer than the metric's usual precision; rounding them all
/// to it repeated one label down the axis (issue #3055: a 3 degree
/// temperature range read 31, 31, 31, 30, 30 ...). Each label therefore
/// carries enough decimals to tell it from its neighbour, and never fewer
/// than the metric's own precision. Without a usable step, the metric's own
/// precision applies.
String formatRightAxisTick(
  ProfileRightAxisMetric metric,
  double value,
  UnitFormatter units, {
  double? tickStep,
}) {
  final display = _displayValue(metric, value, units);
  var decimals = _baseDecimals(metric);
  if (tickStep != null && tickStep.isFinite && tickStep != 0) {
    final displayStep =
        (_displayValue(metric, value + tickStep, units) - display).abs();
    decimals = math.max(decimals, _decimalsToSeparate(displayStep));
  }
  // A tick on the zero line can unmap to -1e-13, which would print "-0".
  final rounded = double.parse(display.toStringAsFixed(decimals));
  return formatFixedForDisplay(rounded == 0 ? 0 : display, decimals);
}

/// Fewest decimals at which two values [step] apart round to different
/// labels: rounding to 10^-d can only merge values closer than 10^-d.
int _decimalsToSeparate(double step) {
  if (!step.isFinite || step <= 0) return 0;
  final decimals = (-math.log(step) / math.ln10 - 1e-9).ceil();
  return decimals.clamp(0, _maxTickDecimals);
}

double _displayValue(
  ProfileRightAxisMetric metric,
  double value,
  UnitFormatter units,
) => switch (metric) {
  // Already in the diver's unit (converted in _getMetricRange).
  ProfileRightAxisMetric.temperature => value,
  // SAC is bar/min, so only its pressure component converts.
  ProfileRightAxisMetric.pressure ||
  ProfileRightAxisMetric.sac => units.convertPressure(value),
  ProfileRightAxisMetric.ascentRate ||
  ProfileRightAxisMetric.meanDepth => units.convertDepth(value),
  // Stored in seconds, labelled in minutes.
  ProfileRightAxisMetric.ndl ||
  ProfileRightAxisMetric.tts ||
  ProfileRightAxisMetric.gtr => value / 60,
  ProfileRightAxisMetric.heartRate ||
  ProfileRightAxisMetric.gf ||
  ProfileRightAxisMetric.surfaceGf ||
  ProfileRightAxisMetric.ppO2 ||
  ProfileRightAxisMetric.ppN2 ||
  ProfileRightAxisMetric.ppHe ||
  ProfileRightAxisMetric.gasDensity ||
  ProfileRightAxisMetric.cns ||
  ProfileRightAxisMetric.otu ||
  ProfileRightAxisMetric.o2CellMv => value,
};

int _baseDecimals(ProfileRightAxisMetric metric) => switch (metric) {
  ProfileRightAxisMetric.sac ||
  ProfileRightAxisMetric.ppO2 ||
  ProfileRightAxisMetric.ppN2 ||
  ProfileRightAxisMetric.ppHe ||
  ProfileRightAxisMetric.gasDensity => 1,
  _ => 0,
};
