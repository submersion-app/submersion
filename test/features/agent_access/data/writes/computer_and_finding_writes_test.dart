import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A dive computer's own settings, and dismissing a safety finding, as the
/// computer page and the dive's safety card keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<void> computer(String id, {bool favorite = false}) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'gear-$id',
            name: 'Computer $id',
            type: 'computer',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: 'Computer $id',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
            isFavorite: Value(favorite),
            equipmentId: Value('gear-$id'),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test(
    'a computer becomes the favourite, listing the one it replaces',
    () async {
      await computer('c1', favorite: true);
      await computer('c2');

      final plan = await h.preview([
        updateOp('dive_computers', 'c2', {
          'is_favorite': true,
          'auto_download_disabled': true,
        }),
      ]);
      expect(plan.items.single.alsoChanges, {'dive_computers': 1});
      await h.apply(plan);

      expect((await h.one('dive_computers', 'c1'))!['is_favorite'], isFalse);
      final c2 = (await h.one('dive_computers', 'c2'))!;
      expect([c2['is_favorite'], c2['auto_download_disabled']], [true, true]);

      final unstar = await h.preview([
        updateOp('dive_computers', 'c2', {'is_favorite': false}),
      ]);
      expect(unstar.items.single.block!.reason, BlockReason.invalidValue);
    },
  );

  test('renaming a computer points to its gear item', () async {
    await computer('c1');

    final plan = await h.preview([
      updateOp('dive_computers', 'c1', {'name': 'Teric'}),
    ]);
    final block = plan.items.single.block!;
    expect(block.reason, BlockReason.notPermitted);
    expect(block.detail, contains('gear-c1'));
    final drop = await h.preview([deleteOp('dive_computers', 'c1')]);
    expect(drop.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('a finding is dismissed and restored', () async {
    await db
        .into(db.diveSafetyReviews)
        .insert(
          DiveSafetyReviewsCompanion.insert(
            diveId: 'd1',
            engineVersion: 1,
            reviewedAt: kSeedTime,
          ),
        );
    await db
        .into(db.diveSafetyFindings)
        .insert(
          DiveSafetyFindingsCompanion.insert(
            id: 'f1',
            diveId: 'd1',
            ruleId: 'rapidAscent',
            severity: 'caution',
            engineVersion: 1,
            createdAt: kSeedTime,
          ),
        );

    final plan = await h.preview([
      updateOp('safety_findings', 'f1', {'dismissed': true}),
    ]);
    expect(plan.items.single.alsoChanges, {'dives': 1});
    await h.apply(plan);
    expect((await h.one('safety_findings', 'f1'))!['dismissed_at'], isNotNull);

    await h.run([
      updateOp('safety_findings', 'f1', {'dismissed': false}),
    ]);
    expect((await h.one('safety_findings', 'f1'))!['dismissed_at'], isNull);
  });
}
