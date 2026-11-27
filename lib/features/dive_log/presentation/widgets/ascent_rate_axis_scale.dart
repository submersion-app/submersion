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
