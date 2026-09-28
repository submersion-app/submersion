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

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Reasons',
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

MissionMember _member(
  String id,
  int order, {
  double sac = 15,
  int burn = 7200,
  double speed = 0.5,
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

MissionOutcome _compute(DpvMission mission) =>
    const MissionEngine().compute(plan: _plan(), mission: mission);

MemberOutcome _outcomeOf(MissionOutcome outcome, String id) =>
    outcome.members.firstWhere((m) => m.memberId == id);

/// Throws from every tow that [_brokenTower] would give; everything else is
/// computed normally.
class _OneTowerThrows extends MissionScenarioService {
  const _OneTowerThrows();

  @override
  ExitOutcome evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
    MissionProfile? outbound,
  }) {
    if (towerId == _brokenTower) throw StateError('unschedulable');
    return super.evaluate(
      plan: plan,
      mission: mission,
      waypointIndex: waypointIndex,
      failedMemberId: failedMemberId,
      mode: mode,
      towerId: towerId,
      outbound: outbound,
    );
  }
}

const _brokenTower = 'a';

/// Throws from every swim; tows and the rest are computed normally.
class _SwimThrows extends MissionScenarioService {
  const _SwimThrows();

  @override
  ExitOutcome evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
    MissionProfile? outbound,
  }) {
    if (mode == MissionExitMode.swim) throw StateError('unschedulable');
    return super.evaluate(
      plan: plan,
      mission: mission,
      waypointIndex: waypointIndex,
      failedMemberId: failedMemberId,
      mode: mode,
      towerId: towerId,
      outbound: outbound,
    );
  }
}

