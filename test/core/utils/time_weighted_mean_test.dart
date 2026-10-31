import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/time_weighted_mean.dart';

typedef _Sample = ({int t, double depth});

double? _mean(List<_Sample> samples) =>
    timeWeightedMean(samples, time: (s) => s.t, value: (s) => s.depth);

void main() {
  group('timeWeightedMean', () {
    test('weights a piecewise linear profile by elapsed time (#3891)', () {
      // 60 s at 10 m, a 60 s ramp averaging 20 m, 480 s at 30 m. A sample
      // average gives 20 m; (600 + 1200 + 14400) / 600 is 27 m.
      expect(
        _mean([
          (t: 0, depth: 10),
          (t: 60, depth: 10),
          (t: 120, depth: 30),
          (t: 600, depth: 30),
        ]),
        closeTo(27, 1e-9),
      );
    });

    test('is unchanged by another sample on an existing segment (#3891)', () {
      final sparse = _mean([
        (t: 0, depth: 10),
        (t: 60, depth: 10),
        (t: 120, depth: 30),
        (t: 600, depth: 30),
      ]);
      final dense = _mean([
        (t: 0, depth: 10),
        (t: 30, depth: 10),
        (t: 60, depth: 10),
        (t: 90, depth: 20),
        (t: 120, depth: 30),
        (t: 600, depth: 30),
      ]);

      expect(dense, closeTo(sparse!, 1e-9));
    });

    test('the value after each sample is the mean up to that sample', () {
      final mean = TimeWeightedMean();

      expect(mean.value, isNull);
      mean.add(0, 10);
      expect(mean.value, 10);
      mean.add(60, 10);
      expect(mean.value, closeTo(10, 1e-9));
      mean.add(120, 30);
      expect(mean.value, closeTo(15, 1e-9));
      mean.add(600, 30);
      expect(mean.value, closeTo(27, 1e-9));
    });

    test('has no value for no samples', () {
      expect(_mean(const []), isNull);
    });

    test('is the sample itself for a single sample', () {
      expect(_mean([(t: 120, depth: 18.5)]), 18.5);
    });

    test('averages the samples when no time passes between them', () {
      expect(
        _mean([(t: 60, depth: 10), (t: 60, depth: 20), (t: 60, depth: 30)]),
        closeTo(20, 1e-9),
      );
    });

    test('a repeated timestamp adds no time to the mean', () {
      // The step from 10 m to 30 m at t=60 takes no time, so the mean is
      // that of the two flat stretches, 30 s each.
      expect(
        _mean([
          (t: 30, depth: 10),
          (t: 60, depth: 10),
          (t: 60, depth: 30),
          (t: 90, depth: 30),
        ]),
        closeTo(20, 1e-9),
      );
    });

    test('a step back in time adds no time to the mean', () {
      expect(
        _mean([
          (t: 0, depth: 10),
          (t: 60, depth: 10),
          (t: 30, depth: 50),
          (t: 90, depth: 50),
        ]),
        closeTo(30, 1e-9),
      );
    });
  });
}
