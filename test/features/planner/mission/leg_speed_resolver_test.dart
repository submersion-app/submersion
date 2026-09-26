import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';

const _leg = MissionLeg(
  id: 'l1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);

void main() {
  const resolver = LegSpeedResolver();

  test('no current: both directions run at the base speed', () {
    final speeds = resolver.resolve(
      leg: _leg,
      current: null,
      baseSpeedMps: 0.5,
    );
    expect(speeds, const LegSpeeds(outboundMps: 0.5, returnMps: 0.5));
    expect(speeds.traversable, isTrue);
  });

  test('a following current helps outbound and hurts the return', () {
    const current = CurrentVector(speedMps: 0.2, setsTowardDeg: 90);
    final speeds = resolver.resolve(
      leg: _leg,
      current: current,
      baseSpeedMps: 0.5,
    );
    expect(speeds.outboundMps, closeTo(0.7, 1e-9));
    expect(speeds.returnMps, closeTo(0.3, 1e-9));
  });

  test('a current as strong as the base speed blocks the return only', () {
    const current = CurrentVector(speedMps: 0.5, setsTowardDeg: 90);
    final speeds = resolver.resolve(
      leg: _leg,
      current: current,
      baseSpeedMps: 0.5,
    );
    expect(speeds.outboundTraversable, isTrue);
    expect(speeds.returnTraversable, isFalse);
    expect(speeds.traversable, isFalse);
  });

  test('a head current stronger than the base speed blocks the outbound', () {
    const current = CurrentVector(speedMps: 0.6, setsTowardDeg: 270);
    final speeds = resolver.resolve(
      leg: _leg,
      current: current,
      baseSpeedMps: 0.5,
    );
    expect(speeds.outboundTraversable, isFalse);
    expect(speeds.returnTraversable, isTrue);
  });

  test('a zero base speed is never traversable', () {
    final speeds = resolver.resolve(leg: _leg, current: null, baseSpeedMps: 0);
    expect(speeds.traversable, isFalse);
  });
}
