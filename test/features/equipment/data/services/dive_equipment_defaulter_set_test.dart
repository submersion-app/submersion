import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';

/// The defaulter already knows which set won; it now says so on every row
/// (issue #1487), so the dive remembers the set that was applied.
void main() {
  late AppDatabase db;
  late EquipmentSetRepository sets;
  late DiveEquipmentDefaulter defaulter;

  setUp(() async {
    db = await setUpTestDatabase();
    // Junction writes without a full Dive fixture, as in the sibling test.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    sets = EquipmentSetRepository();
    defaulter = DiveEquipmentDefaulter();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['reg', 'fins']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('rows written by the default set carry its id', () async {
    await sets.createSet(
      EquipmentSet(
        id: 'def',
        diverId: 'd1',
        name: 'Default',
        equipmentIds: const ['reg', 'fins'],
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await sets.setAsDefault('def', diverId: 'd1');

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isTrue);
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals('dive1'))).get();
    expect(rows.map((r) => r.equipmentId), unorderedEquals(['reg', 'fins']));
    expect(rows.map((r) => r.viaSetId), everyElement('def'));
  });
}
