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
