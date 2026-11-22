import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

import '../../../../helpers/test_database.dart';
import '../../../../helpers/unique_ids.dart';

/// A computer's "Dives imported" and its Equipment item cover every dive
/// with a source from that computer, however the source came to point at it
/// (issue #4846): a download, a relink after the computer was set up again,
/// or a merge.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertItem(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: 'Perdix',
            type: 'computer',
            brand: const Value('Shearwater'),
            model: const Value('Perdix'),
            serialNumber: const Value('SN-12345'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<String> insertComputer({
    required String id,
    String? equipmentId,
    int storedDiveCount = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Perdix $id'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix'),
            serialNumber: Value('SN-$id'),
            equipmentId: Value(equipmentId),
            diveCount: Value(storedDiveCount),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<String> insertDive({String? computerId}) async {
    final diveId = uniqueTestId('dive');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            computerId: Value(computerId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  Future<String> insertSource({
    required String diveId,
    String? computerId,
    bool isPrimary = true,
    String? computerSerial,
  }) async {
    final id = uniqueTestId('ds');
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            computerModel: const Value('Shearwater Perdix'),
            computerSerial: Value(computerSerial),
            sourceFormat: const Value('dive_computer'),
            descriptorVendor: const Value('Shearwater'),
            descriptorProduct: const Value('Perdix'),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
    return id;
  }

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return {for (final r in rows) r.equipmentId};
  }

  Future<bool> isPending(String entityType, String recordId) async =>
      (await (db.select(db.syncRecords)..where(
                (r) =>
                    r.entityType.equals(entityType) &
                    r.recordId.equals(recordId),
              ))
              .get())
          .isNotEmpty;

  domain.DiveComputer newComputer({String? equipmentId}) {
    final now = DateTime.now();
    return domain.DiveComputer(
      id: '',
      name: 'My Perdix',
      manufacturer: 'Shearwater',
      model: 'Perdix',
      serialNumber: 'SN-12345',
      equipmentId: equipmentId,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Dives imported', () {
    test('counts every dive with a source from the computer, not the stored '
        'download counter', () async {
      await insertComputer(id: 'c1', storedDiveCount: 1);
      await insertComputer(id: 'c2');
      // Primary source.
      final primary = await insertDive(computerId: 'c1');
      await insertSource(diveId: primary, computerId: 'c1');
      // Secondary source: another computer is the dive's primary.
      final secondary = await insertDive(computerId: 'c2');
      await insertSource(diveId: secondary, computerId: 'c2');
      await insertSource(diveId: secondary, computerId: 'c1', isPrimary: false);
      // Attributed to the computer before data sources existed.
      await insertDive(computerId: 'c1');
      // Two sources of one dive count it once.
      final twice = await insertDive(computerId: 'c1');
      await insertSource(diveId: twice, computerId: 'c1');
      await insertSource(diveId: twice, computerId: 'c1', isPrimary: false);
      // Another computer's dive.
      final other = await insertDive(computerId: 'c2');
      await insertSource(diveId: other, computerId: 'c2');

      expect((await repository.getComputerById('c1'))!.diveCount, 4);
      final all = await repository.getAllComputers();
      expect({for (final c in all) c.id: c.diveCount}, {'c1': 4, 'c2': 2});
    });

    test('is zero for a computer with no dives', () async {
      await insertComputer(id: 'c1', storedDiveCount: 7);

      expect((await repository.getComputerById('c1'))!.diveCount, 0);
    });

    test('is the same through every read of the computer', () async {
      await insertItem('gear-1');
      await insertComputer(id: 'c1', equipmentId: 'gear-1');
      await db.customStatement(
        'UPDATE dive_computers SET is_favorite = 1 WHERE id = ?',
        ['c1'],
      );
      final diveId = await insertDive(computerId: 'c1');
      await insertSource(diveId: diveId, computerId: 'c1');

      expect(
        (await repository.getComputersForEquipment('gear-1')).single.diveCount,
        1,
      );
      expect((await repository.getFavoriteComputer())!.diveCount, 1);
      expect(
        (await repository.findByHardwareIdentity(
          serialNumber: 'SN-c1',
        ))!.diveCount,
        1,
      );
    });

    test('a computer set up again counts the dives relinked to it', () async {
      final diveIds = <String>[];
      for (var i = 0; i < 3; i++) {
        final diveId = await insertDive();
        await insertSource(diveId: diveId, computerSerial: 'SN-12345');
        diveIds.add(diveId);
      }

      final created = await repository.createComputer(newComputer());

      expect((await repository.getComputerById(created.id))!.diveCount, 3);
    });

    test('refreshes when a data source changes', () async {
      await insertComputer(id: 'c1');
      final diveId = await insertDive();
      final ticks = repository.watchComputersChanges().first;

      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('ds-tick'),
              diveId: Value(diveId),
              computerId: const Value('c1'),
              isPrimary: const Value(true),
              importedAt: Value(DateTime.now()),
              createdAt: Value(DateTime.now()),
            ),
          );

      await expectLater(ticks, completes);
    });
  });

  test('refreshes when a dive changes its computer', () async {
    await insertComputer(id: 'c1');
    final diveId = await insertDive();
    final ticks = repository.watchComputersChanges().first;

    await (db.update(db.dives)..where((t) => t.id.equals(diveId))).write(
      const DivesCompanion(computerId: Value('c1')),
    );

    await expectLater(ticks, completes);
    expect((await repository.getComputerById('c1'))!.diveCount, 1);
  });

  group('relinking a computer set up again', () {
    test('puts the computer\'s Equipment item on every relinked dive, '
        'staged for sync', () async {
      final diveIds = <String>[];
      for (var i = 0; i < 3; i++) {
        final diveId = await insertDive();
        await insertSource(diveId: diveId, computerSerial: 'SN-12345');
        diveIds.add(diveId);
      }

      final created = await repository.createComputer(newComputer());
      final itemId = created.equipmentId;

      expect(itemId, isNotNull);
      for (final diveId in diveIds) {
        expect(await equipmentOn(diveId), contains(itemId));
        expect(await isPending('diveEquipment', '$diveId|$itemId'), isTrue);
      }
    });

    test('leaves the item off a dive the diver took it off', () async {
      await insertItem('gear-1');
      final kept = await insertDive();
      await insertSource(diveId: kept, computerSerial: 'SN-12345');
      final removed = await insertDive();
      await insertSource(diveId: removed, computerSerial: 'SN-12345');
      await SyncRepository().logDeletion(
        entityType: 'diveEquipment',
        recordId: '$removed|gear-1',
      );

      final created = await repository.createComputer(
        newComputer(equipmentId: 'gear-1'),
      );

      expect(created.equipmentId, 'gear-1');
      expect(await equipmentOn(kept), {'gear-1'});
      expect(await equipmentOn(removed), isEmpty);
    });
  });

  group('merging computers', () {
    test('puts the survivor\'s item on the duplicate\'s dives that lacked '
        'one', () async {
      await insertItem('gear-1');
      await insertComputer(id: 'survivor', equipmentId: 'gear-1');
      await insertComputer(id: 'duplicate');
      final diveId = await insertDive(computerId: 'duplicate');
      await insertSource(diveId: diveId, computerId: 'duplicate');

      await DiveComputerMergeRepository().mergeComputers(
        survivorId: 'survivor',
        duplicateIds: ['duplicate'],
      );

      expect(await equipmentOn(diveId), {'gear-1'});
      expect(await isPending('diveEquipment', '$diveId|gear-1'), isTrue);
    });

    test('leaves the item off a dive the diver took the duplicate\'s item '
        'off', () async {
      await insertItem('gear-1');
      await insertItem('gear-dup');
      await insertComputer(id: 'survivor', equipmentId: 'gear-1');
      await insertComputer(id: 'duplicate', equipmentId: 'gear-dup');
      final removed = await insertDive(computerId: 'duplicate');
      await insertSource(diveId: removed, computerId: 'duplicate');
      await SyncRepository().logDeletion(
        entityType: 'diveEquipment',
        recordId: '$removed|gear-dup',
      );
      // Its link moves with the merge, which tombstones the old key; that
      // is not a removal by the diver.
      final moved = await insertDive(computerId: 'duplicate');
      await insertSource(diveId: moved, computerId: 'duplicate');
      await db.customStatement(
        'INSERT INTO dive_equipment (dive_id, equipment_id) VALUES (?, ?)',
        [moved, 'gear-dup'],
      );

      await DiveComputerMergeRepository().mergeComputers(
        survivorId: 'survivor',
        duplicateIds: ['duplicate'],
      );

      expect(await equipmentOn(removed), isEmpty);
      expect(await equipmentOn(moved), {'gear-1'});
    });

    test('leaves the survivor\'s own dives as they are', () async {
      await insertItem('gear-1');
      await insertComputer(id: 'survivor', equipmentId: 'gear-1');
      await insertComputer(id: 'duplicate');
      // The diver took the item off this dive long ago; its tombstone is
      // gone, so only leaving the survivor's dives alone keeps it off.
      final own = await insertDive(computerId: 'survivor');
      await insertSource(diveId: own, computerId: 'survivor');

      await DiveComputerMergeRepository().mergeComputers(
        survivorId: 'survivor',
        duplicateIds: ['duplicate'],
      );

      expect(await equipmentOn(own), isEmpty);
    });
  });
}
