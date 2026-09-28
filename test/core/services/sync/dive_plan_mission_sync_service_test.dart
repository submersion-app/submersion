import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// DPV mission rows (issue #2086) applied by a full [SyncService.performSync]
/// from a peer's published base, so the apply order, the parent references
/// and the updated-at handling are exercised, not only the serializer.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

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
        current: CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
      ),
      MissionLeg(
        id: 'leg-2',
        order: 1,
        label: 'Exit',
        distanceM: 120,
        depthM: 12,
        headingDeg: 180,
        shoreExit: ShoreExit(surfaceSwimM: 80, walkM: 200),
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
    batteryReserveFraction: 0.4,
    environment: MissionEnvironment.openWater,
  );

  DivePlan plan() => DivePlan(
    id: 'plan-1',
    name: 'Synced mission',
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

  test("a peer's mission arrives with its plan through performSync", () async {
    // The peer saves the plan and publishes its base.
    await DivePlanRepository().savePlan(plan());
    final payload = await SyncDataSerializer().exportChangeset(
      deviceId: 'peer-dev',
      hlcWatermark: null,
      deletions: const [],
    );
    final cloud = FakeCloudStorageProvider();
    await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

    // This device starts empty. The tearDown closes the receiver; this
    // closes the peer's database.
    final peer = DatabaseService.instance.database;
    addTearDown(peer.close);
    DatabaseService.instance.resetForTesting();
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase.memory()),
    );

    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));

    final received = await DivePlanRepository().getPlan('plan-1');
    expect(received, isNotNull);
    expect(received!.mission, mission);
  });

  test(
    'a mission added after the first publish arrives in a changeset',
    () async {
      // The peer publishes the plan without a mission, then adds one and
      // publishes again, so the mission rows travel in an incremental
      // changeset and are applied in the service's apply order.
      final cloud = FakeCloudStorageProvider();
      await DivePlanRepository().savePlan(plan().copyWith(clearMission: true));
      await publishOwnLog(cloud, 'peer-dev');
      await DivePlanRepository().savePlan(plan());
      await publishOwnLog(cloud, 'peer-dev');

      final peer = DatabaseService.instance.database;
      addTearDown(peer.close);
      DatabaseService.instance.resetForTesting();
      DatabaseService.instance.setTestDatabase(
        AppDatabase(NativeDatabase.memory()),
      );

      final result = await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      ).performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect((await DivePlanRepository().getPlan('plan-1'))!.mission, mission);
    },
  );

  test(
    "a peer's new leg is dropped when this device removed the mission",
    () async {
      // The peer's mission has leg-1 and a leg this device never saw.
      final cloud = FakeCloudStorageProvider();
      final peerMission = mission.copyWith(
        legs: [
          ...mission.legs,
          const MissionLeg(
            id: 'leg-3',
            order: 2,
            label: 'Jump',
            distanceM: 90,
            depthM: 25,
            headingDeg: 270,
          ),
        ],
      );
      await DivePlanRepository().savePlan(
        plan().copyWith(mission: peerMission),
      );
      await publishOwnLog(cloud, 'peer-dev');

      final peer = DatabaseService.instance.database;
      addTearDown(peer.close);
      DatabaseService.instance.resetForTesting();
      DatabaseService.instance.setTestDatabase(
        AppDatabase(NativeDatabase.memory()),
      );

      // This device had the mission, then turned it off: the mission row and
      // its legs and members are tombstoned here, the plan survives.
      await DivePlanRepository().savePlan(plan());
      await DivePlanRepository().savePlan(plan().copyWith(clearMission: true));

      final result = await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      ).performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final receiver = DatabaseService.instance.database;
      final legs = await receiver.select(receiver.divePlanMissionLegs).get();
      expect(legs.map((l) => l.id), isEmpty);
      expect((await DivePlanRepository().getPlan('plan-1'))!.mission, isNull);
    },
  );
}
