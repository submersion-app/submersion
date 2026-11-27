import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The dives a photo picker opens on for a gear item (issue #5046): the
/// same dives the item page's Dives row counts.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['owner', 'wife']) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 0, 0)",
      );
    }
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at, '
      "diver_id) VALUES ('cyl', 'AL80', 'tank', 0, 0, 'owner')",
    );
    for (final (id, diver, at, planned) in [
      ('d1', 'owner', 100, 0),
      ('d2', 'owner', 200, 0),
      ('d3', 'wife', 300, 0),
      ('d4', 'owner', 400, 1),
    ]) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at, is_planned) VALUES ('$id', '$diver', $at, 0, 0, $planned)",
      );
    }
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d1', 'cyl')",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, equipment_id) '
      "VALUES ('t2', 'd2', 'cyl')",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d3', 'cyl')",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d4', 'cyl')",
    );
  });

  tearDown(tearDownTestDatabase);

  test('getDiveIdsForEquipment matches getDiveCountForEquipment', () async {
    final repo = EquipmentRepository();
    for (final diver in ['owner', 'wife', null]) {
      final ids = await repo.getDiveIdsForEquipment('cyl', diverId: diver);
      expect(
        ids.length,
        await repo.getDiveCountForEquipment('cyl', diverId: diver),
      );
    }
  });

  test('lists the diver dives newest first, without planned dives', () async {
    final repo = EquipmentRepository();
    expect(await repo.getDiveIdsForEquipment('cyl', diverId: 'owner'), [
      'd2',
      'd1',
    ]);
  });
}
