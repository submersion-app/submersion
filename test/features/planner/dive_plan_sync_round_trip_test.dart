import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../helpers/fake_cloud_storage_provider.dart';
import '../../helpers/sync_test_helpers.dart';
import '../../helpers/test_database.dart';

void main() {
  group('dive plan sync serialization', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    const gas = GasMix(o2: 32);
    const tank = DiveTank(
      id: 'tank-1',
      name: 'Back gas',
      volume: 11.1,
      startPressure: 200.0,
      gasMix: gas,
    );

    DivePlan plan() => DivePlan(
      id: 'plan-1',
      name: 'Sync plan',
      gfLow: 40,
      gfHigh: 80,
      mode: PlanMode.oc,
      tanks: const [tank],
      segments: [
        PlanSegment.bottom(
          id: 'seg-1',
          depth: 30,
          durationMinutes: 20,
          tankId: 'tank-1',
          gasMix: gas,
        ),
      ],
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );

    test('export includes the plan, tank, and segment rows', () async {
      await DivePlanRepository().savePlan(plan());
      final serializer = SyncDataSerializer();

      final changeset = await serializer.exportChangeset(
        deviceId: 'device-a',
        hlcWatermark: null,
        deletions: const [],
      );

      expect(changeset.data.divePlans.map((r) => r['id']), contains('plan-1'));
      expect(
        changeset.data.divePlanTanks.map((r) => r['id']),
        contains('tank-1'),
      );
      expect(
        changeset.data.divePlanSegments.map((r) => r['id']),
        contains('seg-1'),
      );
      // Field values survive the toJson export.
      final planRow = changeset.data.divePlans.firstWhere(
        (r) => r['id'] == 'plan-1',
      );
      expect(planRow['name'], 'Sync plan');
      expect(planRow['gfLow'], 40);
    });

    test(
      'exported rows re-import through upsertRecord and fetchRecord',
      () async {
        await DivePlanRepository().savePlan(plan());
        final serializer = SyncDataSerializer();
        final changeset = await serializer.exportChangeset(
          deviceId: 'device-a',
          hlcWatermark: null,
          deletions: const [],
        );
        final planRow = changeset.data.divePlans.firstWhere(
          (r) => r['id'] == 'plan-1',
        );
        final tankRow = changeset.data.divePlanTanks.firstWhere(
          (r) => r['id'] == 'tank-1',
        );
        final segmentRow = changeset.data.divePlanSegments.firstWhere(
          (r) => r['id'] == 'seg-1',
        );

        // Wipe the tables and re-apply as if received from a peer.
        await serializer.deleteRecord('divePlanSegments', 'seg-1');
        await serializer.deleteRecord('divePlanTanks', 'tank-1');
        await serializer.deleteRecord('divePlans', 'plan-1');
        expect(await serializer.fetchRecord('divePlans', 'plan-1'), isNull);

        await serializer.upsertRecord('divePlans', planRow);
        await serializer.upsertRecord('divePlanTanks', tankRow);
        await serializer.upsertRecord('divePlanSegments', segmentRow);

        expect(
          (await serializer.fetchRecord('divePlans', 'plan-1'))?['name'],
          'Sync plan',
        );
        expect(
          await serializer.fetchRecord('divePlanTanks', 'tank-1'),
          isNotNull,
        );
        expect(
          await serializer.fetchRecord('divePlanSegments', 'seg-1'),
          isNotNull,
        );

        // And the aggregate rebuilds from the re-imported rows.
        final reloaded = await DivePlanRepository().getPlan('plan-1');
        expect(reloaded, isNotNull);
        expect(reloaded!.tanks, hasLength(1));
        expect(reloaded.segments, hasLength(1));
      },
    );

    test('a plan created on device A is restored on device B', () async {
      final cloud = FakeCloudStorageProvider();
      SyncService buildService() => SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );

      // Device A: seed a plan and push (exercises the full export pipeline).
      await DivePlanRepository().savePlan(plan());
      final push = await buildService().performSync();
      expect(push.isSuccess, isTrue, reason: 'device A push: ${push.message}');

      // Impersonate a fresh device B and pull (exercises fetch/upsert/merge
      // batch paths for the plan tables).
      await DivePlanRepository().deletePlan('plan-1');
      await impersonateFreshDevice();
      expect(await DivePlanRepository().getPlan('plan-1'), isNull);

      final pull = await buildService().performSync();
      expect(pull.isSuccess, isTrue, reason: 'device B pull: ${pull.message}');

      final restored = await DivePlanRepository().getPlan('plan-1');
      expect(
        restored,
        isNotNull,
        reason: 'plan did not propagate A -> B through the round-trip',
      );
      expect(restored!.name, 'Sync plan');
      expect(restored.tanks, hasLength(1));
      expect(restored.segments, hasLength(1));
    });
  });
}
