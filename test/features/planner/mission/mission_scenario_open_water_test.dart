import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Lake',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  sacBottom: 15,
  reservePressure: 50,
  salinityPpt: DiveEnvironment.salinityPptFromDensity(
    DiveEnvironment.en13319Density,
  ),
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  swimSpeedMps: 0.2,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: 0.5,
    burnTimeSeconds: 7200,
  ),
);

const _l1 = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'A',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);
const _l2 = MissionLeg(
  id: 'L2',
  order: 1,
  label: 'B',
  distanceM: 400,
  depthM: 20,
  headingDeg: 0,
);

DpvMission _mission({
  MissionEnvironment environment = MissionEnvironment.openWater,
  ShoreExit? shore,
  double? limit,
  double walkSpeed = 0.8,
  CurrentVector? current,
}) => DpvMission(
  legs: [
    _l1,
    _l2.copyWith(shoreExit: shore),
  ],
  team: [_member('a', 0), _member('b', 1)],
  environment: environment,
  walkSpeedMps: walkSpeed,
  surfaceSwimLimitM: limit,
  defaultCurrent: current,
);

void main() {
  const service = MissionScenarioService();

  group('underwater exits by environment', () {
    test('open water swims straight home', () {
      final exit = service.evaluate(
        plan: _plan(),
        mission: _mission(),
        waypointIndex: 1,
        failedMemberId: 'b',
        mode: MissionExitMode.swim,
      );
      expect(exit.exitBottomSeconds, 2500);
      expect(exit.blockedByCurrent, isFalse);
    });

    test('an overhead retraces the route', () {
      final exit = service.evaluate(
        plan: _plan(),
        mission: _mission(environment: MissionEnvironment.overhead),
        waypointIndex: 1,
        failedMemberId: 'b',
        mode: MissionExitMode.swim,
      );
      expect(exit.exitBottomSeconds, 3500);
    });

    test('an open-water tow goes straight home at tow speed', () {
      final exit = service.evaluate(
        plan: _plan(),
        mission: _mission(),
        waypointIndex: 1,
        failedMemberId: 'b',
        mode: MissionExitMode.tow,
        towerId: 'a',
      );
      expect(exit.towerId, 'a');
      expect(exit.exitBottomSeconds, 1667);
    });

    test('evaluate refuses the surface mode', () {
      expect(
        () => service.evaluate(
          plan: _plan(),
          mission: _mission(),
          waypointIndex: 1,
          failedMemberId: 'b',
          mode: MissionExitMode.surface,
        ),
        throwsArgumentError,
      );
    });
  });

  group('surface exit', () {
    ExitOutcome surface(DpvMission mission, {int waypoint = 1}) =>
        service.evaluateSurface(
          plan: _plan(),
          mission: mission,
          waypointIndex: waypoint,
        );

    test('without a shore exit it swims straight to the entry', () {
      final exit = surface(_mission());
      expect(exit.mode, MissionExitMode.surface);
      expect(exit.exitBottomSeconds, 0);
      expect(exit.ttsSeconds, greaterThan(0));
      expect(exit.surfaceSwimM, closeTo(500, 1e-6));
      expect(exit.walkM, 0);
      expect(exit.viaShore, isFalse);
      expect(exit.surfaceSeconds, 2500);
      expect(exit.feasible, isTrue);
      expect(exit.exitLitersByMember.keys, containsAll(['a', 'b']));
    });

    test('a shore exit and a walk win when they are faster', () {
      final exit = surface(
        _mission(shore: const ShoreExit(surfaceSwimM: 100, walkM: 300)),
      );
      expect(exit.viaShore, isTrue);
      expect(exit.surfaceSwimM, 100);
      expect(exit.walkM, 300);
      expect(exit.surfaceSeconds, 875);
    });

    test('a limit no route meets makes the surface exit infeasible', () {
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 300),
          limit: 50,
        ),
      );
      expect(exit.surfaceLimitExceeded, isTrue);
      expect(exit.feasible, isFalse);
      expect(exit.viaShore, isTrue, reason: 'still the fastest route');
    });

    test('a limit picks the route within it even when it is slower', () {
      // Direct 500 m swim: 2500 s. Shore: 100 m swim + 3000 m walk:
      // 500 + 3750 = 4250 s. Only the shore swim is within 200 m.
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 3000),
          limit: 200,
        ),
      );
      expect(exit.viaShore, isTrue);
      expect(exit.surfaceSeconds, 4250);
      expect(exit.feasible, isTrue);
    });

    test('a walk with no walking speed drops the shore route', () {
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 300),
          walkSpeed: 0,
        ),
      );
      expect(exit.viaShore, isFalse);
      expect(exit.surfaceSeconds, 2500);
    });

    test('a shore with no walk needs no walking speed', () {
      final exit = surface(
        _mission(
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 0),
          walkSpeed: 0,
        ),
      );
      expect(exit.viaShore, isTrue);
      expect(exit.surfaceSeconds, 500);
    });

    // The bearing home from waypoint 1 is 216.87 degrees (see the plan).
    test('a current the swimmer cannot beat closes the surface swim home', () {
      final exit = surface(
        _mission(
          current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 36.8699),
        ),
      );
      expect(exit.blockedByCurrent, isTrue);
      expect(exit.feasible, isFalse);
    });

    test('a current behind the swimmer speeds the surface swim home', () {
      // 0.2 m/s swim + 0.1 m/s current home: 500 m / 0.3 m/s = 1666.7 s.
      final exit = surface(
        _mission(
          current: const CurrentVector(speedMps: 0.1, setsTowardDeg: 216.8699),
        ),
      );
      expect(exit.viaShore, isFalse);
      expect(exit.surfaceSeconds, 1667);
    });

    test('a shore route, whose bearing is unknown, takes the worst case', () {
      // Worst case 0.2 - 0.1 = 0.1 m/s: 100 m in 1000 s, then 300 m of
      // walk at 0.8 m/s in 375 s; 1375 s beats the 1667 s swim home.
      final exit = surface(
        _mission(
          current: const CurrentVector(speedMps: 0.1, setsTowardDeg: 216.8699),
          shore: const ShoreExit(surfaceSwimM: 100, walkM: 300),
        ),
      );
      expect(exit.viaShore, isTrue);
      expect(exit.surfaceSeconds, 1375);
    });

    test('the surface swim feels the waypoint leg own current first', () {
      // A strong local current against the swim home beats a light default
      // setting toward home: the swim is closed.
      final mission = DpvMission(
        legs: [
          _l1,
          _l2.copyWith(
            current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 36.8699),
          ),
        ],
        team: [_member('a', 0), _member('b', 1)],
        environment: MissionEnvironment.openWater,
        defaultCurrent: const CurrentVector(
          speedMps: 0.05,
          setsTowardDeg: 216.8699,
        ),
      );
      expect(surface(mission).blockedByCurrent, isTrue);
    });

    test('a route that ends at the entry has nothing to swim', () {
      final mission = DpvMission(
        legs: const [
          MissionLeg(
            id: 'out',
            order: 0,
            label: 'A',
            distanceM: 200,
            depthM: 20,
            headingDeg: 0,
          ),
          MissionLeg(
            id: 'back',
            order: 1,
            label: 'B',
            distanceM: 200,
            depthM: 20,
            headingDeg: 180,
          ),
        ],
        team: [_member('a', 0)],
        environment: MissionEnvironment.openWater,
      );
      final exit = surface(mission);
      expect(exit.surfaceSeconds, 0);
      expect(exit.surfaceSwimM, closeTo(0, 1e-6));
      expect(exit.feasible, isTrue);
      final swim = service.evaluate(
        plan: _plan(),
        mission: mission,
        waypointIndex: 1,
        failedMemberId: 'a',
        mode: MissionExitMode.swim,
      );
      expect(swim.exitBottomSeconds, 0);
    });
  });

  test('the overhead time to a safe surface grows with distance in', () {
    final mission = _mission(environment: MissionEnvironment.overhead);
    final t0 = service.overheadSafeSurfaceSeconds(
      plan: _plan(),
      mission: mission,
      waypointIndex: 0,
    );
    final t1 = service.overheadSafeSurfaceSeconds(
      plan: _plan(),
      mission: mission,
      waypointIndex: 1,
    );
    // The way out at cruise alone is 600 s from waypoint 0 and 1400 s from
    // waypoint 1; the ascent comes on top.
    expect(t0, greaterThan(600));
    expect(t1, greaterThan(1400));
  });
}
