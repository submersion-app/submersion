import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/time_weighted_mean.dart';

typedef _Sample = ({int t, double depth});

double? _mean(List<_Sample> samples) =>
    timeWeightedMean(samples, time: (s) => s.t, value: (s) => s.depth);

double? _between(List<_Sample> samples, num start, num end) =>
    timeWeightedMeanBetween(
      samples,
      start: start,
      end: end,
      time: (s) => s.t,
      value: (s) => s.depth,
    );

void main() {
  group('timeWeightedMeanBetween', () {
    const profile = <_Sample>[
      (t: 0, depth: 10),
      (t: 100, depth: 10),
      (t: 400, depth: 30),
      (t: 600, depth: 30),
    ];

    test('covers the whole window, interpolating at both edges', () {
      // 13.33 m at 150 s, 30 m at 400 s and at 450 s: 250 s averaging
      // 21.67 m, then 50 s at 30 m.
      expect(
        _between(profile, 150, 450),
        closeTo((250 * (40 / 3 + 30) / 2 + 50 * 30) / 300, 1e-9),
      );
    });

    test('a window between two samples still reads the path', () {
      // 200 s centred on the ramp's midpoint, at 20 m.
      expect(_between(profile, 150, 350), closeTo(20, 1e-9));
    });

    test('a window ending on a sample stops there', () {
      expect(_between(profile, 0, 400), closeTo((1000 + 6000) / 400, 1e-9));
    });

    test('is the same as the whole series over the whole series', () {
      expect(_between(profile, 0, 600), closeTo(_mean(profile)!, 1e-9));
    });

    test('a window running past the samples stops at them', () {
      expect(_between(profile, 500, 900), closeTo(30, 1e-9));
    });

    test('samplesInWindow gives the edges with the samples between', () {
      final window = samplesInWindow(
        profile,
        start: 250,
        end: 450,
        time: (s) => s.t,
        value: (s) => s.depth,
      );

      expect(window, hasLength(3));
      expect(window.map((s) => s.time), [250, 400, 450]);
      expect(window[0].value, closeTo(20, 1e-9));
      expect(window[1].value, 30);
      expect(window[2].value, closeTo(30, 1e-9));
    });

    test('has no value without samples in or around the window', () {
      expect(_between(profile, 700, 900), isNull);
      expect(_between(const [], 0, 10), isNull);
    });
  });

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

    test('exposes the area and span it has built up', () {
      final mean = TimeWeightedMean()
        ..add(0, 10)
        ..add(60, 20);

      expect(mean.area, closeTo(900, 1e-9));
      expect(mean.span, 60);
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
