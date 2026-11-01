import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ascent_travel_spans.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

void main() {
  final oneGas = FixedAscentGas(fN2: 0.79);
  final airAndEan50 = OptimalOcAscentGas(
    maxPpO2: 1.6,
    gases: const [
      AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66),
      AvailableGas(fN2: 0.50, fHe: 0, maxPpO2Mod: 21),
    ],
  );

  group('straightAscentSpans', () {
    List<AscentLeg> spans(double from, double to, int seconds) =>
        straightAscentSpans(
          airAndEan50,
          fromDepth: from,
          toDepth: to,
          seconds: seconds,
        );

    test('a leg with no switch is one span, end to end', () {
      expect(spans(60, 30, 200), [
        (fromDepth: 60.0, toDepth: 30.0, seconds: 200),
      ]);
    });

    test('a switch inside the leg cuts it there', () {
      expect(spans(30, 12, 180), [
        (fromDepth: 30.0, toDepth: 21.0, seconds: 90),
        (fromDepth: 21.0, toDepth: 12.0, seconds: 90),
      ]);
    });

    test('a cut rounded to a whole second stays on the line', () {
      // 21 m is 31.8 s into the 60 s leg, so the cut lands on 32 s: on the
      // leg's own line that is 20.93 m, a hair past the switch.
      final cut = spans(30, 13, 60);

      expect(cut.map((span) => span.seconds), [32, 28]);
      expect(cut.first.fromDepth, 30);
      expect(cut.first.toDepth, closeTo(30 - 17 * 32 / 60, 1e-9));
      expect(cut.last.fromDepth, cut.first.toDepth);
      expect(cut.last.toDepth, closeTo(13, 1e-9));
    });

    test('a span rounded away to no time leaves no depth behind', () {
      // The 21 m switch sits 0.01 m above the end of this 60 s leg, so the
      // last span gets no seconds and the first must reach the end itself.
      final cut = spans(30, 20.99, 60);

      expect(cut.map((span) => span.seconds), [60]);
      expect(cut.single.toDepth, closeTo(20.99, 1e-9));
    });

    test('a leg with no time has nothing to walk', () {
      expect(spans(21, 21, 0), isEmpty);
      expect(spans(30, 12, 0), isEmpty);
    });
  });

  group('ascentTravelSpans', () {
    test('a dive with no stops is one span to the surface', () {
      final spans = ascentTravelSpans(
        const SchedulePolicy(finalAscentRate: 3),
        oneGas,
        fromDepth: 18,
        stopDepths: const [],
      );

      // The working rate: no stop was held, so the final rate does not apply.
      expect(spans, [(fromDepth: 18.0, toDepth: 0.0, seconds: 120)]);
    });

    test('each leg takes the rate of its own phase', () {
      final spans = ascentTravelSpans(
        const SchedulePolicy(
          ascentRate: 9,
          intermediateAscentRate: 6,
          shallowAscentRate: 3,
          finalAscentRate: 1,
        ),
        oneGas,
        fromDepth: 30,
        stopDepths: const [12, 9, 6, 3],
      );

      expect(spans, [
        (fromDepth: 30.0, toDepth: 12.0, seconds: 120),
        (fromDepth: 12.0, toDepth: 9.0, seconds: 30),
        (fromDepth: 9.0, toDepth: 6.0, seconds: 60),
        (fromDepth: 6.0, toDepth: 3.0, seconds: 60),
        (fromDepth: 3.0, toDepth: 0.0, seconds: 180),
      ]);
    });

    test('a leg splits at a gas switch and keeps its full duration', () {
      final spans = ascentTravelSpans(
        const SchedulePolicy(),
        airAndEan50,
        fromDepth: 30,
        stopDepths: const [9],
      );

      expect(spans, [
        (fromDepth: 30.0, toDepth: 21.0, seconds: 60),
        (fromDepth: 21.0, toDepth: 9.0, seconds: 80),
        (fromDepth: 9.0, toDepth: 0.0, seconds: 60),
      ]);
    });

    test('the final leg splits at a gas switch too', () {
      final spans = ascentTravelSpans(
        const SchedulePolicy(),
        airAndEan50,
        fromDepth: 25,
        stopDepths: const [],
      );

      expect(spans.map((span) => span.toDepth), [21.0, 0.0]);
      expect(
        spans.fold<int>(0, (sum, span) => sum + span.seconds),
        const SchedulePolicy().ascentSeconds(fromDepth: 25, toDepth: 0),
      );
    });

    test('a first stop at the starting depth adds no span', () {
      final spans = ascentTravelSpans(
        const SchedulePolicy(),
        oneGas,
        fromDepth: 6,
        stopDepths: const [6],
      );

      expect(spans, [(fromDepth: 6.0, toDepth: 0.0, seconds: 40)]);
    });

    test('a switch set between two stops divides the leg between them', () {
      final spans = ascentTravelSpans(
        const SchedulePolicy(),
        OptimalOcAscentGas(
          maxPpO2: 1.6,
          gases: const [
            AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66),
            AvailableGas(fN2: 0.50, fHe: 0, maxPpO2Mod: 16),
          ],
        ),
        fromDepth: 18,
        stopDepths: const [18, 15],
      );

      expect(spans.map((span) => span.toDepth), [16.0, 15.0, 0.0]);
    });

    test('no span runs backwards when a leg holds several switches', () {
      // Rounding each share alone gives 3, 3 and 2 of the leg's 7 seconds.
      final spans = splitAscentLeg(
        OptimalOcAscentGas(
          maxPpO2: 1.6,
          gases: const [
            AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66),
            AvailableGas(fN2: 0.68, fHe: 0, maxPpO2Mod: 18),
            AvailableGas(fN2: 0.50, fHe: 0, maxPpO2Mod: 8),
            AvailableGas(fN2: 0.00, fHe: 0, maxPpO2Mod: 0.4),
          ],
        ),
        fromDepth: 28,
        toDepth: 0,
        seconds: 7,
      );

      expect(spans.map((span) => span.toDepth), [18.0, 8.0, 0.4, 0.0]);
      expect(spans.map((span) => span.seconds), [3, 2, 2, 0]);
    });

    test('a split leg always adds back up to its whole duration', () {
      final spans = splitAscentLeg(
        airAndEan50,
        fromDepth: 30,
        toDepth: 0,
        seconds: 7,
      );

      expect(spans.map((span) => span.fromDepth), [30.0, 21.0]);
      expect(spans.fold<int>(0, (sum, span) => sum + span.seconds), 7);
    });

    test('a plan that ends at the surface has no travel', () {
      final spans = ascentTravelSpans(
        const SchedulePolicy(),
        oneGas,
        fromDepth: 0,
        stopDepths: const [],
      );

      expect(spans, isEmpty);
    });
  });
}
