import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/estimated_profile.dart';

/// The outline as (seconds, depth) pairs, rounded to hundredths so the
/// expectations can be written by hand.
List<(double, double)> _corners(EstimatedProfile profile) => [
  for (final p in profile.points)
    (
      (p.seconds * 100).roundToDouble() / 100,
      (p.depth * 100).roundToDouble() / 100,
    ),
];

void main() {
  group('EstimatedProfile.estimate', () {
    test('needs a depth', () {
      expect(
        EstimatedProfile.estimate(
          maxDepth: null,
          runtime: const Duration(minutes: 40),
        ),
        isNull,
      );
      expect(
        EstimatedProfile.estimate(
          maxDepth: 0,
          runtime: const Duration(minutes: 40),
        ),
        isNull,
      );
    });

    test('needs a runtime or a bottom time', () {
      expect(EstimatedProfile.estimate(maxDepth: 20), isNull);
      expect(
        EstimatedProfile.estimate(maxDepth: 20, runtime: Duration.zero),
        isNull,
      );
    });

    test('runtime only: descends, holds, ascends through a safety stop', () {
      final profile = EstimatedProfile.estimate(
        maxDepth: 30,
        runtime: const Duration(minutes: 45),
      )!;

      // 30 m at 18 m/min is 100 s down. Up: 25 m at 9 m/min (166.67 s),
      // 3 minutes at 5 m, then 5 m at 9 m/min (33.33 s): 380 s in all.
      expect(_corners(profile), [
        (0.0, 0.0),
        (100.0, 30.0),
        (2320.0, 30.0),
        (2486.67, 5.0),
        (2666.67, 5.0),
        (2700.0, 0.0),
      ]);
      expect(profile.maxDepth, 30);
      expect(profile.durationSeconds, 2700);
    });

    test('a dive no deeper than 10 m gets no safety stop', () {
      final profile = EstimatedProfile.estimate(
        maxDepth: 8,
        runtime: const Duration(minutes: 40),
      )!;

      expect(_corners(profile), [
        (0.0, 0.0),
        (26.67, 8.0),
        (2346.67, 8.0),
        (2400.0, 0.0),
      ]);
    });

    test('bottom time only: the ascent starts at the bottom time', () {
      final profile = EstimatedProfile.estimate(
        maxDepth: 20,
        bottomTime: const Duration(minutes: 30),
      )!;

      expect(_corners(profile), [
        (0.0, 0.0),
        (66.67, 20.0),
        (1800.0, 20.0),
        (1900.0, 5.0),
        (2080.0, 5.0),
        (2113.33, 0.0),
      ]);
    });

    test(
      'bottom time and runtime: a long ascent window slows the first leg',
      () {
        final profile = EstimatedProfile.estimate(
          maxDepth: 20,
          bottomTime: const Duration(minutes: 30),
          runtime: const Duration(minutes: 40),
        )!;

        // 600 s from leaving the bottom to the surface; the stop and the last
        // leg keep their length and the first leg takes the rest.
        expect(_corners(profile), [
          (0.0, 0.0),
          (66.67, 20.0),
          (1800.0, 20.0),
          (2186.67, 5.0),
          (2366.67, 5.0),
          (2400.0, 0.0),
        ]);
      },
    );

    test(
      'bottom time and runtime: a short ascent window squeezes the ascent',
      () {
        final profile = EstimatedProfile.estimate(
          maxDepth: 30,
          bottomTime: const Duration(minutes: 40),
          runtime: const Duration(minutes: 40, seconds: 190),
        )!;

        // 190 s for a 380 s ascent: every leg at half its length.
        expect(_corners(profile), [
          (0.0, 0.0),
          (100.0, 30.0),
          (2400.0, 30.0),
          (2483.33, 5.0),
          (2573.33, 5.0),
          (2590.0, 0.0),
        ]);
      },
    );

    test('a bottom time at or past the runtime is ignored', () {
      final withBadBottom = EstimatedProfile.estimate(
        maxDepth: 30,
        bottomTime: const Duration(minutes: 50),
        runtime: const Duration(minutes: 45),
      )!;
      final runtimeOnly = EstimatedProfile.estimate(
        maxDepth: 30,
        runtime: const Duration(minutes: 45),
      )!;

      expect(_corners(withBadBottom), _corners(runtimeOnly));
    });

    test('a runtime too short for the rates scales the whole dive to fit', () {
      final profile = EstimatedProfile.estimate(
        maxDepth: 30,
        runtime: const Duration(minutes: 4),
      )!;

      // 480 s of descent and ascent in 240 s: everything at half length, and
      // no time left at the bottom.
      expect(_corners(profile), [
        (0.0, 0.0),
        (50.0, 30.0),
        (133.33, 5.0),
        (223.33, 5.0),
        (240.0, 0.0),
      ]);
    });

    test('a bottom time shorter than the descent ends the descent there', () {
      final profile = EstimatedProfile.estimate(
        maxDepth: 40,
        bottomTime: const Duration(minutes: 1),
      )!;

      expect(_corners(profile).take(2), [(0.0, 0.0), (60.0, 40.0)]);
      expect(_corners(profile)[2], (60.0 + 35 / 9 * 60, 5.0).rounded);
    });

    test('corners never go back in time', () {
      for (final depth in [3.0, 10.0, 10.5, 25.0, 60.0]) {
        for (final minutes in [1, 3, 10, 60]) {
          final profile = EstimatedProfile.estimate(
            maxDepth: depth,
            runtime: Duration(minutes: minutes),
          )!;
          for (var i = 1; i < profile.points.length; i++) {
            expect(
              profile.points[i].seconds,
              greaterThan(profile.points[i - 1].seconds),
              reason: '$depth m, $minutes min, corner $i',
            );
          }
          expect(profile.points.last.depth, 0);
          expect(profile.durationSeconds, minutes * 60);
        }
      }
    });
  });
}

extension on (double, double) {
  (double, double) get rounded =>
      (($1 * 100).roundToDouble() / 100, ($2 * 100).roundToDouble() / 100);
}
