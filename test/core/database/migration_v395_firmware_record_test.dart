import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v395: `service_records.firmware_version` (TEXT, nullable), the
/// version a firmware update installed (issue #5104). Nullable, no backfill,
/// so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool withColumn = false}) {
    final extra = withColumn ? ', firmware_version TEXT' : '';
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $version');
        rawDb.execute(
          'CREATE TABLE service_records (id TEXT NOT NULL PRIMARY KEY, '
          'equipment_id TEXT NOT NULL, service_category TEXT NOT NULL$extra)',
        );
        if (withColumn) {
          rawDb.execute(
            'INSERT INTO service_records '
            '(id, equipment_id, service_category, firmware_version) '
            "VALUES ('r1', 'e1', 'firmwareUpdate', 'V95')",
          );
        } else {
          rawDb.execute(
            'INSERT INTO service_records (id, equipment_id, service_category) '
            "VALUES ('r1', 'e1', 'annual')",
          );
        }
      },
    );
  }

  Future<Map<String, Object?>> stored(AppDatabase db) async =>
      (await db
              .customSelect('SELECT firmware_version FROM service_records')
              .getSingle())
          .data;

  test('v395 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(395));
    expect(AppDatabase.migrationVersions, contains(395));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(395));
  });

  test(
    'upgrading from v394 leaves existing records without a version',
    () async {
      final db = AppDatabase(dbAt(394));
      addTearDown(db.close);
      expect(await stored(db), {'firmware_version': null});
    },
  );

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(394, withColumn: true));
    addTearDown(db.close);
    expect(await stored(db), {'firmware_version': 'V95'});
  });
}
