import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_member_analysis.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

void main() {
  test('the return from a waypoint excludes the next leg transition', () {
    // L0 300 m at 20 m, then L1 200 m at 30 m, all at 0.5 m/s. The planned
    // return is ret-L1 (400 s), ret-travel-L0 (30 to 20 m at 9 m/min, 67 s),
    // ret-L0 (600 s). From waypoint 0 only ret-L0 is the way back: the
    // 30-to-20 m transition belongs to coming back from L1.
    const legs = [
      MissionLeg(
        id: 'L0',
        order: 0,
        label: 'A',
        distanceM: 300,
        depthM: 20,
        headingDeg: 0,
      ),
      MissionLeg(
        id: 'L1',
        order: 1,
        label: 'B',
        distanceM: 200,
        depthM: 30,
        headingDeg: 0,
      ),
    ];
    final profile = const MissionSegmentBuilder().build(
      plan: domain.DivePlan(
        id: 'p',
        name: 'Return',
        gfLow: 40,
        gfHigh: 80,
        descentRate: 18,
        ascentRate: 9,
        tanks: const [
          DiveTank(
            id: 'back',
            volume: 24,
            startPressure: 200,
            gasMix: GasMix(o2: 21),
            role: TankRole.backGas,
          ),
        ],
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      ),
      mission: const DpvMission(legs: legs),
      throughLegIndex: 1,
      outboundSpeedMps: 0.5,
      exitSpeedMps: 0.5,
    );
    expect(const MissionMemberAnalysis().returnSecondsFrom(legs, profile), [
      600,
      400 + 67 + 600,
    ]);
  });

  test('an exit closed only by oxygen or gas exposure binds as exposure', () {
    const blocked = ExitOutcome(
      mode: MissionExitMode.swim,
      feasible: false,
      exitBottomSeconds: 900,
      ttsSeconds: 300,
      exitLitersByMember: {'a': 900.0},
      notDiveable: true,
    );
    final outcome = const MissionMemberAnalysis().memberOutcome(
      member: const MissionMember(
        id: 'a',
        order: 0,
        displayName: 'a',
        sacBottom: 15,
        scooter: ScooterSpec(
          name: 'S',
          ratedSpeedMps: 0.5,
          burnTimeSeconds: 7200,
        ),
      ),
      mission: const DpvMission(),
      waypoints: const [
        WaypointOutcome(
          index: 0,
          legId: 'L0',
          cumulativeDistanceM: 300,
          arrivalRuntimeSeconds: 667,
          directDistanceHomeM: 300,
          safeSurfaceSeconds: 900,
          members: [
            MemberWaypointOutcome(
              memberId: 'a',
              gasRemainingBar: 180,
              swim: blocked,
              survivable: false,
            ),
          ],
          survivable: false,
        ),
      ],
      abandonment: null,
      roundTripSeconds: 1300,
      returnSecondsFrom: const [600],
      setsCruise: true,
      bottomTank: const DiveTank(
        id: 'back',
        volume: 24,
        startPressure: 200,
        gasMix: GasMix(o2: 21),
      ),
      reserveBar: 50,
      gasModel: GasModel.ideal,
    );
    expect(outcome.bindingFactor, MissionBindingFactor.exposure);
    expect(outcome.bindingWaypointIndex, 0);
  });
}
