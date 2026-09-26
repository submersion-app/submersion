import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';

const _air = GasMix(o2: 21);

const _back = DiveTank(
  id: 'back',
  volume: 24,
  startPressure: 200,
  gasMix: _air,
  role: TankRole.backGas,
);

domain.DivePlan _plan({
  List<DiveTank> tanks = const [_back],
  domain.PlanMode mode = domain.PlanMode.oc,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Validation',
  gfLow: 40,
  gfHigh: 80,
  mode: mode,
  tanks: tanks,
  createdAt: DateTime(2026, 9, 26),
  updatedAt: DateTime(2026, 9, 26),
);

MissionMember _member({
  double towSpeed = 0.6,
  double towBurn = 1.5,
  double sac = 15,
  double swim = 0.2,
}) => MissionMember(
  id: 'a',
  order: 0,
  displayName: 'a',
  sacBottom: sac,
  swimSpeedMps: swim,
  scooter: ScooterSpec(
    name: 'S',
    ratedSpeedMps: 0.5,
    burnTimeSeconds: 7200,
    towSpeedFactor: towSpeed,
    towBurnFactor: towBurn,
  ),
);

MissionLeg _leg({double distance = 200, double depth = 20}) => MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: distance,
  depthM: depth,
  headingDeg: 0,
);

DpvMission _mission({
  double reserve = 1 / 3,
  MissionMember? member,
  MissionLeg? leg,
}) => DpvMission(
  legs: [leg ?? _leg()],
  team: [member ?? _member()],
  batteryReserveFraction: reserve,
);

List<(MissionIssueType, String?, String?)> _blocking(
  DpvMission mission, {
  domain.DivePlan? plan,
}) => [
  for (final issue
      in const MissionEngine()
          .compute(plan: plan ?? _plan(), mission: mission)
          .issues)
    if (issue.severity == MissionIssueSeverity.blocking)
      (issue.type, issue.legId, issue.memberId),
];

void main() {
  test('a valid mission raises no blocking issue', () {
    expect(_blocking(_mission()), isEmpty);
  });

  group('battery reserve', () {
    for (final reserve in [-1.0, 1.5, double.nan, double.infinity]) {
      test('a reserve of $reserve is refused', () {
        expect(
          _blocking(_mission(reserve: reserve)),
          contains((MissionIssueType.batteryReserveInvalid, null, null)),
        );
      });
    }

    for (final reserve in [0.0, 1.0]) {
      test('a reserve of $reserve is allowed', () {
        expect(
          _blocking(_mission(reserve: reserve)).map((i) => i.$1),
          isNot(contains(MissionIssueType.batteryReserveInvalid)),
        );
      });
    }
  });

  group('tow factors', () {
    for (final (speed, burn) in [(0.6, 0.0), (0.6, -1.0), (0.0, 1.5)]) {
      test('tow speed $speed and burn $burn are refused', () {
        expect(
          _blocking(
            _mission(
              member: _member(towSpeed: speed, towBurn: burn),
            ),
          ),
          contains((MissionIssueType.scooterUnspecified, null, 'a')),
        );
      });
    }
  });

  group('numbers that are not numbers are refused', () {
    // NaN fails every comparison, so a `<= 0` check lets it through and it
    // then makes every gas comparison false: an exit would read feasible.
    for (final sac in [double.nan, double.infinity]) {
      test('a SAC of $sac', () {
        expect(
          _blocking(_mission(member: _member(sac: sac))),
          contains((MissionIssueType.memberSacUnset, null, 'a')),
        );
      });
    }

    test('a swim speed of NaN', () {
      expect(
        _blocking(_mission(member: _member(swim: double.nan))),
        contains((MissionIssueType.memberSwimSpeedUnset, null, 'a')),
      );
    });

    test('a tow burn factor of infinity', () {
      expect(
        _blocking(_mission(member: _member(towBurn: double.infinity))),
        contains((MissionIssueType.scooterUnspecified, null, 'a')),
      );
    });

    DpvMission openWater({
      double? limit,
      double walk = 0.8,
      ShoreExit? shore,
    }) => DpvMission(
      legs: [_leg().copyWith(shoreExit: shore)],
      team: [_member()],
      environment: MissionEnvironment.openWater,
      surfaceSwimLimitM: limit,
      walkSpeedMps: walk,
    );

    for (final (label, mission, legId) in [
      ('a surface swim limit of NaN', openWater(limit: double.nan), null),
      ('a walking speed of NaN', openWater(walk: double.nan), null),
      ('a walking speed of infinity', openWater(walk: double.infinity), null),
      (
        'a shore swim of NaN',
        openWater(shore: const ShoreExit(surfaceSwimM: double.nan, walkM: 0)),
        'L1',
      ),
      (
        'a shore walk of NaN',
        openWater(shore: const ShoreExit(surfaceSwimM: 50, walkM: double.nan)),
        'L1',
      ),
    ]) {
      test(label, () {
        expect(
          _blocking(mission),
          contains((MissionIssueType.openWaterInputInvalid, legId, null)),
        );
      });
    }
  });

  group('legs', () {
    for (final depth in [-5.0, double.nan]) {
      test('a depth of $depth is refused', () {
        expect(
          _blocking(_mission(leg: _leg(depth: depth))),
          contains((MissionIssueType.legDepthInvalid, 'L1', null)),
        );
      });
    }

    test('a distance that is not a number is too short to travel', () {
      expect(
        _blocking(_mission(leg: _leg(distance: double.nan))),
        contains((MissionIssueType.legTooShort, 'L1', null)),
      );
    });
  });

  group('the plan under the mission', () {
    test('a cylinder with no volume or fill cannot prove gas safety', () {
      for (final tank in const [
        DiveTank(id: 'x', startPressure: 200, gasMix: _air),
        DiveTank(id: 'x', volume: 11, gasMix: _air),
      ]) {
        expect(
          _blocking(_mission(), plan: _plan(tanks: [_back, tank])),
          contains((MissionIssueType.tankBudgetUnknown, null, null)),
        );
      }
    });

    test('a rebreather plan is refused: version 1 is open circuit only', () {
      expect(
        _blocking(_mission(), plan: _plan(mode: domain.PlanMode.ccr)),
        contains((MissionIssueType.unsupportedMode, null, null)),
      );
    });

    test('a planned route the plan engine calls not diveable is refused', () {
      // EAN50 at 30 m is a ppO2 of 2.0 bar: critical before any failure.
      final outcome = const MissionEngine().compute(
        plan: _plan(
          tanks: const [
            DiveTank(
              id: 'back',
              volume: 24,
              startPressure: 200,
              gasMix: GasMix(o2: 50),
              role: TankRole.backGas,
            ),
          ],
        ),
        mission: _mission(leg: _leg(depth: 30)),
      );
      expect(outcome.isBlocked, isTrue);
      expect(
        outcome.issues.map((i) => i.type),
        contains(MissionIssueType.planNotDiveable),
      );
    });
  });
}
