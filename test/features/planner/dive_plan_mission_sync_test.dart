import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

import '../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  const gas = GasMix(o2: 32);
  const mission = DpvMission(
    legs: [
      MissionLeg(
        id: 'leg-1',
        order: 0,
        label: 'T',
        distanceM: 300,
        depthM: 20,
        headingDeg: 90,
      ),
    ],
    team: [
      MissionMember(
        id: 'member-1',
        order: 0,
        displayName: 'Sam',
        sacBottom: 15,
        scooter: ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    ],
  );

  DivePlan plan() => DivePlan(
    id: 'plan-1',
    name: 'Sync mission',
    gfLow: 40,
    gfHigh: 80,
    tanks: const [
      DiveTank(id: 'tank-1', volume: 11.1, startPressure: 200, gasMix: gas),
    ],
    segments: [
      PlanSegment.hold(
        id: 'seg-1',
        depth: 20,
        durationMinutes: 20,
        tankId: 'tank-1',
        gasMix: gas,
      ),
    ],
    mission: mission,
    createdAt: DateTime(2026, 9, 19),
    updatedAt: DateTime(2026, 9, 19),
  );

  test('export carries the mission, leg and member rows', () async {
    await DivePlanRepository().savePlan(plan());
    final changeset = await SyncDataSerializer().exportChangeset(
      deviceId: 'device-a',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(changeset.data.divePlanMissions.map((r) => r['id']), ['plan-1']);
    expect(changeset.data.divePlanMissionLegs.map((r) => r['id']), ['leg-1']);
    expect(changeset.data.divePlanMissionMembers.map((r) => r['id']), [
      'member-1',
    ]);
    expect(changeset.data.divePlanMissionLegs.single['planId'], 'plan-1');
  });

  test(
    'rows re-import through upsertRecord and read back as the mission',
    () async {
      await DivePlanRepository().savePlan(plan());
      final serializer = SyncDataSerializer();
      final changeset = await serializer.exportChangeset(
        deviceId: 'device-a',
        hlcWatermark: null,
        deletions: const [],
      );
      final missionRow = changeset.data.divePlanMissions.single;
      final legRow = changeset.data.divePlanMissionLegs.single;
      final memberRow = changeset.data.divePlanMissionMembers.single;

      await serializer.deleteRecord('divePlanMissionLegs', 'leg-1');
      await serializer.deleteRecord('divePlanMissionMembers', 'member-1');
      await serializer.deleteRecord('divePlanMissions', 'plan-1');
      expect(
        await serializer.fetchRecord('divePlanMissions', 'plan-1'),
        isNull,
      );

      await serializer.upsertRecord('divePlanMissions', missionRow);
      await serializer.upsertRecord('divePlanMissionLegs', legRow);
      await serializer.upsertRecord('divePlanMissionMembers', memberRow);

      expect((await DivePlanRepository().getPlan('plan-1'))!.mission, mission);
    },
  );

  test('the changeset JSON round-trips the mission lists', () async {
    await DivePlanRepository().savePlan(plan());
    final changeset = await SyncDataSerializer().exportChangeset(
      deviceId: 'device-a',
      hlcWatermark: null,
      deletions: const [],
    );
    final restored = SyncData.fromJson(changeset.data.toJson());
    expect(restored.divePlanMissions, changeset.data.divePlanMissions);
    expect(restored.divePlanMissionLegs, changeset.data.divePlanMissionLegs);
    expect(
      restored.divePlanMissionMembers,
      changeset.data.divePlanMissionMembers,
    );
  });

  test('fetchRecord reads each mission row by its id', () async {
    await DivePlanRepository().savePlan(plan());
    final serializer = SyncDataSerializer();

    final missionRow = await serializer.fetchRecord(
      'divePlanMissions',
      'plan-1',
    );
    final legRow = await serializer.fetchRecord('divePlanMissionLegs', 'leg-1');
    final memberRow = await serializer.fetchRecord(
      'divePlanMissionMembers',
      'member-1',
    );

    expect(missionRow!['planId'], 'plan-1');
    expect(legRow!['label'], 'T');
    expect(legRow['planId'], 'plan-1');
    expect(memberRow!['displayName'], 'Sam');
    expect(memberRow['scooterName'], 'Blacktip');
    expect(
      await serializer.fetchRecord('divePlanMissionLegs', 'missing'),
      isNull,
    );
  });
}
