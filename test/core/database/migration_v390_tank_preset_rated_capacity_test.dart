import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v390: `tank_presets.rated_capacity_cuft` (REAL, nullable), the
/// manufacturer's rated capacity a custom preset copied from a built-in keeps
/// (issue #800). Nullable with no backfill, so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool withColumn = false}) {
    final extra = withColumn ? ', rated_capacity_cuft REAL' : '';
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $version');
        rawDb.execute(
          'CREATE TABLE tank_presets (id TEXT NOT NULL PRIMARY KEY, '
          'name TEXT NOT NULL$extra)',
        );
        if (withColumn) {
          rawDb.execute(
            'INSERT INTO tank_presets (id, name, rated_capacity_cuft) '
            "VALUES ('p1', 'al80_copy', 77.4)",
          );
        } else {
          rawDb.execute(
            "INSERT INTO tank_presets (id, name) VALUES ('p1', 'mine')",
          );
        }
      },
    );
  }

  Future<Map<String, Object?>> stored(AppDatabase db) async =>
      (await db
              .customSelect('SELECT rated_capacity_cuft FROM tank_presets')
              .getSingle())
          .data;

  test('v390 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(390));
    expect(AppDatabase.migrationVersions, contains(390));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(390));
  });

  test(
    'upgrading from v389 leaves an existing preset with no rating',
    () async {
      final db = AppDatabase(dbAt(389));
      addTearDown(db.close);
      expect(await stored(db), {'rated_capacity_cuft': null});
    },
  );

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(389, withColumn: true));
    addTearDown(db.close);
    expect(await stored(db), {'rated_capacity_cuft': 77.4});
  });
}
