import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ascent_rate_axis_scale.dart';

/// The ascent-rate right axis (issue #5069) reads the bars' own scale: zero
/// at mid-plot, the saturation rate at the top and bottom edges, whatever
/// depth the axis is showing.
void main() {
  double at(double value) =>
      ascentRateAtAxisValue(value, axisMin: -30, axisMax: 0, maxAbsRate: 12);

  test('top is +max, middle 0, bottom -max', () {
    expect(at(0), closeTo(12, 1e-9));
    expect(at(-15), closeTo(0, 1e-9));
    expect(at(-30), closeTo(-12, 1e-9));
  });

  test('is linear between the edges', () {
    expect(at(-7.5), closeTo(6, 1e-9));
    expect(at(-22.5), closeTo(-6, 1e-9));
  });

  test('reads the plot, not the depth, when the axis is a zoomed slice', () {
    expect(
      ascentRateAtAxisValue(-8, axisMin: -12, axisMax: -4, maxAbsRate: 12),
      closeTo(0, 1e-9),
    );
  });

  test('a zero-height axis returns 0', () {
    expect(
      ascentRateAtAxisValue(-5, axisMin: -5, axisMax: -5, maxAbsRate: 12),
      0,
    );
  });
}
