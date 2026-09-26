import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The item page's Dives row counts what tapping it lists (issue #2046):
/// the active diver's dives, linked as gear or through a tank slot.
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
    for (final (id, diver) in [
      ('d1', 'owner'),
      ('d2', 'owner'),
      ('d3', 'wife'),
    ]) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at) VALUES ('$id', '$diver', 0, 0, 0)",
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
  });

  tearDown(tearDownTestDatabase);

  test('counts the active diver dives with the dive filter link set', () async {
    final repo = EquipmentRepository();
    expect(await repo.getDiveCountForEquipment('cyl', diverId: 'owner'), 2);
    expect(await repo.getDiveCountForEquipment('cyl', diverId: 'wife'), 1);
    expect(await repo.getDiveCountForEquipment('cyl'), 3);
  });

  test('a dive linked both ways counts once', () async {
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, equipment_id) '
      "VALUES ('t1', 'd1', 'cyl')",
    );
    expect(
      await EquipmentRepository().getDiveCountForEquipment(
        'cyl',
        diverId: 'owner',
      ),
      2,
    );
  });
}
