import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';

void main() {
  // Reported bug scenario: 60 min dive, ~10 min at 95 ft (29 m) then a
  // 40 min multilevel tail at 50 ft (15.2 m), safety stop, surface.
  // Threshold = min(max(6, 0.33*29=9.57), 0.85*29=24.65) = 9.57 m.
  // Last sample >= 9.57 m is t=3060 (15.2 m), so bottom time = 3060 s.
  // The old 85% heuristic returned 540 s for this profile.
  const multilevel = [
    (timestamp: 0, depth: 0.0),
    (timestamp: 60, depth: 29.0),
    (timestamp: 600, depth: 29.0),
    (timestamp: 660, depth: 15.2),
    (timestamp: 3060, depth: 15.2),
    (timestamp: 3120, depth: 5.0),
    (timestamp: 3300, depth: 5.0),
    (timestamp: 3600, depth: 0.0),
  ];

  group('BottomTimeCalculator.secondsFromSamples', () {
    test('multilevel dive counts the shallow tail as bottom time', () {
      expect(BottomTimeCalculator.secondsFromSamples(multilevel), 3060);
    });

    test('square profile measures surface departure to ascent start', () {
      // Threshold = min(max(6, 9.9), 25.5) = 9.9 m; last sample >= 9.9 m
      // is t=1200. Includes the descent (starts at t=0), so 1200 s -- the
      // old heuristic gave 1140 s (descent excluded).
      const square = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 60, depth: 30.0),
        (timestamp: 120, depth: 30.0),
        (timestamp: 1200, depth: 30.0),
        (timestamp: 1260, depth: 5.0),
        (timestamp: 1320, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(square), 1200);
    });

    test('safety stop at 5 m is excluded via the 6 m absolute floor', () {
      // 18 m dive: threshold = min(max(6, 5.94), 15.3) = 6 m. The 5 m
      // safety stop (t=1860..2160) is below it; bottom ends at t=1800.
      const withStop = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 60, depth: 18.0),
        (timestamp: 1800, depth: 18.0),
        (timestamp: 1860, depth: 5.0),
        (timestamp: 2160, depth: 5.0),
        (timestamp: 2220, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(withStop), 1800);
    });

    test('dive shallower than the floor still gets a result (0.85 cap)', () {
      // 4 m dive: max(6, 1.32) = 6 exceeds max depth, so the cap kicks in:
      // threshold = 0.85 * 4 = 3.4 m. Last sample >= 3.4 m is t=600.
      const shallow = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 30, depth: 4.0),
        (timestamp: 600, depth: 4.0),
        (timestamp: 630, depth: 2.0),
        (timestamp: 660, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(shallow), 600);
    });

    test('deep stop beyond a third of max depth counts as bottom (known '
        'trade-off, documented in the spec)', () {
      // 45 m dive: threshold = min(max(6, 14.85), 38.25) = 14.85 m. The
      // 21 m deep stop (t=1260..1440) sits above it and is counted; the
      // 6 m stop is not (6 < 14.85). Bottom ends at t=1440.
      const deco = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 120, depth: 45.0),
        (timestamp: 1200, depth: 45.0),
        (timestamp: 1260, depth: 21.0),
        (timestamp: 1440, depth: 21.0),
        (timestamp: 1500, depth: 6.0),
        (timestamp: 1800, depth: 6.0),
        (timestamp: 1860, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(deco), 1440);
    });

    test('unsorted input is sorted internally', () {
      final shuffled = [
        multilevel[4],
        multilevel[0],
        multilevel[6],
        multilevel[2],
        multilevel[1],
        multilevel[7],
        multilevel[3],
        multilevel[5],
      ];
      expect(BottomTimeCalculator.secondsFromSamples(shuffled), 3060);
    });

    test('returns null for fewer than 3 samples', () {
      expect(
        BottomTimeCalculator.secondsFromSamples(const [
          (timestamp: 0, depth: 0.0),
          (timestamp: 60, depth: 10.0),
        ]),
        isNull,
      );
    });

    test('returns null when all depths are zero', () {
      expect(
        BottomTimeCalculator.secondsFromSamples(const [
          (timestamp: 0, depth: 0.0),
          (timestamp: 60, depth: 0.0),
          (timestamp: 120, depth: 0.0),
        ]),
        isNull,
      );
    });

    test('returns null when the bottom span is zero', () {
      // Only the first sample reaches the threshold (min(max(6, 9.9),
      // 25.5) = 9.9 m), so ascentStart == first timestamp and span is 0.
      expect(
        BottomTimeCalculator.secondsFromSamples(const [
          (timestamp: 0, depth: 30.0),
          (timestamp: 60, depth: 1.0),
          (timestamp: 120, depth: 0.0),
        ]),
        isNull,
      );
    });
    group('totalDurationSeconds clamp', () {
      // Issue #1642: a 13 s dive to 1.77 m whose sample stream keeps logging
      // at the surface. Threshold = min(max(6, 0.58), 0.85 * 1.77 = 1.50) =
      // 1.50 m, so the 1.55 m noise sample at t=368 becomes the ascent start
      // and the unbounded answer is 368 s, longer than the whole dive.
      const shallowWithSurfaceTail = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 5, depth: 1.77),
        (timestamp: 10, depth: 1.6),
        (timestamp: 13, depth: 0.3),
        (timestamp: 60, depth: 0.2),
        (timestamp: 120, depth: 0.4),
        (timestamp: 240, depth: 0.9),
        (timestamp: 368, depth: 1.55),
        (timestamp: 400, depth: 0.0),
      ];

      test('without a total duration the surface tail is counted', () {
        expect(
          BottomTimeCalculator.secondsFromSamples(shallowWithSurfaceTail),
          368,
        );
      });

      test('never exceeds the dive\'s own total duration', () {
        expect(
          BottomTimeCalculator.secondsFromSamples(
            shallowWithSurfaceTail,
            totalDurationSeconds: 13,
          ),
          13,
        );
      });

      test('is a no-op when the result is already within bounds', () {
        expect(
          BottomTimeCalculator.secondsFromSamples(
            multilevel,
            totalDurationSeconds: 3600,
          ),
          3060,
        );
      });

      test('a zero total duration yields null rather than zero', () {
        expect(
          BottomTimeCalculator.secondsFromSamples(
            shallowWithSurfaceTail,
            totalDurationSeconds: 0,
          ),
          isNull,
        );
      });
    });
  });
}
