import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Round trip',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 28),
  updatedAt: DateTime(2026, 9, 28),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  scooter: const ScooterSpec(
    name: 'S',
    ratedSpeedMps: 0.5,
    burnTimeSeconds: 7200,
  ),
);

MissionLeg _leg(String id, int order, {double distance = 200}) => MissionLeg(
  id: id,
  order: order,
  label: id,
  distanceM: distance,
  depthM: 20,
  headingDeg: 0,
);

void main() {
  const engine = MissionEngine();

  test('a valid mission gives the same segments as compute', () {
    final mission = DpvMission(
      legs: [_leg('L1', 0), _leg('L2', 1)],
      team: [_member('a', 0), _member('b', 1)],
    );
    final segments = engine.roundTripSegments(plan: _plan(), mission: mission);
    expect(segments, isNotEmpty);
    expect(segments, engine.compute(plan: _plan(), mission: mission).segments);
  });

  test('a route the current blocks keeps the legs before the block', () {
    // L2 heads north into a 0.6 m/s current setting south: the 0.5 m/s
    // scooters cannot make headway on it.
    final mission = DpvMission(
      legs: [
        _leg('L1', 0),
        _leg('L2', 1).copyWith(
          current: const CurrentVector(speedMps: 0.6, setsTowardDeg: 180),
        ),
      ],
      team: [_member('a', 0)],
    );
    final segments = engine.roundTripSegments(plan: _plan(), mission: mission);
    expect(segments.map((s) => s.id), everyElement(isNot(contains('L2'))));
    expect(segments.map((s) => s.id), contains('mission-out-L1'));
  });

  test('a mission with a blocking issue gives no segments', () {
    // The starter mission: one empty leg, a scooter with no numbers.
    final mission = DpvMission(
      legs: [_leg('L1', 0, distance: 0)],
      team: [
        const MissionMember(
          id: 'a',
          order: 0,
          displayName: 'a',
          sacBottom: 15,
          scooter: ScooterSpec(name: '', ratedSpeedMps: 0, burnTimeSeconds: 0),
        ),
      ],
    );
    expect(engine.roundTripSegments(plan: _plan(), mission: mission), isEmpty);
  });
}
