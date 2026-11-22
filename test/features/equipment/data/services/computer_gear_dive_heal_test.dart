import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/services/computer_gear_dive_heal.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../../helpers/test_database.dart';

/// The one-time pass that gives existing libraries the computer item links
/// their relinked and merged dives never got (issue #4846).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertItem(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'computer',
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  Future<void> insertComputer(String id, {String? equipmentId}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: id,
            equipmentId: Value(equipmentId),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  Future<void> insertDive(String id, {String? computerId}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(t),
            computerId: Value(computerId),
            createdAt: Value(t),
            updatedAt: Value(t),
          ),
        );
  }

  Future<void> insertSource(
    String diveId,
    String computerId, {
    bool isPrimary = true,
  }) async {
    await db.customStatement(
      'INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, '
      'imported_at, created_at) VALUES (?, ?, ?, ?, 1, 1)',
      ['src-$diveId-$computerId', diveId, computerId, isPrimary ? 1 : 0],
    );
  }

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return {for (final r in rows) r.equipmentId};
  }

  Future<bool> isPending(String recordId) async =>
      (await (db.select(db.syncRecords)..where(
                (r) =>
                    r.entityType.equals('diveEquipment') &
                    r.recordId.equals(recordId),
              ))
              .get())
          .isNotEmpty;

  test('puts each computer\'s item on every dive it recorded, staged for '
      'sync', () async {
    await insertItem('gear-1');
    await insertItem('gear-2');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertComputer('c2', equipmentId: 'gear-2');
    await insertDive('primary', computerId: 'c1');
    await insertSource('primary', 'c1');
    await insertDive('legacy', computerId: 'c1');
    await insertDive('both', computerId: 'c2');
    await insertSource('both', 'c2');
    await insertSource('both', 'c1', isPrimary: false);

    final linked = await ComputerGearDiveHeal().run();

    expect(linked, 4);
    expect(await equipmentOn('primary'), {'gear-1'});
    expect(await equipmentOn('legacy'), {'gear-1'});
    expect(await equipmentOn('both'), {'gear-1', 'gear-2'});
    expect(await isPending('primary|gear-1'), isTrue);
  });

  test('leaves a dive the diver took the item off, and a computer with no '
      'item', () async {
    await insertItem('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertComputer('bare');
    await insertDive('removed', computerId: 'c1');
    await insertSource('removed', 'c1');
    await insertDive('bare-dive', computerId: 'bare');
    await SyncRepository().logDeletion(
      entityType: 'diveEquipment',
      recordId: 'removed|gear-1',
    );

    expect(await ComputerGearDiveHeal().run(), 0);
    expect(await equipmentOn('removed'), isEmpty);
    expect(await equipmentOn('bare-dive'), isEmpty);
  });

  test('leaves a library with no computer unmarked, so a device joining '
      'a synced library still runs the pass once its data arrives', () async {
    expect(await ComputerGearDiveHeal().run(), 0);
    expect(
      await AppSettingsRepository().getRawSetting(ComputerGearDiveHeal.doneKey),
      isNull,
    );

    await insertItem('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertDive('d1', computerId: 'c1');

    expect(await ComputerGearDiveHeal().run(), 1);
    expect(await equipmentOn('d1'), {'gear-1'});
  });

  test('skips the pass when the marker cannot be read', () async {
    await insertItem('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertDive('d1', computerId: 'c1');
    await db.customStatement('ALTER TABLE settings RENAME TO settings_gone');
    addTearDown(
      () => db.customStatement('ALTER TABLE settings_gone RENAME TO settings'),
    );

    expect(await ComputerGearDiveHeal().run(), 0);
    expect(await equipmentOn('d1'), isEmpty);
  });

  test(
    'puts the item alone on a dive, not the parts fitted to it since',
    () async {
      await insertItem('gear-1');
      await insertItem('battery');
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipmentComponents)
          .insert(
            EquipmentComponentsCompanion.insert(
              id: 'comp-1',
              parentEquipmentId: 'gear-1',
              componentEquipmentId: 'battery',
              createdAt: t,
              updatedAt: t,
            ),
          );
      await insertComputer('c1', equipmentId: 'gear-1');
      await insertDive('old', computerId: 'c1');

      expect(await ComputerGearDiveHeal().run(), 1);
      expect(await equipmentOn('old'), {'gear-1'});
    },
  );

  test('leaves a computer whose item a sync left dangling', () async {
    await insertComputer('c1', equipmentId: 'ghost');
    await insertDive('d1', computerId: 'c1');

    expect(await ComputerGearDiveHeal().run(), 0);
    expect(await equipmentOn('d1'), isEmpty);
  });

  test('keeps to the removals it read at the start when a tombstone GC runs '
      'part way through', () async {
    await insertItem('gear-1');
    await insertItem('gear-2');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertComputer('c2', equipmentId: 'gear-2');
    await insertDive('d1', computerId: 'c1');
    await insertDive('d2', computerId: 'c2');
    await SyncRepository().logDeletion(
      entityType: 'diveEquipment',
      recordId: 'd2|gear-2',
    );

    await ComputerGearDiveHeal(
      linker: _BeforeFirstLink(
        () => db.customStatement('DELETE FROM deletion_log'),
      ),
    ).run();

    expect(await equipmentOn('d1'), {'gear-1'});
    expect(await equipmentOn('d2'), isEmpty);
  });

  test('stops, unmarked, when another library is opened part way', () async {
    await insertItem('gear-1');
    await insertItem('gear-2');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertComputer('c2', equipmentId: 'gear-2');
    await insertDive('d1', computerId: 'c1');
    await insertDive('d2', computerId: 'c2');
    final other = createTestDatabase();
    addTearDown(() async {
      DatabaseService.instance.setTestDatabase(db);
      await other.close();
    });

    await ComputerGearDiveHeal(
      linker: _BeforeFirstLink(
        () async => DatabaseService.instance.setTestDatabase(other),
      ),
    ).run();

    for (final library in [db, other]) {
      final marker = await (library.select(
        library.settings,
      )..where((t) => t.key.equals(ComputerGearDiveHeal.doneKey))).get();
      expect(marker, isEmpty);
    }
  });

  test('runs once per library: a link removed afterwards stays removed, '
      'whatever became of its tombstone', () async {
    await insertItem('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertDive('d1', computerId: 'c1');
    await insertSource('d1', 'c1');

    expect(await ComputerGearDiveHeal().run(), 1);
    expect(
      await AppSettingsRepository().getRawSetting(ComputerGearDiveHeal.doneKey),
      'true',
    );
    await db.customStatement('DELETE FROM dive_equipment');

    expect(await ComputerGearDiveHeal().run(), 0);
    expect(await equipmentOn('d1'), isEmpty);
  });
}

/// Runs [before] once, ahead of the first link, as a job running
/// alongside the pass would.
class _BeforeFirstLink extends DiveComputerGearLinker {
  _BeforeFirstLink(this.before);

  final Future<void> Function() before;
  var _ran = false;

  @override
  Future<int> linkComputerGearToDives({
    required String computerId,
    required Iterable<String> diveIds,
    Set<String>? removedKeys,
  }) async {
    if (!_ran) {
      _ran = true;
      await before();
    }
    return super.linkComputerGearToDives(
      computerId: computerId,
      diveIds: diveIds,
      removedKeys: removedKeys,
    );
  }
}
