import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v388: `divers.emergency_tag_share`, the diver's emergency tag
/// choices as JSON (issue #5060). Nullable, no backfill, so the sync floor
/// holds.
void main() {
  NativeDatabase dbAt(int version, {bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL'
            '${withColumn ? ', emergency_tag_share TEXT' : ''})',
          );
          rawDb.execute(
            withColumn
                ? 'INSERT INTO divers (id, name, emergency_tag_share) '
                      "VALUES ('d1', 'Sam', '{\"primary\":\"call\"}')"
                : "INSERT INTO divers (id, name) VALUES ('d1', 'Sam')",
          );
        },
      );

  Future<Object?> stored(AppDatabase db) async =>
      (await db
              .customSelect('SELECT emergency_tag_share FROM divers')
              .getSingle())
          .data['emergency_tag_share'];

  test('v388 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(388));
    expect(AppDatabase.migrationVersions, contains(388));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(388));
  });

  test('upgrading from v387 adds the column, empty', () async {
    final db = AppDatabase(dbAt(387));
    addTearDown(db.close);
    expect(await stored(db), isNull);
  });

  test('a database that already has the column keeps its value', () async {
    final db = AppDatabase(dbAt(388, withColumn: true));
    addTearDown(db.close);
    expect(await stored(db), '{"primary":"call"}');
  });
}
