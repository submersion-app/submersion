import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/planner/data/repositories/dive_plan_mission_rows.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

const _member = MissionMember(
  id: 'm1',
  order: 0,
  displayName: 'Sam',
  buddyId: 'buddy-1',
  sacBottom: 16,
  swimSpeedMps: 0.25,
  scooter: ScooterSpec(
    equipmentId: 'eq-1',
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
    towSpeedFactor: 0.55,
    towBurnFactor: 1.7,
  ),
);

const _leg = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
  current: CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
);

void main() {
  test('the mission companion uses the plan id as its id', () {
    const mission = DpvMission(
      batteryReserveFraction: 0.4,
      defaultCurrent: CurrentVector(speedMps: 0.1, setsTowardDeg: 180),
    );
    final c = DivePlanMissionRows.mission('plan-1', mission, 1000);
    expect(c.id.value, 'plan-1');
    expect(c.planId.value, 'plan-1');
    expect(c.batteryReserveFraction.value, 0.4);
    expect(c.defaultCurrentSpeedMps.value, 0.1);
    expect(c.defaultCurrentSetsTowardDeg.value, 180);
    expect(c.createdAt.value, 1000);
    expect(c.updatedAt.value, 1000);
  });

  test('an existing createdAt survives, updatedAt moves', () {
    final c = DivePlanMissionRows.leg('plan-1', _leg, 2, 5000, createdAt: 10);
    expect(c.createdAt.value, 10);
    expect(c.updatedAt.value, 5000);
    expect(c.sortOrder.value, 2);
  });

  test('rows round-trip back to the same mission', () {
    const mission = DpvMission(
      legs: [_leg],
      team: [_member],
      batteryReserveFraction: 0.25,
    );
    const missionRow = db.DivePlanMission(
      id: 'plan-1',
      planId: 'plan-1',
      batteryReserveFraction: 0.25,
      environment: 'overhead',
      walkSpeedMps: 0.8,
      createdAt: 1,
      updatedAt: 1,
    );
    const legRow = db.DivePlanMissionLeg(
      id: 'L1',
      planId: 'plan-1',
      sortOrder: 0,
      label: 'T',
      distanceM: 300,
      depthM: 20,
      headingDeg: 90,
      currentSpeedMps: 0.2,
      currentSetsTowardDeg: 45,
      createdAt: 1,
      updatedAt: 1,
    );
    const memberRow = db.DivePlanMissionMember(
      id: 'm1',
      planId: 'plan-1',
      sortOrder: 0,
      displayName: 'Sam',
      buddyId: 'buddy-1',
      sacBottom: 16,
      swimSpeedMps: 0.25,
      scooterEquipmentId: 'eq-1',
      scooterName: 'Blacktip',
      scooterSpeedMps: 0.9,
      scooterBurnSeconds: 5400,
      towSpeedFactor: 0.55,
      towBurnFactor: 1.7,
      createdAt: 1,
      updatedAt: 1,
    );
    expect(
      DivePlanMissionRows.toMission(missionRow, [legRow], [memberRow]),
      mission,
    );
  });

  test('legs and members come back in sort order with order renumbered', () {
    db.DivePlanMissionLeg leg(String id, int sort) => db.DivePlanMissionLeg(
      id: id,
      planId: 'p',
      sortOrder: sort,
      label: id,
      distanceM: 100,
      depthM: 10,
      headingDeg: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final mission = DivePlanMissionRows.toMission(
      const db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'overhead',
        walkSpeedMps: 0.8,
        createdAt: 1,
        updatedAt: 1,
      ),
      [leg('b', 7), leg('a', 3)],
      const [],
    );
    expect(mission.legs.map((l) => l.id), ['a', 'b']);
    expect(mission.legs.map((l) => l.order), [0, 1]);
    expect(mission.defaultCurrent, isNull);
  });

  test('the open-water fields round-trip through the rows', () {
    const mission = DpvMission(
      environment: MissionEnvironment.openWater,
      walkSpeedMps: 1.1,
      surfaceSwimLimitM: 250,
    );
    final c = DivePlanMissionRows.mission('p', mission, 1);
    expect(c.environment.value, 'openWater');
    expect(c.walkSpeedMps.value, 1.1);
    expect(c.surfaceSwimLimitM.value, 250);
    const leg = MissionLeg(
      id: 'L1',
      order: 0,
      label: 'T',
      distanceM: 100,
      depthM: 10,
      headingDeg: 0,
      shoreExit: ShoreExit(surfaceSwimM: 120, walkM: 400),
    );
    final l = DivePlanMissionRows.leg('p', leg, 0, 1);
    expect(l.shoreSwimM.value, 120);
    expect(l.shoreWalkM.value, 400);

    final restored = DivePlanMissionRows.toMission(
      const db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'openWater',
        walkSpeedMps: 1.1,
        surfaceSwimLimitM: 250,
        createdAt: 1,
        updatedAt: 1,
      ),
      [
        const db.DivePlanMissionLeg(
          id: 'L1',
          planId: 'p',
          sortOrder: 0,
          label: 'T',
          distanceM: 100,
          depthM: 10,
          headingDeg: 0,
          shoreSwimM: 120,
          shoreWalkM: 400,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      const [],
    );
    expect(restored.environment, MissionEnvironment.openWater);
    expect(restored.walkSpeedMps, 1.1);
    expect(restored.surfaceSwimLimitM, 250);
    expect(
      restored.legs.single.shoreExit,
      const ShoreExit(surfaceSwimM: 120, walkM: 400),
    );
  });

  test('an unknown environment name reads as overhead', () {
    final mission = DivePlanMissionRows.toMission(
      const db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'cave2030',
        walkSpeedMps: 0.8,
        createdAt: 1,
        updatedAt: 1,
      ),
      const [],
      const [],
    );
    expect(mission.environment, MissionEnvironment.overhead);
  });

  test('a half-written current is read as no current', () {
    const legRow = db.DivePlanMissionLeg(
      id: 'L1',
      planId: 'p',
      sortOrder: 0,
      label: 'T',
      distanceM: 100,
      depthM: 10,
      headingDeg: 0,
      currentSpeedMps: 0.3,
      createdAt: 1,
      updatedAt: 1,
    );
    final mission = DivePlanMissionRows.toMission(
      const db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'overhead',
        walkSpeedMps: 0.8,
        createdAt: 1,
        updatedAt: 1,
      ),
      [legRow],
      const [],
    );
    expect(mission.legs.single.current, isNull);
  });
}
