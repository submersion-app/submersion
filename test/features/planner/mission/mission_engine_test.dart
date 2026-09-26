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
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({double tankLiters = 24, double startBar = 200}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'Engine',
      gfLow: 40,
      gfHigh: 80,
      descentRate: 18,
      ascentRate: 9,
      sacBottom: 15,
      reservePressure: 50,
      salinityPpt: DiveEnvironment.salinityPptFromDensity(
        DiveEnvironment.en13319Density,
      ),
      tanks: [
        DiveTank(
          id: 'back',
          volume: tankLiters,
          startPressure: startBar,
          gasMix: _air,
          role: TankRole.backGas,
        ),
      ],
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

MissionMember _member(
  String id,
  int order, {
  double sac = 15,
  double speed = 0.5,
  int burn = 7200,
}) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: sac,
  swimSpeedMps: 0.2,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: speed,
    burnTimeSeconds: burn,
  ),
);

MissionLeg _leg(
  String id,
  int order, {
  double distance = 500,
  double depth = 20,
  CurrentVector? current,
}) => MissionLeg(
  id: id,
  order: order,
  label: id,
  distanceM: distance,
  depthM: depth,
  headingDeg: 0,
  current: current,
);

/// A scenario service whose every failure evaluation throws, standing in for
/// a plan the engine cannot schedule.
class _ThrowingScenarios extends MissionScenarioService {
  const _ThrowingScenarios();

  @override
  ExitOutcome evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
    MissionProfile? outbound,
  }) => throw StateError('unschedulable');
}

