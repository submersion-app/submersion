import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/services/equipment_set_for_computer_linker.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentSetForComputerLinker linker;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    linker = EquipmentSetForComputerLinker();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertGear(String id, {String type = 'computer'}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
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

  Future<void> linkSource(String diveId, String computerId) async {
    await db.customStatement(
      'INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, '
      'imported_at, created_at) VALUES (?, ?, ?, 1, 1, 1)',
      ['src-$diveId-$computerId', diveId, computerId],
    );
  }

  Future<void> insertSet(String id, {String? diverId}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: id,
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  Future<void> addToSet(String setId, String equipmentId) async {
    await db
        .into(db.equipmentSetItems)
        .insert(
          EquipmentSetItemsCompanion.insert(
            setId: setId,
            equipmentId: equipmentId,
          ),
        );
  }

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.map((r) => r.equipmentId).toSet();
  }

  test('applies the set that lists the dive computer as a member', () async {
    await insertGear('gear-computer');
    await insertGear('gear-drysuit', type: 'exposure');
    await insertGear('gear-fins', type: 'fins');
    await insertComputer('c1', equipmentId: 'gear-computer');
    await insertSet('set-ccr');
    await addToSet('set-ccr', 'gear-computer');
    await addToSet('set-ccr', 'gear-drysuit');
    await addToSet('set-ccr', 'gear-fins');
    await linkSource('dive1', 'c1');

    expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {
      'gear-computer',
      'gear-drysuit',
      'gear-fins',
    });
  });

  test('applies every set that lists the computer, additively', () async {
    await insertGear('gear-computer');
    await insertGear('gear-drysuit', type: 'exposure');
    await insertGear('gear-bailout', type: 'cylinder');
    await insertComputer('c1', equipmentId: 'gear-computer');
    await insertSet('set-rig');
    await addToSet('set-rig', 'gear-computer');
    await addToSet('set-rig', 'gear-drysuit');
    await insertSet('set-bailout');
    await addToSet('set-bailout', 'gear-computer');
    await addToSet('set-bailout', 'gear-bailout');
    await linkSource('dive1', 'c1');

    expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {
      'gear-computer',
      'gear-drysuit',
      'gear-bailout',
    });
  });

  test('adds to existing equipment rather than replacing it', () async {
    await insertGear('gear-computer');
    await insertGear('gear-drysuit', type: 'exposure');
    await insertComputer('c1', equipmentId: 'gear-computer');
    await insertSet('set-ccr');
    await addToSet('set-ccr', 'gear-computer');
    await addToSet('set-ccr', 'gear-drysuit');
    await linkSource('dive1', 'c1');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'dive1', equipmentId: 'a-bcd'),
        );

    expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {
      'a-bcd',
      'gear-computer',
      'gear-drysuit',
    });
  });

  test(
    'does not remove an item from a set applied separately by the defaulter',
    () async {
      // The defaulter tags rows with its own set's id; a later, additive call
      // from this linker must not steal that provenance for an item both
      // sets happen to share (GearExpander only fills a null viaSetId).
      await insertGear('gear-computer');
      await insertGear('gear-fins', type: 'fins');
      await insertComputer('c1', equipmentId: 'gear-computer');
      await insertSet('set-geo');
      await addToSet('set-geo', 'gear-fins');
      await insertSet('set-ccr');
      await addToSet('set-ccr', 'gear-computer');
      await addToSet('set-ccr', 'gear-fins');
      await linkSource('dive1', 'c1');
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(
              diveId: 'dive1',
              equipmentId: 'gear-fins',
              viaSetId: const Value('set-geo'),
            ),
          );

      expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isTrue);
      final finsRow = await (db.select(
        db.diveEquipment,
      )..where((t) => t.equipmentId.equals('gear-fins'))).getSingle();
      expect(finsRow.viaSetId, 'set-geo');
    },
  );

  test('is a no-op when the computer belongs to no set', () async {
    await insertGear('gear-computer');
    await insertComputer('c1', equipmentId: 'gear-computer');
    await linkSource('dive1', 'c1');

    expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isFalse);
    expect(await equipmentOn('dive1'), isEmpty);
  });

  test('never applies a set for a computer whose twin was deleted', () async {
    await insertComputer('c1');
    await linkSource('dive1', 'c1');

    expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isFalse);
    expect(await equipmentOn('dive1'), isEmpty);
  });

  test('is a no-op for a dive with no registered computer', () async {
    expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isFalse);
    expect(await equipmentOn('dive1'), isEmpty);
  });

  test('is idempotent', () async {
    await insertGear('gear-computer');
    await insertGear('gear-drysuit', type: 'exposure');
    await insertComputer('c1', equipmentId: 'gear-computer');
    await insertSet('set-ccr');
    await addToSet('set-ccr', 'gear-computer');
    await addToSet('set-ccr', 'gear-drysuit');
    await linkSource('dive1', 'c1');

    await linker.linkComputerSetsForDive(diveId: 'dive1');
    await linker.linkComputerSetsForDive(diveId: 'dive1');

    expect(await equipmentOn('dive1'), {'gear-computer', 'gear-drysuit'});
  });

  test('returns false instead of throwing when the read fails', () async {
    await insertGear('gear-computer');
    await insertComputer('c1', equipmentId: 'gear-computer');
    await linkSource('dive1', 'c1');
    await db.customStatement('DROP TABLE dive_data_sources');

    expect(await linker.linkComputerSetsForDive(diveId: 'dive1'), isFalse);
  });
}
