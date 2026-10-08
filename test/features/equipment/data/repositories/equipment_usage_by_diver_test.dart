import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The History card's dives (issue #2046): the service clocks' dive set,
/// each dive with its diver.
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
    for (final (id, diver, at) in [
      ('d1', 'owner', 1000),
      ('d2', 'wife', 2000),
      ('d3', 'wife', 3000),
    ]) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at) VALUES ('$id', '$diver', $at, $at, $at)",
      );
    }
    // d1 carries the cylinder as gear; d2 only through a tank slot; d3 not
    // at all.
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d1', 'cyl')",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, equipment_id) '
      "VALUES ('t2', 'd2', 'cyl')",
    );
  });

  tearDown(tearDownTestDatabase);

  test('returns the clock dive set with each dive diver', () async {
    final repo = EquipmentRepository();
    final item = (await repo.getEquipmentById('cyl'))!;
    final usage = await repo.getUsageByDiver(item);
    expect(
      {for (final u in usage) u.diveId: u.diverId},
      {'d1': 'owner', 'd2': 'wife'},
    );
    expect(usage.map((u) => u.date.millisecondsSinceEpoch), [1000, 2000]);
  });
}
