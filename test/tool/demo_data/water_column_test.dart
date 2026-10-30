import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/seeders/water_column.dart';
import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/story/destinations.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';

/// A profile through [knots] of (seconds, metres), sampled every [interval].
List<ShapeSample> _profile(List<(int, double)> knots, {int interval = 10}) => [
  for (var t = 0; t <= knots.last.$1; t += interval)
    ShapeSample(t: t, depth: _depthAt(knots, t)),
];

double _depthAt(List<(int, double)> knots, int t) {
  for (var i = 1; i < knots.length; i++) {
    final (t0, d0) = knots[i - 1];
    final (t1, d1) = knots[i];
    if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
  }
  return knots.last.$2;
}

/// A square dive to [depth]: down in [descent] seconds, 20 minutes there,
/// a safety stop and up.
List<ShapeSample> _square(double depth, {int descent = 180}) => _profile([
  (0, 0),
  (descent, depth),
  (descent + 1200, depth),
  (descent + 1500, 5),
  (descent + 1680, 5),
  (descent + 1740, 0),
]);

Destination _at(String key) => key == 'home'
    ? homeDestination
    : tripDestinations.firstWhere((d) => d.key == key);

List<double> _trace(String key, double deepC, List<ShapeSample> s, int seed) =>
    WaterColumn.forDive(_at(key), deepC, Random(seed)).trace(s, Random(seed));

int _turns(List<double> trace) {
  var turns = 0;
  var last = 0;
  for (var i = 1; i < trace.length; i++) {
    final d = (trace[i] - trace[i - 1]).sign.toInt();
    if (d != 0 && last != 0 && d != last) turns++;
    if (d != 0) last = d;
  }
  return turns;
}

void main() {
  const seeds = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89];

  test('a tropical dive stays within a couple of degrees', () {
    for (final seed in seeds) {
      final trace = _trace('maldives', 28, _square(30), seed);
      expect(trace.reduce(max) - trace.reduce(min), lessThanOrEqualTo(2.5));
    }
  });

  test('a summer dive off New Jersey crosses a thermocline', () {
    for (final seed in seeds) {
      final trace = _trace('home', 15, _square(25), seed);
      expect(trace.first - trace.reduce(min), greaterThanOrEqualTo(6));
    }
  });

  test('winter water off New Jersey is nearly the same top to bottom', () {
    for (final seed in seeds) {
      final trace = _trace('home', 5, _square(25), seed);
      expect(trace.reduce(max) - trace.reduce(min), lessThanOrEqualTo(1.5));
    }
  });

  test("stratified water's planned temperature is its deep water", () {
    for (final seed in seeds) {
      final trace = _trace('home', 12, _square(25), seed);
      expect((trace.reduce(min) - 12).abs(), lessThanOrEqualTo(0.35));
    }
  });

  test("a sea's planned temperature is its top water, colder below", () {
    for (final seed in seeds) {
      final trace = _trace('cyprus', 27, _square(30), seed);
      expect((trace.first - 27).abs(), lessThanOrEqualTo(0.35));
      expect(trace.reduce(min), lessThan(25));
    }
  });

  test('no sea is ever warmer than its warmest water', () {
    for (final d in tripDestinations.where((d) => !d.freshwater)) {
      final warmest = d.waterTempC.$2;
      for (final seed in seeds) {
        final trace = _trace(d.key, warmest, _square(12), seed);
        expect(
          trace.reduce(max),
          lessThanOrEqualTo(warmest + 0.3),
          reason: '${d.key} seed $seed',
        );
      }
    }
  });

  test('readings never flicker between neighbouring samples', () {
    for (final key in ['maldives', 'home', 'med']) {
      for (final seed in seeds) {
        final trace = _trace(key, key == 'home' ? 14 : 20, _square(28), seed);
        for (var i = 1; i < trace.length - 1; i++) {
          final flicker =
              trace[i - 1] == trace[i + 1] && trace[i] != trace[i - 1];
          expect(flicker, isFalse, reason: '$key seed $seed sample $i');
        }
        // A 32-minute dive turns from warming to cooling only a few times.
        expect(_turns(trace), lessThanOrEqualTo(14), reason: '$key $seed');
      }
    }
  });

  test('the sensor follows a fast descent slowly', () {
    for (final seed in seeds) {
      final trace = _trace('home', 15, _square(25, descent: 60), seed);
      // Samples are 10 s apart: six of them make a minute.
      for (var i = 6; i < trace.length; i++) {
        expect(
          (trace[i] - trace[i - 6]).abs(),
          lessThanOrEqualTo(8),
          reason: 'seed $seed sample $i',
        );
      }
    }
  });

  test('readings have the 0.1 degree resolution of a dive computer', () {
    final trace = _trace('maldives', 28, _square(30), 1);
    for (final t in trace) {
      expect((t * 10 - (t * 10).round()).abs(), lessThan(1e-9));
    }
  });
}
