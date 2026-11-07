import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Twin set pairings (issue #4242), as the Twin set card keeps them: a
/// pairing is made, ended and deleted, and one that would put a cylinder in
/// two sets on one day is blocked.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> cylinder(String id) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Cylinder $id',
          type: 'tank',
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
        ),
      );

  Future<List<CylinderPairingRow>> pairings() => (db.select(
    db.cylinderPairings,
  )..orderBy([(p) => OrderingTerm.asc(p.pairedOn)])).get();

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    for (final id in const ['A', 'B', 'C']) {
      await cylinder(id);
    }
  });
  tearDown(() => tearDownTestDatabase());

  test('a pairing is made, ended and deleted', () async {
    final id = (await h.run([
      createOp('cylinder_pairings', {
        'cylinder_a_id': 'A',
        'cylinder_b_id': 'B',
        'paired_on': '2026-03-03',
      }),
    ])).created.single.id;
    final made = (await pairings()).single;
    expect(made.id, id);
    expect(made.pairedOn, DateTime.utc(2026, 3, 3).millisecondsSinceEpoch);
    expect(made.unpairedOn, isNull);

    await h.run([
      updateOp('cylinder_pairings', id, {'unpaired_on': '2026-09-14'}),
    ]);
    expect(
      (await pairings()).single.unpairedOn,
      DateTime.utc(2026, 9, 14).millisecondsSinceEpoch,
    );

    await h.run([deleteOp('cylinder_pairings', id)]);
    expect(await pairings(), isEmpty);
  });

  test('a cylinder already in a set that day is blocked, naming it', () async {
    await h.run([
      createOp('cylinder_pairings', {
        'cylinder_a_id': 'A',
        'cylinder_b_id': 'B',
        'paired_on': '2026-03-03',
      }),
    ]);
    final plan = await h.preview([
      createOp('cylinder_pairings', {
        'cylinder_a_id': 'C',
        'cylinder_b_id': 'B',
        'paired_on': '2026-06-01',
      }),
    ]);
    final block = plan.items.single.block!;
    expect(block.reason, BlockReason.invalidValue);
    expect(block.detail, contains('Cylinder A'));
  });

  test('a cylinder cannot pair with itself, and the pair is fixed', () async {
    final self = await h.preview([
      createOp('cylinder_pairings', {
        'cylinder_a_id': 'A',
        'cylinder_b_id': 'A',
        'paired_on': '2026-03-03',
      }),
    ]);
    expect(self.items.single.block!.reason, BlockReason.invalidValue);

    final id = (await h.run([
      createOp('cylinder_pairings', {
        'cylinder_a_id': 'A',
        'cylinder_b_id': 'B',
        'paired_on': '2026-03-03',
      }),
    ])).created.single.id;
    final swap = await h.preview([
      updateOp('cylinder_pairings', id, {'cylinder_b_id': 'C'}),
    ]);
    expect(swap.items.single.block, isNotNull);
  });

  test('an end on or before the start is blocked', () async {
    final id = (await h.run([
      createOp('cylinder_pairings', {
        'cylinder_a_id': 'A',
        'cylinder_b_id': 'B',
        'paired_on': '2026-03-03',
      }),
    ])).created.single.id;
    final plan = await h.preview([
      updateOp('cylinder_pairings', id, {'unpaired_on': '2026-03-03'}),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('only two cylinders can be paired', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'REG',
            name: 'Regulator',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    final plan = await h.preview([
      createOp('cylinder_pairings', {
        'cylinder_a_id': 'A',
        'cylinder_b_id': 'REG',
        'paired_on': '2026-03-03',
      }),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });
}
