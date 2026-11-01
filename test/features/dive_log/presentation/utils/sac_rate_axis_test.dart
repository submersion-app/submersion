import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_axis.dart';

void main() {
  group('SacRateAxis.forPeak', () {
    const peaks = <double>[0.13, 0.9, 1, 3.1, 7, 9.99, 18, 45, 120, 1500];

    test('rounds up to whole steps that read easily', () {
      expect(SacRateAxis.forPeak(20).ticks, [0, 10, 20]);
      expect(SacRateAxis.forPeak(22).ticks, [0, 10, 20, 30]);
      expect(SacRateAxis.forPeak(15).ticks, [0, 5, 10, 15]);
      expect(SacRateAxis.forPeak(2).ticks, [0, 1, 2]);
    });

    test('scales to psi/min, which runs in the tens', () {
      final axis = SacRateAxis.forPeak(29.3);

      expect(axis.ticks, [0, 10, 20, 30]);
      expect(axis.decimals, 0);
    });

    test('keeps the decimals a small unit needs', () {
      final axis = SacRateAxis.forPeak(0.59);

      expect(axis.top, closeTo(0.6, 1e-9));
      expect(axis.decimals, 1);
    });

    test('keeps the second decimal of a quarter step', () {
      final axis = SacRateAxis.forPeak(0.7);

      expect(axis.ticks, [0, 0.25, 0.5, 0.75]);
      expect(axis.decimals, 2);
    });

    test('never puts the peak above the top line', () {
      for (final peak in peaks) {
        expect(SacRateAxis.forPeak(peak).top, greaterThanOrEqualTo(peak));
      }
    });

    test('stays at three intervals or fewer', () {
      for (final peak in peaks) {
        expect(SacRateAxis.forPeak(peak).ticks.length, lessThanOrEqualTo(4));
      }
    });

    test('a peak already on a line gets no empty band above it', () {
      expect(SacRateAxis.forPeak(30).top, 30);
    });

    test('has nothing to label with no consumption', () {
      expect(SacRateAxis.forPeak(0).ticks, isEmpty);
      expect(SacRateAxis.forPeak(0).top, 0);
      expect(SacRateAxis.forPeak(double.nan).ticks, isEmpty);
    });
  });
}
