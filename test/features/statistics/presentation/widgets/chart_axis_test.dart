import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/presentation/widgets/chart_axis.dart';

// Issue #219: the statistics trend charts drew grid lines on one interval and
// labelled the left axis on another, so the tick lines sat between the values.
// ChartAxis is the single source of truth both sides now read from.

/// True when [value] sits on a tick of [interval] measured from zero, which is
/// the baseline fl_chart anchors both grid lines and side titles to.
bool _isOnTick(double value, double interval) {
  final steps = value / interval;
  return (steps - steps.roundToDouble()).abs() < 1e-9;
}

void main() {
  group('ChartAxis.forTrend', () {
    test('bounds land on whole interval steps', () {
      final axis = ChartAxis.forTrend(const [12.4, 15.1, 13.8, 18.2, 16.0]);

      expect(axis.interval, greaterThan(0));
      expect(_isOnTick(axis.min, axis.interval), isTrue);
      expect(_isOnTick(axis.max, axis.interval), isTrue);
    });

    test('keeps every data point inside the axis', () {
      const values = [12.4, 15.1, 13.8, 18.2, 16.0];
      final axis = ChartAxis.forTrend(values);

      expect(
        axis.min,
        lessThanOrEqualTo(values.reduce((a, b) => a < b ? a : b)),
      );
      expect(
        axis.max,
        greaterThanOrEqualTo(values.reduce((a, b) => a > b ? a : b)),
      );
    });

    test('picks a human-readable step rather than range/4', () {
      // Range 6.0 over four ticks is 1.5 exactly; 2.0 reads better.
      final axis = ChartAxis.forTrend(const [10.0, 16.0]);
      expect(axis.interval, 2.0);
      expect(axis.min, 8.0);
      expect(axis.max, 18.0);
    });

    test('never drops below zero for all-positive data', () {
      final axis = ChartAxis.forTrend(const [0.4, 0.9, 1.2]);
      expect(axis.min, greaterThanOrEqualTo(0.0));
    });

    test('allows negative bounds when the data goes negative', () {
      final axis = ChartAxis.forTrend(const [-4.0, 6.0]);
      expect(axis.min, lessThan(0));
      expect(_isOnTick(axis.min, axis.interval), isTrue);
    });

    test('gives a flat series a usable range around the value', () {
      final axis = ChartAxis.forTrend(const [15.0, 15.0, 15.0]);

      expect(axis.max, greaterThan(axis.min));
      expect(axis.min, lessThanOrEqualTo(15.0));
      expect(axis.max, greaterThanOrEqualTo(15.0));
      expect(_isOnTick(axis.interval, axis.interval), isTrue);
    });

    test('gives an all-zero series a usable range', () {
      final axis = ChartAxis.forTrend(const [0.0, 0.0]);

      expect(axis.min, 0.0);
      expect(axis.max, greaterThan(0.0));
      expect(axis.interval, greaterThan(0));
    });

    test('stays drawable when handed no values at all', () {
      final axis = ChartAxis.forTrend(const []);

      expect(axis.max, greaterThan(axis.min));
      expect(axis.interval, greaterThan(0));
      expect(_isOnTick(axis.min, axis.interval), isTrue);
      expect(_isOnTick(axis.max, axis.interval), isTrue);
    });

    test('handles sub-unit SAC pressure values without collapsing', () {
      // bar/min SAC lives well under 1; the interval must scale down with it.
      final axis = ChartAxis.forTrend(const [0.52, 0.61, 0.58, 0.74]);

      expect(axis.interval, lessThan(0.5));
      expect(axis.max, greaterThanOrEqualTo(0.74));
      expect(_isOnTick(axis.max, axis.interval), isTrue);
    });
  });

  group('ChartAxis.forCounts', () {
    test('anchors at zero and steps in whole dives', () {
      final axis = ChartAxis.forCounts(10);

      expect(axis.min, 0.0);
      expect(axis.interval, axis.interval.roundToDouble());
      expect(axis.interval, greaterThanOrEqualTo(1));
      expect(axis.max, greaterThanOrEqualTo(10));
      expect(_isOnTick(axis.max, axis.interval), isTrue);
    });

    test('never produces a fractional step for small counts', () {
      for (var maxCount = 1; maxCount <= 12; maxCount++) {
        final axis = ChartAxis.forCounts(maxCount.toDouble());
        expect(
          axis.interval,
          axis.interval.roundToDouble(),
          reason: 'maxCount $maxCount produced a fractional interval',
        );
        expect(axis.max, greaterThanOrEqualTo(maxCount.toDouble()));
      }
    });

    test('stays valid for an empty chart', () {
      final axis = ChartAxis.forCounts(0);

      expect(axis.min, 0.0);
      expect(axis.max, greaterThan(0.0));
      expect(axis.interval, greaterThan(0));
    });
  });
}
