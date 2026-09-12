import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer's equipment tombstone must apply even when a local cylinder is
/// linked to that item (dive_tanks.equipment_id, written by the transmitter
/// registry). The link was a NO ACTION foreign key, so the delete failed and
/// the item survived on this device.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  test(
    'applying an equipment deletion clears a cylinder linked to it',
    () async {
      final db = DatabaseService.instance.database;
      await serializer.upsertRecord('equipment', {
        'id': 'cyl',
        'name': 'Blue AL80',
        'type': 'tank',
        'status': 'active',
        'purchaseCurrency': 'USD',
        'notes': '',
        'isActive': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
        "VALUES ('d1', 1000, 1000, 1000)",
      );
      await db.customStatement(
        'INSERT INTO dive_tanks (id, dive_id, equipment_id) '
        "VALUES ('t1', 'd1', 'cyl')",
      );

      await serializer.deleteRecord('equipment', 'cyl');

      expect(await serializer.fetchRecord('equipment', 'cyl'), isNull);
      final tank = await db
          .customSelect("SELECT equipment_id FROM dive_tanks WHERE id = 't1'")
          .getSingle();
      expect(tank.read<String?>('equipment_id'), isNull);
    },
  );
}
