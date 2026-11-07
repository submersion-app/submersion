import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// The parts of an assembly, as its components card keeps them: a part is
/// added, given a role, swapped, moved and removed, and nothing loops.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> gear(String id, String type) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: type,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
        ),
      );

  Map<String, Object?> part(String parent, String component) => {
    'parent_equipment_id': parent,
    'component_equipment_id': component,
    'role': 'Primary',
  };

  Future<List<EquipmentComponentRow>> parts(String parent) =>
      (db.select(db.equipmentComponents)
            ..where((c) => c.parentEquipmentId.equals(parent))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await gear('reg', 'regulator');
    await gear('first', 'firstStage');
    await gear('second', 'secondStage');
    await gear('octo', 'secondStage');
  });
  tearDown(() => tearDownTestDatabase());

  test('a part is added, renamed, swapped, moved and removed', () async {
    final first = (await h.run([
      createOp('equipment_components', part('reg', 'first')),
    ])).created.single.id;
    final second = (await h.run([
      createOp('equipment_components', part('reg', 'second')),
    ])).created.single.id;
    expect([for (final p in await parts('reg')) p.id], [first, second]);

    await h.run([
      updateOp('equipment_components', second, {'role': ' Octopus '}),
    ]);
    await h.run([
      updateOp('equipment_components', second, {
        'component_equipment_id': 'octo',
      }),
    ]);
    final swapped = (await parts('reg')).last;
    expect(swapped.componentEquipmentId, 'octo');
    expect(swapped.role, 'Octopus');

    await h.run([
      updateOp('equipment_components', second, {'sort_order': 0}),
    ]);
    expect([for (final p in await parts('reg')) p.id], [second, first]);

    await h.run([deleteOp('equipment_components', first)]);
    expect([for (final p in await parts('reg')) p.id], [second]);
  });

  test('a part change follows on planned dives only (#4283)', () async {
    // d1 is logged, p1 planned; both carry reg with first under it.
    await h.dive('p1');
    await (db.update(db.dives)..where((d) => d.id.equals('p1'))).write(
      const DivesCompanion(isPlanned: Value(true)),
    );
    final first = (await h.run([
      createOp('equipment_components', part('reg', 'first')),
    ])).created.single.id;
    for (final dive in ['d1', 'p1']) {
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: dive, equipmentId: 'reg'),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(
              diveId: dive,
              equipmentId: 'first',
              viaEquipmentId: const Value('reg'),
            ),
          );
    }
    Future<Set<String>> gearOn(String dive) async => {
      for (final row in await (db.select(
        db.diveEquipment,
      )..where((r) => r.diveId.equals(dive))).get())
        row.equipmentId,
    };

    final added = await h.preview([
      createOp('equipment_components', part('reg', 'second')),
    ]);
    expect(added.items.single.alsoChanges, {'dives': 1});
    await h.apply(added);
    expect(await gearOn('p1'), {'reg', 'first', 'second'});
    expect(await gearOn('d1'), {'reg', 'first'});

    await h.run([
      updateOp('equipment_components', first, {
        'component_equipment_id': 'octo',
      }),
    ]);
    expect(await gearOn('p1'), {'reg', 'octo', 'second'});

    await h.run([deleteOp('equipment_components', first)]);
    expect(await gearOn('p1'), {'reg', 'second'});
    expect(await gearOn('d1'), {'reg', 'first'});
  });

  test('a part that would close a loop is blocked', () async {
    await h.run([createOp('equipment_components', part('reg', 'first'))]);

    final plan = await h.preview([
      createOp('equipment_components', part('first', 'reg')),
      createOp('equipment_components', part('reg', 'reg')),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  // The set runs in order, so a link an earlier change adds is there by
  // the time a later one would close a loop or repeat it.
  test('a loop or a repeat within one set is blocked', () async {
    final loop = await h.preview([
      createOp('equipment_components', part('reg', 'first')),
      createOp('equipment_components', part('first', 'reg')),
    ]);
    expect(loop.items.first.block, isNull);
    expect(loop.items.last.block!.reason, BlockReason.invalidValue);

    final twice = await h.preview([
      createOp('equipment_components', part('reg', 'first')),
      createOp('equipment_components', part('reg', 'first')),
    ]);
    expect(twice.items.last.block!.reason, BlockReason.duplicateRecord);

    final id = (await h.run([
      createOp('equipment_components', part('reg', 'second')),
    ])).created.single.id;
    final swap = await h.preview([
      createOp('equipment_components', part('reg', 'octo')),
      updateOp('equipment_components', id, {'component_equipment_id': 'octo'}),
    ]);
    expect(swap.items.last.block!.reason, BlockReason.duplicateRecord);
  });

  test('a part already in the assembly is a duplicate', () async {
    await h.run([createOp('equipment_components', part('reg', 'first'))]);

    final plan = await h.preview([
      createOp('equipment_components', part('reg', 'first')),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.duplicateRecord);
  });

  // A removal leaves a gap in the stored order, so a plan reads a part's
  // place in the assembly, the number an agent writes back.
  test('a part at its place already is unchanged', () async {
    for (final (id, component, order) in [
      ('c1', 'first', 0),
      ('c2', 'second', 5),
    ]) {
      await db
          .into(db.equipmentComponents)
          .insert(
            EquipmentComponentsCompanion.insert(
              id: id,
              parentEquipmentId: 'reg',
              componentEquipmentId: component,
              sortOrder: Value(order),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }

    final plan = await h.preview([
      updateOp('equipment_components', 'c2', {'sort_order': 1}),
    ]);

    expect(plan.unchanged.single.id, 'c2');
  });

  test('a position must be one the assembly holds', () async {
    final id = (await h.run([
      createOp('equipment_components', part('reg', 'first')),
    ])).created.single.id;

    final plan = await h.preview([
      updateOp('equipment_components', id, {'sort_order': 3}),
      createOp('equipment_components', {
        ...part('reg', 'second'),
        'sort_order': 0,
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });
}
