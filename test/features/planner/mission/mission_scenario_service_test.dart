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
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({double tankLiters = 24, double startBar = 200}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'Scenario',
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
  int burn = 7200,
  double speed = 0.5,
}) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  swimSpeedMps: 0.2,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: speed,
    burnTimeSeconds: burn,
  ),
);

const _leg = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 0,
);

DpvMission _mission({List<MissionMember>? team, MissionLeg leg = _leg}) =>
    DpvMission(legs: [leg], team: team ?? [_member('a', 0), _member('b', 1)]);

void main() {
  const service = MissionScenarioService();

  test('a swim exit covers the leg at the slowest swim speed with no burn', () {
    final exit = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    expect(exit.mode, MissionExitMode.swim);
    expect(exit.towerId, isNull);
    expect(exit.exitBottomSeconds, 1500);
    expect(exit.ttsSeconds, greaterThan(0));
    expect(exit.batteryShortfallMemberIds, isEmpty);
    expect(exit.exitLitersByMember.keys, containsAll(['a', 'b']));
  });

  test('the failed member breathes stressed SAC on the swim out', () {
    final exit = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    // Same tank, same schedule: only the SAC differs, 37.5 versus 15 on the
    // bottom rows, so b's exit gas is well above a's.
    expect(
      exit.exitLitersByMember['b']!,
      greaterThan(exit.exitLitersByMember['a']! * 2),
    );
  });

  test('a tow exit is faster than a swim and needs less gas', () {
    final swim = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    final tow = service.evaluate(
      plan: _plan(),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.tow,
      towerId: 'a',
    );
    expect(tow.towerId, 'a');
    expect(tow.exitBottomSeconds, 1000);
    expect(tow.exitBottomSeconds, lessThan(swim.exitBottomSeconds));
    expect(
      tow.exitLitersByMember['b']!,
      lessThan(swim.exitLitersByMember['b']!),
    );
  });

  test('a tower without battery for the tow is a battery shortfall', () {
    // Outbound 667 s plus 1000 s towing at 1.5x on a 3000 s battery:
    // 667/3000 + 1000*1.5/3000 = 0.72, past the two-thirds allowed.
    final tow = service.evaluate(
      plan: _plan(),
      mission: _mission(team: [_member('a', 0, burn: 3000), _member('b', 1)]),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.tow,
      towerId: 'a',
    );
    expect(tow.batteryShortfallMemberIds, {'a'});
    expect(tow.feasible, isFalse);
  });

  test('the tower is charged the tow rate for the exit, not cruise on top', () {
    // Outbound 667 s powered, then 1000 s towing at 1.5x: 2167 s of rated
    // burn. Two thirds of 3300 s is 2200 s, so the tower is within reserve.
    // Charging cruise as well (667 + 1000 + 1500 = 3167 s) would fail it,
    // and 3200 s (2133 s allowed) must fail on the correct charge alone.
    ExitOutcome tow(int towerBurn) => service.evaluate(
      plan: _plan(tankLiters: 40, startBar: 230),
      mission: _mission(
        team: [
          _member('a', 0, burn: towerBurn),
          _member('b', 1),
        ],
      ),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.tow,
      towerId: 'a',
    );
    expect(tow(3300).batteryShortfallMemberIds, isEmpty);
    expect(tow(3200).batteryShortfallMemberIds, {'a'});
  });

  test('a tank too small for the exit is a gas shortfall for that member', () {
    // 3 L at 200 bar is 600 L; the outbound is about 483 L and the swim
    // out adds over 1100 L for either member, so both run out.
    final swim = service.evaluate(
      plan: _plan(tankLiters: 3),
      mission: _mission(),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    expect(swim.gasShortfallMemberIds, {'a', 'b'});
    expect(swim.feasible, isFalse);
  });

  test('a generous tank and battery make both exits feasible', () {
    for (final mode in [MissionExitMode.swim, MissionExitMode.tow]) {
      final exit = service.evaluate(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: _mission(),
        waypointIndex: 0,
        failedMemberId: 'b',
        mode: mode,
        towerId: mode == MissionExitMode.tow ? 'a' : null,
      );
      expect(exit.feasible, isTrue, reason: '$mode');
    }
  });

  test(
    'a current a swim cannot beat blocks the exit without running the engine',
    () {
      // 0.3 m/s setting toward 0 on a heading of 0: the scooters make 0.2 m/s
      // on the way back, but a 0.2 m/s swim makes no headway at all.
      const leg = MissionLeg(
        id: 'L1',
        order: 0,
        label: 'T',
        distanceM: 300,
        depthM: 20,
        headingDeg: 0,
        current: CurrentVector(speedMps: 0.3, setsTowardDeg: 0),
      );
      final swim = service.evaluate(
        plan: _plan(tankLiters: 40, startBar: 230),
        mission: _mission(leg: leg),
        waypointIndex: 0,
        failedMemberId: 'b',
        mode: MissionExitMode.swim,
      );
      expect(swim.blockedByCurrent, isTrue);
      expect(swim.feasible, isFalse);
      expect(swim.exitLitersByMember, isEmpty);
    },
  );

  test('the tow speed is capped by the slowest other running scooter', () {
    final mission = _mission(
      team: [
        _member('a', 0, speed: 1.0),
        _member('b', 1),
        _member('c', 2, speed: 0.4),
      ],
    );
    // a tows b: 1.0 * 0.6 = 0.6, but c can only make 0.4.
    expect(
      service.towSpeedMps(mission: mission, failedMemberId: 'b', towerId: 'a'),
      closeTo(0.4, 1e-9),
    );
    // c tows b: 0.4 * 0.6 = 0.24, a keeps up easily.
    expect(
      service.towSpeedMps(mission: mission, failedMemberId: 'b', towerId: 'c'),
      closeTo(0.24, 1e-9),
    );
  });
}
