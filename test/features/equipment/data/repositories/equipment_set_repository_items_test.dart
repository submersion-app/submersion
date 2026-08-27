import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';

/// Membership writes on [EquipmentSetRepository].
///
/// Regression cover for issue #819: deleting a gear item that belongs to a set
/// left a stale [EquipmentSet] in the provider cache, and saving that set
/// re-inserted the dead id -- an FK violation (SqliteException 787) that
/// aborted the save *after* the delete-all step had already emptied the set and
/// tombstoned every member for sync.
void main() {
  late AppDatabase db;
  late EquipmentSetRepository repo;
  late EquipmentRepository equipmentRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentSetRepository();
    equipmentRepo = EquipmentRepository();
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
  });

  tearDown(tearDownTestDatabase);

  Future<void> seedEquipment(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }

  EquipmentSet newSet(String id, List<String> equipmentIds) => EquipmentSet(
    id: id,
    diverId: 'd1',
    name: id,
    equipmentIds: equipmentIds,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<List<DeletionLogData>> itemTombstones() async {
    final rows = await db.select(db.deletionLog).get();
    return rows.where((r) => r.entityType == 'equipmentSetItems').toList();
  }

  group('updateSet', () {
    test('drops members whose equipment was deleted (issue #819)', () async {
      for (final id in ['e1', 'e2', 'e3']) {
        await seedEquipment(id);
      }
      await repo.createSet(newSet('s1', ['e1', 'e2', 'e3']));

      // SQLite cascades the junction row away, but a cached EquipmentSet held
      // by equipmentSetProvider still carries all three ids -- and the edit
      // page seeds its selection from that cache.
      await equipmentRepo.deleteEquipment('e2');

      final stale = newSet('s1', ['e1', 'e2', 'e3']);
      await repo.updateSet(stale);

      expect(
        await repo.getEquipmentIdsInSet('s1'),
        unorderedEquals(['e1', 'e3']),
        reason: 'the dead id must be pruned, not inserted',
      );
    });

    test('a save carrying a dead id still persists the real edits', () async {
      for (final id in ['e1', 'e2']) {
        await seedEquipment(id);
      }
      await repo.createSet(newSet('s1', ['e1', 'e2']));
      await equipmentRepo.deleteEquipment('e2');

      // The form still carries the deleted id in its selection, alongside a
      // genuine rename the diver expects to keep.
      await repo.updateSet(
        EquipmentSet(
          id: 's1',
          diverId: 'd1',
          name: 'Renamed',
          equipmentIds: const ['e1', 'e2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final saved = await repo.getSetById('s1');
      expect(saved!.name, 'Renamed');
      expect(saved.equipmentIds, ['e1']);
    });

    test('unchanged membership writes no item tombstones', () async {
      for (final id in ['e1', 'e2']) {
        await seedEquipment(id);
      }
      await repo.createSet(newSet('s1', ['e1', 'e2']));

      await repo.updateSet(newSet('s1', ['e1', 'e2']));

      expect(
        await itemTombstones(),
        isEmpty,
        reason:
            'a diff-based write must not delete-and-reinsert unchanged rows; '
            'spurious tombstones race live rows on the next sync',
      );
      expect(
        await repo.getEquipmentIdsInSet('s1'),
        unorderedEquals(['e1', 'e2']),
      );
    });

    test('tombstones only the members actually removed', () async {
      for (final id in ['e1', 'e2', 'e3']) {
        await seedEquipment(id);
      }
      await repo.createSet(newSet('s1', ['e1', 'e2', 'e3']));

      await repo.updateSet(newSet('s1', ['e1', 'e3']));

      final tombs = await itemTombstones();
      expect(tombs.map((t) => t.recordId), ['s1|e2']);
      expect(
        await repo.getEquipmentIdsInSet('s1'),
        unorderedEquals(['e1', 'e3']),
      );
    });

    test('a failed write rolls back and logs no sync bookkeeping', () async {
      await seedEquipment('e1');

      // No such set: the junction insert violates the set_id FK. The whole
      // write must roll back, and because sync bookkeeping runs only after the
      // transaction commits, nothing may be marked pending or tombstoned.
      await expectLater(
        repo.updateSet(newSet('ghost', ['e1'])),
        throwsA(anything),
      );

      expect(await itemTombstones(), isEmpty);
      final pending = await db.select(db.syncRecords).get();
      expect(pending, isEmpty);
    });
  });

  group('createSet', () {
    test('ignores ids with no equipment row', () async {
      await seedEquipment('e1');

      await repo.createSet(newSet('s1', ['e1', 'gone']));

      expect(await repo.getEquipmentIdsInSet('s1'), ['e1']);
    });
  });
}
