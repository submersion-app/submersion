import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('version bookkeeping', () {
    expect(AppDatabase.currentSchemaVersion, 384);
    expect(AppDatabase.migrationVersions, contains(384));
    expect(
      AppDatabase.migrationStepCount(383),
      AppDatabase.migrationStepCount(384) + 1,
    );
    // An additive column: the floor does not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 381);
  });

  test('v383 packed gear stays on the trip and starts unassigned', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 383');
          rawDb.execute('''
            CREATE TABLE trip_equipment (
              id TEXT NOT NULL PRIMARY KEY,
              trip_id TEXT NOT NULL,
              equipment_id TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute(
            "INSERT INTO trip_equipment VALUES ('row', 'trip', 'wing', 123)",
          );
        },
      ),
    );
    addTearDown(db.close);

    final row = await db
        .customSelect('SELECT * FROM trip_equipment')
        .getSingle();
    expect(row.read<String>('trip_id'), 'trip');
    expect(row.read<String>('equipment_id'), 'wing');
    expect(row.readNullable<String>('bag_equipment_id'), isNull);
    expect(row.readNullable<String>('bag_hlc'), isNull);
  });
}
