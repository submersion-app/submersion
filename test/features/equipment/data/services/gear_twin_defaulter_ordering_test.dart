import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide EquipmentSet;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';

/// The defaulter bails when the dive already has any dive_equipment row, so
/// running the gear linker FIRST would silently suppress the diver's default
/// and geofenced equipment sets. A downloaded dive must receive both.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['a-bcd', 'gear-1']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: id == 'gear-1' ? 'computer' : 'bcd',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'c1',
            name: 'c1',
            equipmentId: const Value('gear-1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db.customStatement(
      "INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, "
      "imported_at, created_at) VALUES ('s1', 'dive1', 'c1', 1, 1, 1)",
    );
    final sets = EquipmentSetRepository();
    await sets.createSet(
      EquipmentSet(
        id: 'def',
        diverId: 'd1',
        name: 'def',
        equipmentIds: const ['a-bcd'],
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await sets.setAsDefault('def', diverId: 'd1');
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.map((r) => r.equipmentId).toSet();
  }

  test('defaulter first, then linker: the dive gets BOTH', () async {
    await DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );
    await DiveComputerGearLinker().linkComputerGearForDive(diveId: 'dive1');

    expect(await equipmentOn('dive1'), {'a-bcd', 'gear-1'});
  });

  test(
    'linker first would suppress the default set, proving the order',
    () async {
      await DiveComputerGearLinker().linkComputerGearForDive(diveId: 'dive1');
      final applied = await DiveEquipmentDefaulter()
          .applyDefaultEquipmentIfEmpty(
            diveId: 'dive1',
            diverId: 'd1',
            divePoints: const [],
          );

      expect(applied, isFalse);
      expect(await equipmentOn('dive1'), {'gear-1'});
    },
  );
}
