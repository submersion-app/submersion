import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/utils/weight_axis.dart';

void main() {
  group('within a span', () {
    test('marks round steps that stay inside the span', () {
      final axis = WeightAxis.within(12);
      expect(axis.ticks, [0, 5, 10]);
      expect(axis.top, 10);
      expect(axis.decimals, 0);
    });

    test('a span that lands on a mark keeps it', () {
      expect(WeightAxis.within(20).ticks, [0, 5, 10, 15, 20]);
    });

    test('fewer intervals give a coarser step', () {
      expect(WeightAxis.within(12, maxIntervals: 2).ticks, [0, 10]);
    });

    test('a small span uses a fractional step and says so', () {
      final axis = WeightAxis.within(1.2);
      expect(axis.ticks.last, closeTo(1.0, 1e-9));
      expect(axis.decimals, 1);
    });

    test('nothing to mark for an empty or broken span', () {
      expect(WeightAxis.within(0).ticks, isEmpty);
      expect(WeightAxis.within(double.nan).ticks, isEmpty);
      expect(WeightAxis.within(12, maxIntervals: 0).ticks, isEmpty);
    });
  });

  group('covering a peak', () {
    test('the top mark is at or over the peak', () {
      final axis = WeightAxis.covering(9);
      expect(axis.ticks, [0, 5, 10]);
      expect(axis.top, 10);
    });

    test('a peak on a mark does not add another', () {
      expect(WeightAxis.covering(10).ticks, [0, 5, 10]);
    });

    test('pounds get their own round steps', () {
      // 9 kg is 19.8 lb.
      expect(WeightAxis.covering(19.8).ticks, [0, 10, 20]);
    });

    test('nothing to mark for an empty peak', () {
      expect(WeightAxis.covering(0).ticks, isEmpty);
    });
  });
}
