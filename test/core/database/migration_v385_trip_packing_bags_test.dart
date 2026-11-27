import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('version bookkeeping', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(385));
    expect(AppDatabase.migrationVersions, contains(385));
    expect(
      AppDatabase.migrationStepCount(384),
      AppDatabase.migrationStepCount(385) + 1,
    );
    // An additive column: v385 left the floor at 384. v386 (derived course
    // requirements) raised it later.
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(384),
    );
  });

  test('v384 packed gear stays on the trip and starts unassigned', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 384');
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
