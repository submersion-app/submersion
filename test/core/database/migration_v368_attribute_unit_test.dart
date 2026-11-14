import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v368: equipment_attributes.value_unit, the unit an item's own
/// number reads in (issue #4534). Nullable and never backfilled: a row made
/// before this column follows the diver's settings, as it always did.
void main() {
  NativeDatabase dbAt(int version, {required bool withColumn}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE equipment_attributes (id TEXT NOT NULL PRIMARY KEY, '
            'equipment_id TEXT NOT NULL, attr_key TEXT NOT NULL, '
            'is_custom INTEGER NOT NULL DEFAULT 0, value_text TEXT, '
            'value_num REAL, sort_order INTEGER NOT NULL DEFAULT 0, '
            'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
            "hlc TEXT${withColumn ? ', value_unit TEXT' : ''})",
          );
          rawDb.execute(
            'INSERT INTO equipment_attributes (id, equipment_id, attr_key, '
            "value_num, created_at, updated_at) VALUES ('a1', 'e1', "
            "'gauge_max_pressure_bar', 300, 1, 1)",
          );
        },
      );

  Future<List<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('equipment_attributes')").get())
          .map((row) => row.read<String>('name'))
          .toList();

  test('v368 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(368));
    expect(AppDatabase.migrationVersions, contains(368));
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(368));
  });

  test(
    'upgrading adds the column and leaves rows following the diver',
    () async {
      final db = AppDatabase(dbAt(367, withColumn: false));
      addTearDown(db.close);

      expect(await columns(db), contains('value_unit'));
      final row = await db
          .customSelect(
            "SELECT value_unit FROM equipment_attributes WHERE id = 'a1'",
          )
          .getSingle();
      expect(row.read<String?>('value_unit'), isNull);
    },
  );

  test('a database that skipped the rung gets the column on open', () async {
    final db = AppDatabase(dbAt(368, withColumn: false));
    addTearDown(db.close);

    expect(await columns(db), contains('value_unit'));
  });
}
