import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('the floor rises to 383', () {
    // A peer below 383 reads a gear item's stale is_done instead of the
    // trip's packs, so it is held until it updates.
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(383),
    );
  });

  test(
    'v382 checklist rows keep their checkmarks and gain no equipment link',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 382');
            rawDb.execute('''
            CREATE TABLE trip_checklist_items (
              id TEXT NOT NULL PRIMARY KEY,
              title TEXT NOT NULL,
              is_done INTEGER NOT NULL,
              completed_at INTEGER
            )
          ''');
            rawDb.execute(
              "INSERT INTO trip_checklist_items VALUES ('item', 'Mask', 1, 123)",
            );
          },
        ),
      );
      addTearDown(db.close);

      final row = await db
          .customSelect('SELECT * FROM trip_checklist_items')
          .getSingle();
      expect(row.read<String>('title'), 'Mask');
      expect(row.read<int>('is_done'), 1);
      expect(row.read<int>('completed_at'), 123);
      expect(row.readNullable<String>('equipment_id'), isNull);
      expect(AppDatabase.migrationVersions, contains(383));
    },
  );
}
