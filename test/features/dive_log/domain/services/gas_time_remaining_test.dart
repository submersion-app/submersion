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

    test('sparse samples still fill a window of exactly its length', () {
      // Every 50 s: at t = 200 the window start (80 s) falls between samples,
      // so pressure is read there and the drop covers the 120 s window.
      // Consumption is 3 bar/min at depth, so SAC is 1.0; P(200) = 220 bar,
      // usable 166 bar, GTR = 166 / 3 = 55.33 min = 3320 s.
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

    group('is independent of how the same dive was sampled (#3975)', () {
      test('weights the window depth by elapsed time, not sample count', () {
        // Mean over the 120 s window = (60 * 10 + 60 * 20) / 120 = 15 m, not
        // the sample average of 16.67 m. SAC = 10 bar/min / 2.5 bar = 4.0.
        // Ascent from 30 m: 4 * 3 min * 2.5 bar = 30 bar; usable 100 bar at
        // 16 bar/min = 6.25 min.
        final gtr = calculateGtrCurve(
          depths: const [10.0, 10.0, 30.0],
          timestamps: const [0, 60, 120],
          pressures: const [200.0, 190.0, 180.0],
          reserveBar: 50.0,
        );

        expect(gtr[2], 375);
      });

      test('a sample added on an existing segment changes nothing', () {
        final gtr = calculateGtrCurve(
          depths: const [10.0, 10.0, 10.0, 30.0],
          timestamps: const [0, 10, 60, 120],
          pressures: const [200.0, 198.33333333333334, 190.0, 180.0],
          reserveBar: 50.0,
        );

        expect(gtr[3], 375);
      });

      test('reads pressure where the window starts, between samples', () {
        // At t = 200 the window opens at 80 s, on the line from 200 to 190
        // bar: P(80) = 192. Drop 42 bar over 2 min = 21 bar/min at 3.0 bar
        // ambient, so SAC is 7.0. Ascent 7 * 2 min * 2 bar = 28 bar; usable
        // 72 bar at 21 bar/min = 3.43 min = 205.7 s. Measuring from t = 0
        // instead would spread the late burn over 200 s and read 320 s.
        final gtr = calculateGtrCurve(
          depths: const [20.0, 20.0, 20.0],
          timestamps: const [0, 100, 200],
          pressures: const [200.0, 190.0, 150.0],
          reserveBar: 50.0,
        );

        expect(gtr[2], 205);
      });

      test('a sample added at the window start changes nothing', () {
        final gtr = calculateGtrCurve(
          depths: const [20.0, 20.0, 20.0, 20.0],
          timestamps: const [0, 80, 100, 200],
          pressures: const [200.0, 192.0, 190.0, 150.0],
          reserveBar: 50.0,
        );

        expect(gtr[3], 205);
      });

      test('reads depth where the window starts, between samples', () {
        // At t = 200 the window opens at 80 s, on the descent from 10 to 30 m:
        // D(80) = 26 m. Mean = (20 * 28 + 100 * 30) / 120 = 29.67 m, so 3
        // bar/min is SAC 0.756. Ascent from 30 m: 5.67 bar; usable 154.33 bar
        // at 3.03 bar/min = 51.01 min = 3060.8 s.
        final gtr = calculateGtrCurve(
          depths: const [10.0, 30.0, 30.0],
          timestamps: const [0, 100, 200],
          pressures: const [220.0, 215.0, 210.0],
          reserveBar: 50.0,
        );

        expect(gtr[2], 3060);
      });

      test('a window inside one long sample gap covers only its own time', () {
        // The window (180 s to 300 s) lies on one segment: D(180) = 28 m, so
        // the mean is 34 m. 6 bar/min / 4.4 bar = SAC 1.364. Ascent from 40 m:
        // 16.36 bar; usable 103.64 bar at 6.82 bar/min = 15.2 min.
        final gtr = calculateGtrCurve(
          depths: const [10.0, 40.0],
          timestamps: const [0, 300],
          pressures: const [200.0, 170.0],
          reserveBar: 50.0,
        );

        expect(gtr[1], closeTo(912, 1));
      });

      test('a repeated timestamp adds no time to the window', () {
        // The step from 20 to 40 m at t = 90 takes no time. Mean = (90 * 20 +
        // 30 * 35) / 120 = 23.75 m, not the sample average of 27.5 m.
        // SAC = 5 / 3.375 = 1.481; ascent 11.11 bar; usable 128.89 bar
        // at 5.93 bar/min = 21.75 min.
        final gtr = calculateGtrCurve(
          depths: const [20.0, 20.0, 40.0, 30.0],
          timestamps: const [0, 90, 90, 120],
          pressures: const [200.0, 192.5, 192.5, 190.0],
          reserveBar: 50.0,
        );

        expect(gtr[3], closeTo(1305, 1));
      });

      test('a dive resampled every second reads the same at every sample', () {
        const knotTimes = [0, 45, 130, 200, 330, 420];
        const knotDepths = [5.0, 18.0, 30.0, 30.0, 12.0, 6.0];
        const knotPressures = [220.0, 214.0, 199.0, 187.0, 170.0, 165.0];

        double at(List<double> series, int time) {
          final next = knotTimes.indexWhere((t) => t >= time);
          if (knotTimes[next] == time) return series[next];
          final from = next - 1;
          final progress =
              (time - knotTimes[from]) / (knotTimes[next] - knotTimes[from]);
          return series[from] + (series[next] - series[from]) * progress;
        }

        final sparse = calculateGtrCurve(
          depths: knotDepths,
          timestamps: knotTimes,
          pressures: knotPressures,
          reserveBar: 50.0,
        );
        final denseTimes = List<int>.generate(421, (i) => i);
        final dense = calculateGtrCurve(
          depths: denseTimes.map((t) => at(knotDepths, t)).toList(),
          timestamps: denseTimes,
          pressures: denseTimes.map((t) => at(knotPressures, t)).toList(),
          reserveBar: 50.0,
        );

        expect(sparse[3], isNotNull);
        for (var i = 0; i < knotTimes.length; i++) {
          final expected = sparse[i];
          final actual = dense[knotTimes[i]];
          if (expected == null) {
            expect(actual, isNull, reason: 't = ${knotTimes[i]}');
          } else {
            expect(actual, closeTo(expected, 1), reason: 't = ${knotTimes[i]}');
          }
        }
      });
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

    test('throws on a window with no length', () {
      expect(
        () => calculateGtrCurve(
          depths: const [20.0, 20.0],
          timestamps: const [0, 10],
          pressures: const [200.0, 199.0],
          reserveBar: 50.0,
          sacWindowSeconds: 0,
        ),
        throwsArgumentError,
      );
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
