import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerGearLinker linker;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    linker = DiveComputerGearLinker();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertGear(String id) async {
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

  Future<void> linkSource(String diveId, String computerId) async {
    await db.customStatement(
      'INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, '
      'imported_at, created_at) VALUES (?, ?, ?, 1, 1, 1)',
      ['src-$diveId-$computerId', diveId, computerId],
    );
  }

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.map((r) => r.equipmentId).toSet();
  }

  test('attaches the gear twin of the computer that logged the dive', () async {
    await insertGear('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await linkSource('dive1', 'c1');

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {'gear-1'});
  });

  test('attaches every computer on a multi-source dive', () async {
    // dives.computer_id holds only the primary; a twin-computer diver must get
    // both, which is why the linker reads dive_data_sources.
    await insertGear('gear-1');
    await insertGear('gear-2');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertComputer('c2', equipmentId: 'gear-2');
    await linkSource('dive1', 'c1');
    await linkSource('dive1', 'c2');

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {'gear-1', 'gear-2'});
  });

  test('adds to existing equipment rather than replacing it', () async {
    // Unlike the defaulter, the linker is not gated on the dive being empty.
    await insertGear('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await linkSource('dive1', 'c1');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'dive1', equipmentId: 'a-bcd'),
        );

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {'a-bcd', 'gear-1'});
  });

  test(
    'never creates equipment for a computer whose twin was deleted',
    () async {
      await insertComputer('c1');
      await linkSource('dive1', 'c1');

      expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isFalse);
      expect(await equipmentOn('dive1'), isEmpty);
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM equipment')
          .getSingle();
      expect(count.read<int>('c'), 0);
    },
  );

  test('is a no-op for a dive with no registered computer', () async {
    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isFalse);
    expect(await equipmentOn('dive1'), isEmpty);
  });

  test('is idempotent', () async {
    await insertGear('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await linkSource('dive1', 'c1');

    await linker.linkComputerGearForDive(diveId: 'dive1');
    await linker.linkComputerGearForDive(diveId: 'dive1');

    expect(await equipmentOn('dive1'), {'gear-1'});
  });

  test('returns false instead of throwing when the read fails', () async {
    // Best-effort by contract: gear linking must never abort a download or
    // import that has already persisted the dive.
    await insertGear('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await linkSource('dive1', 'c1');
    await db.customStatement('DROP TABLE dive_data_sources');

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isFalse);
  });
}