void main() {
  test("a teammate's gas binds a diver who could get out on their own", () {
    // b breathes 100 L/min: every exit from 300 m in runs b out of gas,
    // while a's own gas covers each of them.
    final outcome = _compute(
      DpvMission(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'T',
            distanceM: 300,
            depthM: 20,
            headingDeg: 0,
          ),
        ],
        team: [_member('a', 0), _member('b', 1, sac: 100)],
      ),
    );
    final a = _outcomeOf(outcome, 'a');
    expect(a.bindingFactor, MissionBindingFactor.teamGas);
    expect(a.bindingWaypointIndex, 0);
    expect(_outcomeOf(outcome, 'b').bindingFactor, MissionBindingFactor.ownGas);
  });

  test('a tow that runs the towed diver out of gas binds as own gas', () {
    // A 0.24 m/s current over 300 m: the swim is blocked, and the 0.06 m/s
    // tow (just above the headway floor) takes 5000 s, which b's gas cannot
    // cover. The tow's own shortfall is the cause, not the mere failure of
    // the tow.
    final outcome = _compute(
      DpvMission(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'T',
            distanceM: 300,
            depthM: 20,
            headingDeg: 0,
          ),
        ],
        team: [_member('a', 0), _member('b', 1)],
        defaultCurrent: const CurrentVector(speedMps: 0.24, setsTowardDeg: 0),
      ),
    );
    final b = outcome.waypoints.single.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.swim.blockedByCurrent, isTrue);
    expect(b.tow!.gasShortfallMemberIds, contains('b'));
    expect(_outcomeOf(outcome, 'b').bindingFactor, MissionBindingFactor.ownGas);
  });

  test('a tow that made headway is kept over one the current blocked', () {
    // 0.35 m/s sets outbound along a 30 m leg. The swim (0.2 m/s) and a's
    // tow (0.3 m/s) make no headway home; c's tow (capped at 0.5 m/s by a's
    // scooter) makes 0.15 m/s but c's 300 s battery cannot pay for it. a
    // comes first in the team, yet c's tow is the one that tells why.
    final outcome = _compute(
      DpvMission(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'T',
            distanceM: 30,
            depthM: 20,
            headingDeg: 0,
          ),
        ],
        team: [
          _member('a', 0),
          _member('b', 1),
          const MissionMember(
            id: 'c',
            order: 2,
            displayName: 'c',
            sacBottom: 15,
            swimSpeedMps: 0.2,
            scooter: ScooterSpec(
              name: 'S-c',
              ratedSpeedMps: 1.0,
              burnTimeSeconds: 300,
            ),
          ),
        ],
        defaultCurrent: const CurrentVector(speedMps: 0.35, setsTowardDeg: 0),
      ),
    );
    final b = outcome.waypoints.single.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.tow!.towerId, 'c');
    expect(b.tow!.blockedByCurrent, isFalse);
    expect(
      _outcomeOf(outcome, 'b').bindingFactor,
      MissionBindingFactor.noFeasibleTow,
    );
  });

  test('a tow that makes headway but fails on battery is no feasible tow', () {
    // 0.24 m/s sets outbound along the 30 m leg: the scooters make 0.26 m/s
    // home, a 0.2 m/s swim makes none, and a 0.3 m/s tow makes 0.06 m/s
    // (just above the headway floor), so towing takes 500 s. a's 1100 s
    // battery cannot pay 500 s at 1.5x on top of the outbound within a
    // one-third reserve; b's can.
    final outcome = _compute(
      DpvMission(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'T',
            distanceM: 30,
            depthM: 20,
            headingDeg: 0,
          ),
        ],
        team: [_member('a', 0, burn: 1100), _member('b', 1)],
        defaultCurrent: const CurrentVector(speedMps: 0.24, setsTowardDeg: 0),
      ),
    );
    final b = outcome.waypoints.single.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.swim.blockedByCurrent, isTrue);
    expect(b.tow!.blockedByCurrent, isFalse);
    expect(b.tow!.batteryShortfallMemberIds, {'a'});
    expect(
      outcome.constraint,
      const MissionConstraint(
        memberId: 'b',
        factor: MissionBindingFactor.noFeasibleTow,
        waypointIndex: 0,
      ),
    );
  });

  test('a tow that ran outranks one whose computation failed', () {
    // As in the own-gas case, b's swim is blocked and a tow that runs leaves
    // b short of gas. a's tow of b throws; c's runs. The failed tow reports
    // no time, so it must not win on time and hide c's real cause.
    final outcome = const MissionEngine(scenarios: _OneTowerThrows()).compute(
      plan: _plan(),
      mission: DpvMission(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'T',
            distanceM: 300,
            depthM: 20,
            headingDeg: 0,
          ),
        ],
        team: [_member('a', 0), _member('b', 1), _member('c', 2)],
        defaultCurrent: const CurrentVector(speedMps: 0.24, setsTowardDeg: 0),
      ),
    );
    final b = outcome.waypoints.single.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.tow!.failed, isFalse);
    expect(b.tow!.towerId, 'c');
    expect(_outcomeOf(outcome, 'b').bindingFactor, MissionBindingFactor.ownGas);
  });

  test('a tow the current blocked outranks one whose computation failed', () {
    // b's swim is blocked. a's tow of b throws; c's slower scooter tows at
    // 0.4 x 0.6 = 0.24 m/s, which the 0.24 m/s current cancels. The blocked
    // tow is a known cause; the failed one would hide it.
    final outcome = const MissionEngine(scenarios: _OneTowerThrows()).compute(
      plan: _plan(),
      mission: DpvMission(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'T',
            distanceM: 300,
            depthM: 20,
            headingDeg: 0,
          ),
        ],
        team: [_member('a', 0), _member('b', 1), _member('c', 2, speed: 0.4)],
        defaultCurrent: const CurrentVector(speedMps: 0.24, setsTowardDeg: 0),
      ),
    );
    final b = outcome.waypoints.single.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.tow!.towerId, 'c');
    expect(b.tow!.blockedByCurrent, isTrue);
    expect(
      _outcomeOf(outcome, 'b').bindingFactor,
      MissionBindingFactor.blockedByCurrent,
    );
  });

  test('a tow that ran and failed is named over a swim that threw', () {
    // The battery case: a's tow of b makes headway but a's battery cannot
    // pay for it. b's swim computation throws, which says nothing about the
    // water; the tow's failure is known, so it is the reason.
    final outcome = const MissionEngine(scenarios: _SwimThrows()).compute(
      plan: _plan(),
      mission: DpvMission(
        legs: const [
          MissionLeg(
            id: 'L1',
            order: 0,
            label: 'T',
            distanceM: 30,
            depthM: 20,
            headingDeg: 0,
          ),
        ],
        team: [_member('a', 0, burn: 1100), _member('b', 1)],
        defaultCurrent: const CurrentVector(speedMps: 0.24, setsTowardDeg: 0),
      ),
    );
    final b = outcome.waypoints.single.members.firstWhere(
      (m) => m.memberId == 'b',
    );
    expect(b.swim.failed, isTrue);
    expect(b.tow!.batteryShortfallMemberIds, {'a'});
    expect(
      _outcomeOf(outcome, 'b').bindingFactor,
      MissionBindingFactor.noFeasibleTow,
    );
  });
}