void main() {
  const engine = MissionEngine();

  group('validation', () {
    test('an empty team is blocking and computes nothing', () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(legs: [_leg('L1', 0)]),
      );
      expect(outcome.isBlocked, isTrue);
      expect(outcome.issues.single.type, MissionIssueType.emptyTeam);
      expect(outcome.segments, isEmpty);
    });

    test('an empty route is blocking', () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(team: [_member('a', 0)]),
      );
      expect(outcome.issues.single.type, MissionIssueType.emptyRoute);
    });

    test('a scooter without a speed and a member without SAC are named', () {
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(
          legs: [_leg('L1', 0)],
          team: [_member('a', 0, speed: 0), _member('b', 1, sac: 0)],
        ),
      );
      expect(outcome.issues.map((i) => (i.type, i.memberId)).toSet(), {
        (MissionIssueType.scooterUnspecified, 'a'),
        (MissionIssueType.memberSacUnset, 'b'),
      });
      expect(outcome.isBlocked, isTrue);
    });
  });

  group('route', () {
    test(
      'the round trip segments and leg outcomes come from the cruise speed',
      () {
        final outcome = engine.compute(
          plan: _plan(tankLiters: 40, startBar: 230),
          mission: DpvMission(
            legs: [_leg('L1', 0), _leg('L2', 1, depth: 30)],
            team: [_member('a', 0), _member('b', 1, speed: 0.9)],
          ),
        );
        expect(outcome.cruiseSpeedMps, 0.5);
        expect(
          outcome.members.firstWhere((m) => m.memberId == 'a').setsCruiseSpeed,
          isTrue,
        );
        expect(
          outcome.members.firstWhere((m) => m.memberId == 'b').setsCruiseSpeed,
          isFalse,
        );
        expect(outcome.segments.map((s) => s.id).toList(), [
          'mission-out-travel-L1',
          'mission-out-L1',
          'mission-out-travel-L2',
          'mission-out-L2',
          'mission-ret-L2',
          'mission-ret-travel-L1',
          'mission-ret-L1',
        ]);
        expect(outcome.legs.map((l) => l.legId).toList(), ['L1', 'L2']);
        expect(outcome.legs.first.outboundSeconds, 1000);
        expect(outcome.legs.first.returnSeconds, 1000);
        expect(outcome.waypoints.map((w) => w.cumulativeDistanceM).toList(), [
          500,
          1000,
        ]);
        expect(outcome.waypoints.map((w) => w.arrivalRuntimeSeconds).toList(), [
          1067,
          2100,
        ]);
      },
    );

    test('an untraversable leg blocks and cuts the route before it', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [
            _leg('L1', 0),
            _leg(
              'L2',
              1,
              current: const CurrentVector(speedMps: 0.5, setsTowardDeg: 0),
            ),
            _leg('L3', 2),
          ],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      final issue = outcome.issues.singleWhere(
        (i) => i.type == MissionIssueType.untraversableLeg,
      );
      expect(issue.legId, 'L2');
      expect(
        issue.outbound,
        isFalse,
        reason: 'the return is the blocked direction',
      );
      expect(outcome.isBlocked, isTrue);
      expect(outcome.legs.map((l) => l.legId).toList(), ['L1']);
      expect(outcome.waypoints, hasLength(1));
    });
  });

  group('failure management', () {
    test('a generous plan survives every waypoint with no constraint', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [_leg('L1', 0, distance: 200), _leg('L2', 1, distance: 200)],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      expect(outcome.waypoints.every((w) => w.survivable), isTrue);
      expect(outcome.abandonmentIndex, 1);
      expect(outcome.constraint, isNull);
      for (final member in outcome.members) {
        expect(member.bindingFactor, isNull, reason: member.memberId);
        expect(
          member.turnPressureBar,
          greaterThan(50),
          reason: member.memberId,
        );
      }
    });

    test('a tiny tank makes the first waypoint unsurvivable on own gas', () {
      final outcome = engine.compute(
        plan: _plan(tankLiters: 3),
        mission: DpvMission(
          legs: [_leg('L1', 0)],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      expect(outcome.waypoints.single.survivable, isFalse);
      expect(outcome.abandonmentIndex, isNull);
      expect(outcome.constraint, isNotNull);
      expect(outcome.constraint!.factor, MissionBindingFactor.ownGas);
      expect(outcome.constraint!.waypointIndex, 0);
      expect(outcome.members.every((m) => m.turnPressureBar == null), isTrue);
    });

    test('a current that closes every exit binds as blocked by current', () {
      // 0.3 m/s setting toward 0 on a heading of 0: the team makes 0.2 m/s
      // home on scooters, a tow at 0.3 - 0.3 = 0 makes none, and a swim at
      // 0.2 makes none. Every failure is unsurvivable and blocked by current.
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [
            _leg(
              'L1',
              0,
              distance: 200,
              current: const CurrentVector(speedMps: 0.3, setsTowardDeg: 0),
            ),
          ],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      final b = outcome.waypoints.single.members.firstWhere(
        (m) => m.memberId == 'b',
      );
      expect(b.swim.blockedByCurrent, isTrue);
      expect(b.tow!.blockedByCurrent, isTrue);
      expect(b.survivable, isFalse);
      expect(outcome.constraint!.factor, MissionBindingFactor.blockedByCurrent);
    });

    test('a scenario that throws is reported and counted as no way out', () {
      final outcome = const MissionEngine(scenarios: _ThrowingScenarios())
          .compute(
            plan: _plan(tankLiters: 40, startBar: 230),
            mission: DpvMission(
              legs: [_leg('L1', 0, distance: 200)],
              team: [_member('a', 0), _member('b', 1)],
            ),
          );
      final failed = outcome.issues
          .where((i) => i.type == MissionIssueType.scenarioFailed)
          .toList();
      // Two members, one swim and one tow each.
      expect(failed, hasLength(4));
      expect(
        failed.every((i) => i.severity == MissionIssueSeverity.warning),
        isTrue,
      );
      expect(failed.map((i) => i.legId).toSet(), {'L1'});
      expect(outcome.waypoints.single.survivable, isFalse);
      expect(outcome.abandonmentIndex, isNull);
    });

    test('a feasible tower is preferred over an earlier infeasible one', () {
      // a would burn 20x its rate towing, so only b can tow c out.
      final heavyTower = _member('a', 0);
      final outcome = engine.compute(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: DpvMission(
          legs: [_leg('L1', 0, distance: 200)],
          team: [
            heavyTower.copyWith(
              scooter: heavyTower.scooter.copyWith(towBurnFactor: 20),
            ),
            _member('b', 1),
            _member('c', 2),
          ],
        ),
      );
      final c = outcome.waypoints.single.members.firstWhere(
        (m) => m.memberId == 'c',
      );
      expect(c.tow!.towerId, 'b');
      expect(c.tow!.feasible, isTrue);
    });

    test('the abandonment point is the last survivable waypoint', () {
      // 24 L at 200 bar (about 3460 L above reserve): a tow out from 200 m
      // needs about 1650 L all in, from 600 m about 4700 L.
      final outcome = engine.compute(
        plan: _plan(),
        mission: DpvMission(
          legs: [
            _leg('L1', 0, distance: 200),
            _leg('L2', 1, distance: 200),
            _leg('L3', 2, distance: 200),
          ],
          team: [_member('a', 0), _member('b', 1)],
        ),
      );
      final survivable = outcome.waypoints.map((w) => w.survivable).toList();
      expect(survivable.first, isTrue);
      expect(survivable.last, isFalse);
      expect(outcome.abandonmentIndex, survivable.lastIndexOf(true));
      expect(outcome.constraint!.waypointIndex, survivable.indexOf(false));
    });

    test(
      'the swim needs more than the tow, so the tow is the reported best exit',
      () {
        final outcome = engine.compute(
          plan: _plan(tankLiters: 40, startBar: 230),
          mission: DpvMission(
            legs: [_leg('L1', 0)],
            team: [_member('a', 0), _member('b', 1)],
          ),
        );
        final b = outcome.waypoints.single.members.firstWhere(
          (m) => m.memberId == 'b',
        );
        expect(b.tow!.towerId, 'a');
        expect(b.tow!.exitSeconds, lessThan(b.swim.exitSeconds));
        expect(b.gasRemainingBar, lessThan(230));
      },
    );

    test(
      'the constraint names the battery-limited member, not the slowest or thirstiest',
      () {
        final outcome = engine.compute(
          plan: _plan(tankLiters: 40, startBar: 230),
          mission: DpvMission(
            legs: [
              _leg('L1', 0, distance: 400, depth: 15),
              _leg('L2', 1, distance: 400, depth: 15),
            ],
            team: [
              _member('a', 0, sac: 25, speed: 0.9),
              _member('b', 1, speed: 0.7, burn: 2400),
              _member('c', 2, speed: 0.4),
            ],
          ),
        );
        expect(outcome.cruiseSpeedMps, 0.4);
        expect(
          outcome.members.firstWhere((m) => m.memberId == 'c').setsCruiseSpeed,
          isTrue,
        );
        expect(
          outcome.constraint,
          const MissionConstraint(
            memberId: 'b',
            factor: MissionBindingFactor.battery,
            waypointIndex: 0,
          ),
        );
        final b = outcome.members.firstWhere((m) => m.memberId == 'b');
        expect(b.batteryRoundTripFraction, greaterThan(2 / 3));
        // a has the highest SAC and does bind, on own gas at the second
        // waypoint, but b's battery binds first.
        final a = outcome.members.firstWhere((m) => m.memberId == 'a');
        expect(a.bindingWaypointIndex ?? 99, greaterThan(0));
      },
    );
  });
}
