import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';

import '../../../../helpers/test_database.dart';

/// The assembly template (issue #1487): membership rows, the cycle guard,
/// ordering, and the sync bookkeeping every write must leave behind.
void main() {
  late AppDatabase db;
  late EquipmentComponentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentComponentRepository();
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
    for (final id in ['reg', 'first', 'second', 'hose', 'kit']) {
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

  Future<List<String>> pendingIds() async {
    final rows = await db.select(db.syncRecords).get();
    return rows
        .where((r) => r.entityType == 'equipmentComponents')
        .map((r) => r.recordId)
        .toList();
  }

  Future<List<String>> tombstones() async {
    final rows = await db.select(db.deletionLog).get();
    return rows
        .where((r) => r.entityType == 'equipmentComponents')
        .map((r) => r.recordId)
        .toList();
  }

  group('addComponent', () {
    test(
      'appends with the next sort order and marks the row pending',
      () async {
        final a = await repo.addComponent(
          parentId: 'reg',
          componentId: 'first',
        );
        final b = await repo.addComponent(
          parentId: 'reg',
          componentId: 'second',
          role: '  Primary  ',
        );
        expect(a.sortOrder, 0);
        expect(b.sortOrder, 1);
        expect(b.role, 'Primary');
        expect(await pendingIds(), containsAll([a.id, b.id]));
      },
    );

    test('a second add of the same pair returns the existing row', () async {
      final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
      final again = await repo.addComponent(
        parentId: 'reg',
        componentId: 'first',
      );
      expect(again.id, a.id);
      expect(await db.select(db.equipmentComponents).get(), hasLength(1));
    });

    test('refuses a self reference', () async {
      expect(
        () => repo.addComponent(parentId: 'reg', componentId: 'reg'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
    });

    test('refuses a direct cycle', () async {
      await repo.addComponent(parentId: 'reg', componentId: 'first');
      expect(
        () => repo.addComponent(parentId: 'first', componentId: 'reg'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
    });

    test('refuses a transitive cycle three levels deep', () async {
      await repo.addComponent(parentId: 'kit', componentId: 'reg');
      await repo.addComponent(parentId: 'reg', componentId: 'first');
      await repo.addComponent(parentId: 'first', componentId: 'hose');
      expect(
        () => repo.addComponent(parentId: 'hose', componentId: 'kit'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
      // The legal direction still works.
      await repo.addComponent(parentId: 'kit', componentId: 'hose');
    });

    test('a part may belong to two assemblies', () async {
      await repo.addComponent(parentId: 'reg', componentId: 'second');
      await repo.addComponent(parentId: 'kit', componentId: 'second');
      expect(await repo.getAllComponents(), hasLength(2));
    });
  });

  test('getComponents hydrates parts in sort order', () async {
    await repo.addComponent(parentId: 'reg', componentId: 'second');
    await repo.addComponent(parentId: 'reg', componentId: 'first');
    final parts = await repo.getComponents('reg');
    expect(parts.map((p) => p.componentEquipmentId), ['second', 'first']);
    expect(parts.map((p) => p.component?.name), ['second', 'first']);
    expect(await repo.getComponents('hose'), isEmpty);
  });

  test('parts that collide on sort order come back in row id order', () async {
    // A sync merge of concurrent reorders can leave two parts on one
    // sort_order; the repository must still answer in one fixed order.
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final (id, child) in [('zz', 'second'), ('aa', 'first')]) {
      await db
          .into(db.equipmentComponents)
          .insert(
            EquipmentComponentsCompanion.insert(
              id: id,
              parentEquipmentId: 'reg',
              componentEquipmentId: child,
              sortOrder: const Value(0),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    expect((await repo.getComponents('reg')).map((p) => p.id), ['aa', 'zz']);
    expect((await repo.getAllComponents()).map((p) => p.id), ['aa', 'zz']);
  });

  test('ancestorsOf walks upward and terminates', () async {
    await repo.addComponent(parentId: 'kit', componentId: 'reg');
    await repo.addComponent(parentId: 'reg', componentId: 'hose');
    expect(await repo.ancestorsOf('hose'), {'reg', 'kit'});
    expect(await repo.ancestorsOf('kit'), isEmpty);
  });

  test(
    'ancestorsOf terminates on a corrupt cycle written behind the guard',
    () async {
      // The repository refuses a cycle, so write the loop with raw inserts.
      final t = DateTime.now().millisecondsSinceEpoch;
      for (final (id, parent, child) in [
        ('x1', 'reg', 'first'),
        ('x2', 'first', 'reg'),
      ]) {
        await db
            .into(db.equipmentComponents)
            .insert(
              EquipmentComponentsCompanion.insert(
                id: id,
                parentEquipmentId: parent,
                componentEquipmentId: child,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      expect(await repo.ancestorsOf('reg'), {'first', 'reg'});
    },
  );

  test('reorder rewrites sort order in the given sequence', () async {
    final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
    final b = await repo.addComponent(parentId: 'reg', componentId: 'second');
    final c = await repo.addComponent(parentId: 'reg', componentId: 'hose');
    await repo.reorder('reg', [c.id, a.id, b.id]);
    final parts = await repo.getComponents('reg');
    expect(parts.map((p) => p.componentEquipmentId), [
      'hose',
      'first',
      'second',
    ]);
    expect(parts.map((p) => p.sortOrder), [0, 1, 2]);
  });

  test('updateRole trims and marks pending', () async {
    final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
    await repo.updateRole(a.id, ' Necklace ');
    final parts = await repo.getComponents('reg');
    expect(parts.single.role, 'Necklace');
    expect(await pendingIds(), contains(a.id));
  });

  test('removeComponent deletes the row and writes a tombstone', () async {
    final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
    await repo.removeComponent(a.id);
    expect(await repo.getComponents('reg'), isEmpty);
    expect(await tombstones(), [a.id]);
  });

  test(
    'distinctRoles returns used roles once, sorted, without blanks',
    () async {
      await repo.addComponent(
        parentId: 'reg',
        componentId: 'first',
        role: 'Primary',
      );
      await repo.addComponent(
        parentId: 'reg',
        componentId: 'second',
        role: 'Necklace',
      );
      await repo.addComponent(
        parentId: 'kit',
        componentId: 'hose',
        role: 'Primary',
      );
      await repo.addComponent(parentId: 'kit', componentId: 'second');
      expect(await repo.distinctRoles(), ['Necklace', 'Primary']);
    },
  );

  test('watchComponentEdgeChanges ignores a rename but sees an edge', () async {
    var ticks = 0;
    final sub = repo.watchComponentEdgeChanges().listen((_) => ticks++);
    addTearDown(sub.cancel);
    await (db.update(db.equipment)..where((t) => t.id.equals('reg'))).write(
      const EquipmentCompanion(name: Value('Renamed reg')),
    );
    // Past the 300 ms debounce with no edge write: still silent.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(ticks, 0);
    await repo.addComponent(parentId: 'reg', componentId: 'first');
    for (var i = 0; i < 50 && ticks == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ticks, greaterThan(0));
  });

  test('watchComponentChanges ticks on a membership write', () async {
    var ticks = 0;
    final sub = repo.watchComponentChanges().listen((_) => ticks++);
    addTearDown(sub.cancel);
    await repo.addComponent(parentId: 'reg', componentId: 'first');
    // The stream is debounced 300 ms; poll rather than pumpEventQueue.
    for (var i = 0; i < 50 && ticks == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ticks, greaterThan(0));
  });

  group('replaceComponent', () {
    test(
      'keeps role and order, swaps the component id, marks the row pending',
      () async {
        await repo.addComponent(parentId: 'reg', componentId: 'first');
        final row = await repo.addComponent(
          parentId: 'reg',
          componentId: 'hose',
          role: 'Primary',
        );
        final replaced = await repo.replaceComponent(row.id, 'second');
        expect(replaced.id, row.id);
        expect(replaced.componentEquipmentId, 'second');
        final parts = await repo.getComponents('reg');
        expect(parts.map((p) => p.componentEquipmentId), ['first', 'second']);
        expect(parts[1].role, 'Primary');
        expect(parts[1].sortOrder, row.sortOrder);
        expect(await pendingIds(), contains(row.id));
      },
    );

    test('refuses a replacement that would close a cycle', () async {
      await repo.addComponent(parentId: 'kit', componentId: 'reg');
      final row = await repo.addComponent(parentId: 'reg', componentId: 'hose');
      await expectLater(
        repo.replaceComponent(row.id, 'kit'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
      final parts = await repo.getComponents('reg');
      expect(parts.single.componentEquipmentId, 'hose');
    });
  });
}
