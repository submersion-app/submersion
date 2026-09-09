import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// SQLite cascades equipment_components away when either end is deleted,
/// but a cascade emits no deletion-log entry, so deleteEquipment must
/// tombstone the rows itself, in both directions (issue #1487).
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;
  late EquipmentComponentRepository components;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    components = EquipmentComponentRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final id in ['reg', 'first', 'hose']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> componentTombstones() async {
    final rows = await db.select(db.deletionLog).get();
    return rows
        .where((r) => r.entityType == 'equipmentComponents')
        .map((r) => r.recordId)
        .toSet();
  }

  test('deleting the parent tombstones every row under it', () async {
    final a = await components.addComponent(
      parentId: 'reg',
      componentId: 'first',
    );
    final b = await components.addComponent(
      parentId: 'reg',
      componentId: 'hose',
    );
    await repo.deleteEquipment('reg');
    expect(await db.select(db.equipmentComponents).get(), isEmpty);
    expect(await componentTombstones(), {a.id, b.id});
  });

  test('deleting a part tombstones the rows that pointed at it', () async {
    final a = await components.addComponent(
      parentId: 'reg',
      componentId: 'first',
    );
    final keep = await components.addComponent(
      parentId: 'reg',
      componentId: 'hose',
    );
    await repo.deleteEquipment('first');
    final remaining = await db.select(db.equipmentComponents).get();
    expect(remaining.map((r) => r.id), [keep.id]);
    expect(await componentTombstones(), {a.id});
  });

  test('watchEquipmentChanges stays quiet on a component write', () async {
    // Every clock evaluation hangs off this stream; a membership edit must
    // not make it re-run. The assembly providers follow the edge stream.
    var ticks = 0;
    final sub = repo.watchEquipmentChanges().listen((_) => ticks++);
    addTearDown(sub.cancel);
    await components.addComponent(parentId: 'reg', componentId: 'first');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(ticks, 0);
    await (db.update(db.equipment)..where((t) => t.id.equals('reg'))).write(
      const EquipmentCompanion(name: Value('Renamed reg')),
    );
    for (var i = 0; i < 50 && ticks == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ticks, greaterThan(0));
  });
}
