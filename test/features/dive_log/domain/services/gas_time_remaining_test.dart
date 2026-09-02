import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/gas_time_remaining.dart';

/// Shearwater-style GTR: minutes at the current depth and SAC until a direct
/// 10 m/min ascent would surface with exactly the reserve pressure left.
///
/// Reference vector, worked by hand: 200 bar at 20 m, SAC 1.0 bar/min at the
/// surface, reserve 50 bar. Ascent gas = 1.0 * (20/10) * (1 + 20/20) = 4 bar,
/// usable = 200 - 50 - 4 = 146 bar, consumption at depth = 3 bar/min, so
/// GTR = 146 / 3 = 48.67 min = 2920 s.
void main() {
  /// Every [intervalSeconds] for [count] samples at a constant [depth], with
  /// the tank draining at [barPerMinuteAtDepth] from [startBar].
  ({List<double> depths, List<int> timestamps, List<double> pressures}) steady({
    int count = 121,
    int intervalSeconds = 10,
    double depth = 20.0,
    double startBar = 230.0,
    double barPerMinuteAtDepth = 3.0,
  }) {
    final timestamps = List<int>.generate(count, (i) => i * intervalSeconds);
    return (
      depths: List<double>.filled(count, depth),
      timestamps: timestamps,
      pressures: timestamps
          .map((t) => startBar - barPerMinuteAtDepth * t / 60)
          .toList(),
    );
  }

  group('calculateGtrCurve', () {
    test('steady 20 m at SAC 1 bar/min reads 48.7 min at 200 bar', () {
      final p = steady();
      final gtr = calculateGtrCurve(
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
      );

      expect(gtr.length, p.depths.length);
      // t = 600 s: 230 - 3 * 10 = 200 bar.
      expect(p.pressures[60], closeTo(200.0, 1e-9));
      expect(gtr[60], isNotNull);
      expect(gtr[60]!, closeTo(2920, 1));
    });

    test('is blank until a full SAC window of history exists', () {
      final p = steady();
      final gtr = calculateGtrCurve(
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
      );

      // 110 s of history: window not yet full.
      expect(gtr[11], isNull);
      // 120 s of history: first sample with a full window.
      expect(gtr[12], isNotNull);
    });

    test('is blank at the surface', () {
      final p = steady();
      final depths = List<double>.from(p.depths)..[60] = 0.5;
      final gtr = calculateGtrCurve(
        depths: depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
      );

      expect(gtr[60], isNull);
      expect(gtr[61], isNotNull);
    });

    test('is blank when pressure is not falling', () {
      final p = steady(barPerMinuteAtDepth: 0.0);
      final gtr = calculateGtrCurve(
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
      );

      expect(gtr.every((v) => v == null), isTrue);
    });

    test('is blank while a deco ceiling exists', () {
      final p = steady();
      final ceilings = List<double>.filled(p.depths.length, 0.0)..[60] = 3.0;
      final gtr = calculateGtrCurve(
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
        ceilings: ceilings,
      );

      expect(gtr[60], isNull);
      expect(gtr[59], isNotNull);
      expect(gtr[61], isNotNull);
    });

    test('clamps to zero once reserve plus ascent gas exceeds the tank', () {
      // 82 - 3 * 10 = 52 bar at t = 600 s: 52 - 50 - 4 < 0.
      final p = steady(startBar: 82.0);
      final gtr = calculateGtrCurve(
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
      );

      expect(p.pressures[60], closeTo(52.0, 1e-9));
      expect(gtr[60], 0);
    });

    test('sparse samples anchor the window at the latest sample at or before '
        'its start', () {
      // Every 50 s: at t = 200 the window start (80 s) falls between samples,
      // so the drop is measured from t = 50 over 150 s. Consumption is still
      // 3 bar/min at depth, so SAC is 1.0; P(200) = 220 bar, usable 166 bar,
      // GTR = 166 / 3 = 55.33 min = 3320 s.
      final p = steady(count: 5, intervalSeconds: 50);
      final gtr = calculateGtrCurve(
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
      );

      expect(gtr[0], isNull);
      expect(gtr[1], isNull);
      expect(gtr[2], isNull);
      expect(gtr[3], isNotNull);
      expect(gtr[4]!, closeTo(3320, 1));
    });

    test('truncates rather than rounds, so a countdown never overstates', () {
      // 200.99 bar at t = 600 s: usable 146.99 bar at 3 bar/min is 2939.8 s.
      // Rounding to 2940 would display 49 min for 48 min 59.8 s remaining.
      final p = steady(startBar: 230.99);
      final gtr = calculateGtrCurve(
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        reserveBar: 50.0,
      );

      expect(gtr[60], 2939);
    });

    test('prices the window at its mean depth, not the current depth', () {
      // Window at t = 180 s spans samples 1..3 (10, 20, 30 m): mean 20 m, so
      // SAC = (156 - 150) bar over 2 min / 3.0 bar ambient = 1.0 bar/min.
      // Ascent from 30 m: 1.0 * 3 min * 2.5 bar = 7.5 bar; usable
      // 150 - 50 - 7.5 = 92.5 bar at 4.0 bar ambient = 23.125 min.
      final gtr = calculateGtrCurve(
        depths: const [5.0, 10.0, 20.0, 30.0],
        timestamps: const [0, 60, 120, 180],
        pressures: const [160.0, 156.0, 153.0, 150.0],
        reserveBar: 50.0,
      );

      expect(gtr[3], 1387);
    });

    test('keeps the window bounded when timestamps do not advance', () {
      // Corrupt profiles repeat a timestamp. No window ever spans any time,
      // so every sample is blank rather than dividing by a zero duration.
      final gtr = calculateGtrCurve(
        depths: List<double>.filled(400, 20.0),
        timestamps: List<int>.filled(400, 300),
        pressures: List<double>.generate(400, (i) => 200.0 - i * 0.01),
        reserveBar: 50.0,
      );

      expect(gtr.every((v) => v == null), isTrue);
    });

    test('throws on mismatched series lengths', () {
      expect(
        () => calculateGtrCurve(
          depths: const [20.0, 20.0],
          timestamps: const [0, 10, 20],
          pressures: const [200.0, 199.0],
          reserveBar: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
