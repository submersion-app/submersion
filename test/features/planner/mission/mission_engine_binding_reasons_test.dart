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
}) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: sac,
  swimSpeedMps: 0.2,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: 0.5,
    burnTimeSeconds: burn,
  ),
);

MissionOutcome _compute(DpvMission mission) =>
    const MissionEngine().compute(plan: _plan(), mission: mission);

MemberOutcome _outcomeOf(MissionOutcome outcome, String id) =>
    outcome.members.firstWhere((m) => m.memberId == id);

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
    // The same 0.25 m/s current over 300 m: the swim is blocked, and the
    // 0.05 m/s tow takes 6000 s, which b's gas cannot cover. The tow's own
    // shortfall is the cause, not the mere failure of the tow.
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
        defaultCurrent: const CurrentVector(speedMps: 0.25, setsTowardDeg: 0),
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
    // 0.25 m/s sets outbound along the 30 m leg: the scooters make 0.25 m/s
    // home, a 0.2 m/s swim makes none, and a 0.3 m/s tow makes 0.05 m/s,
    // so towing takes 600 s. a's 1200 s battery cannot pay 600 s at 1.5x on
    // top of the outbound within a one-third reserve; b's can.
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
        team: [_member('a', 0, burn: 1200), _member('b', 1)],
        defaultCurrent: const CurrentVector(speedMps: 0.25, setsTowardDeg: 0),
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
}
