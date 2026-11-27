import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ascent_rate_axis_scale.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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

  // The five labels sit at fixed plot fractions, so they stay on the bars'
  // baseline and quarter lines at any zoom, and carry a decimal exactly when
  // a value is not whole: 7.5 reads +7.5, not +8.
  group('ascentRateAxisLabels', () {
    test('the floor span reads in whole and half metres per minute', () {
      expect(ascentRateAxisLabels(15, const UnitFormatter(AppSettings())), [
        (fraction: 0.0, label: '+15'),
        (fraction: 0.25, label: '+7.5'),
        (fraction: 0.5, label: '0'),
        (fraction: 0.75, label: '-7.5'),
        (fraction: 1.0, label: '-15'),
      ]);
    });

    test('a whole quarter needs no decimal', () {
      expect(
        ascentRateAxisLabels(
          20,
          const UnitFormatter(AppSettings()),
        ).map((l) => l.label),
        ['+20', '+10', '0', '-10', '-20'],
      );
    });

    // Above 10 a decimal changes little and would not fit the axis gutter
    // at phone width.
    test('feet per minute for an imperial diver, whole above 10', () {
      expect(
        ascentRateAxisLabels(
          15,
          const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
        ).map((l) => l.label),
        ['+49', '+25', '0', '-25', '-49'],
      );
    });
  });
}
