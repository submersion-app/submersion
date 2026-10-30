import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

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

  test('unset rates and battery reserve follow the engine config', () {
    // The plan and mission leave descent rate and battery reserve unset, so
    // both must come from the diver's Settings (issue #3552), not the 18
    // m/min and 1/3 spec constants.
    const config = PlanEngineConfig(
      descentRate: 10,
      batteryReserveFraction: 0.9,
    );
    const configured = MissionEngine(
      scenarios: MissionScenarioService(engine: PlanEngine(config: config)),
    );
    final mission = DpvMission(
      legs: [_leg('L1', 0), _leg('L2', 1)],
      team: [_member('a', 0)],
    );

    final segments = configured.roundTripSegments(
      plan: _plan(),
      mission: mission,
    );
    // 0 to 20 m at 10 m/min, not 67 s at 18 m/min.
    expect(segments.first.durationSeconds, 120);

    // 800 m at 0.5 m/s is about a fifth of the 2 h burn: inside a 1/3
    // reserve, outside a 90% one.
    MissionBindingFactor? factorWith(MissionEngine e) =>
        e.compute(plan: _plan(), mission: mission).members.single.bindingFactor;
    expect(factorWith(engine), isNot(MissionBindingFactor.battery));
    expect(factorWith(configured), MissionBindingFactor.battery);
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

  group('traversableRoute', () {
    const against = CurrentVector(speedMps: 0.6, setsTowardDeg: 180);

    test('a clear route keeps every leg and names no cut', () {
      final route = engine.traversableRoute(
        DpvMission(
          legs: [_leg('L1', 0), _leg('L2', 1)],
          team: [_member('a', 0)],
        ),
      );
      expect(route.speeds, hasLength(2));
      expect(route.cut, isNull);
    });

    test('a blocked first leg leaves no route and names the leg', () {
      final route = engine.traversableRoute(
        DpvMission(
          legs: [
            _leg('L1', 0).copyWith(current: against),
            _leg('L2', 1),
          ],
          team: [_member('a', 0)],
        ),
      );
      expect(route.speeds, isEmpty);
      expect(route.cut!.type, MissionIssueType.untraversableLeg);
      expect(route.cut!.legId, 'L1');
      expect(route.cut!.outbound, isTrue);
    });

    test('a blocked later leg keeps the legs before it', () {
      final route = engine.traversableRoute(
        DpvMission(
          legs: [
            _leg('L1', 0),
            _leg('L2', 1).copyWith(current: against),
          ],
          team: [_member('a', 0)],
        ),
      );
      expect(route.speeds, hasLength(1));
      expect(route.cut!.legId, 'L2');
    });
  });
}
