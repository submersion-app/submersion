import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_tick_format.dart';

/// The ascent rate a right-axis tick at [axisValue] stands for (issue #5069).
///
/// The ascent-rate bars ([AscentRateBarOverlay]) are drawn from a baseline at
/// the vertical middle of the plot, out to [maxAbsRate] at the top and bottom
/// edges, whatever depth window the chart shows. So the axis labelling them
/// reads the tick's place in the plot, not its depth: [axisMin] is the
/// bottom edge's axis value and [axisMax] the top's. A plot with no height
/// reads 0.
double ascentRateAtAxisValue(
  double axisValue, {
  required double axisMin,
  required double axisMax,
  required double maxAbsRate,
}) {
  final span = axisMax - axisMin;
  if (span == 0) return 0;
  return maxAbsRate * (2 * (axisValue - axisMin) / span - 1);
}

/// The ascent-rate right axis's labels (issue #5069): the bars' saturation
/// rate [maxAbsRate] (m/min) at the top edge, half of it at the quarter line,
/// 0 at the middle, and the descents below, each with its plot [fraction]
/// from the top. Fixed fractions keep the labels on the bars' own lines at
/// any zoom. A label below 10 in the diver's unit carries one decimal when it
/// is not whole, so a quarter of 15 m/min reads +7.5, not +8.
List<({double fraction, String label})> ascentRateAxisLabels(
  double maxAbsRate,
  UnitFormatter units,
) => [
  for (final (fraction, share) in const [
    (0.0, 1.0),
    (0.25, 0.5),
    (0.5, 0.0),
    (0.75, -0.5),
    (1.0, -1.0),
  ])
    (
      fraction: fraction,
      label: formatRightAxisTick(
        ProfileRightAxisMetric.ascentRate,
        maxAbsRate * share,
        units,
        minDecimals: _needsDecimal(units.convertDepth(maxAbsRate * share))
            ? 1
            : 0,
      ),
    ),
];

/// One decimal only where it matters and fits: a value below 10 that is not
/// whole (7.5). Above 10 the decimal changes little, and a label like -49.2
/// would not fit the right axis gutter at phone width.
bool _needsDecimal(double value) =>
    value.abs() < 10 && (value - value.roundToDouble()).abs() >= 0.05;
