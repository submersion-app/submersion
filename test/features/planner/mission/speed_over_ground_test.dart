import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';

void main() {
  const resolver = LegSpeedResolver();

  group('CurrentVector.crossTrackComponent', () {
    test('a current square to the heading is all cross track', () {
      const current = CurrentVector(speedMps: 0.3, setsTowardDeg: 90);
      expect(current.crossTrackComponent(0), closeTo(0.3, 1e-12));
      expect(current.alongRouteComponent(0), closeTo(0, 1e-12));
    });

    test('the cross share keeps its size on the reversed heading', () {
      const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 45);
      expect(
        current.crossTrackComponent(180).abs(),
        closeTo(current.crossTrackComponent(0).abs(), 1e-12),
      );
    });
  });

  group('speed over ground', () {
    test('a pure cross current costs speed both ways', () {
      // sqrt(0.5^2 - 0.3^2) = 0.4
      final speeds = resolver.resolveHeading(
        headingDeg: 0,
        current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 90),
        baseSpeedMps: 0.5,
      );
      expect(speeds.outboundMps, closeTo(0.4, 1e-9));
      expect(speeds.returnMps, closeTo(0.4, 1e-9));
    });

    test('a quartering current helps out, hurts back, and costs across', () {
      // a = x = 0.2 * cos 45 = 0.141421; sqrt(0.25 - 0.02) = 0.479583
      final speeds = resolver.resolveHeading(
        headingDeg: 0,
        current: const CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
        baseSpeedMps: 0.5,
      );
      expect(speeds.outboundMps, closeTo(0.479583 + 0.141421, 1e-6));
      expect(speeds.returnMps, closeTo(0.479583 - 0.141421, 1e-6));
    });

    test('a cross current as fast as the diver cannot be held', () {
      final speeds = resolver.resolveHeading(
        headingDeg: 0,
        current: const CurrentVector(speedMps: 0.5, setsTowardDeg: 90),
        baseSpeedMps: 0.5,
      );
      expect(speeds.outboundMps.isNaN, isFalse);
      expect(speeds.returnMps.isNaN, isFalse);
      expect(speeds.outboundMps, 0);
      expect(speeds.returnMps, 0);
      expect(speeds.traversable, isFalse);
    });

    test('a cross current can block a swimmer but not a scooter', () {
      const current = CurrentVector(speedMps: 0.3, setsTowardDeg: 90);
      expect(
        resolver
            .resolveHeading(headingDeg: 0, current: current, baseSpeedMps: 0.2)
            .traversable,
        isFalse,
      );
      expect(
        resolver
            .resolveHeading(headingDeg: 0, current: current, baseSpeedMps: 0.9)
            .traversable,
        isTrue,
      );
    });

    test('headings outside 0 to 360 behave like their normalised twin', () {
      const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 45);
      LegSpeeds at(double heading) => resolver.resolveHeading(
        headingDeg: heading,
        current: current,
        baseSpeedMps: 0.5,
      );
      expect(at(450).outboundMps, closeTo(at(90).outboundMps, 1e-12));
      expect(at(-90).returnMps, closeTo(at(270).returnMps, 1e-12));
    });

    test('resolve on a leg is resolveHeading on its heading', () {
      const leg = MissionLeg(
        id: 'L1',
        order: 0,
        label: 'T',
        distanceM: 300,
        depthM: 20,
        headingDeg: 30,
      );
      const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 100);
      expect(
        resolver.resolve(leg: leg, current: current, baseSpeedMps: 0.6),
        resolver.resolveHeading(
          headingDeg: 30,
          current: current,
          baseSpeedMps: 0.6,
        ),
      );
    });
  });
}
