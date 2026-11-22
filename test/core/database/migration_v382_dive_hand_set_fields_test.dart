import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v382 adds `dives.hand_set_fields` (issue #4909): the computer-written
/// values the diver set by hand, which a re-parse and a resync keep.
/// Nullable with no backfill: only edits saved after the update are marked,
/// so every existing dive upgrades to none marked and the floor holds.
void main() {
  test('v382 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(382));
    expect(AppDatabase.migrationVersions, contains(382));
  });

  test('the new column kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(382));
  });

  test('a fresh database has the column, nullable', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'hand_set_fields',
    );
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String>('type'), 'TEXT');
  });

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing dive upgrades to nothing marked', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 381');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
        ''');
        rawDb.execute(
          "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
          "VALUES ('d1', 0, 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT hand_set_fields FROM dives WHERE id = 'd1'")
        .getSingle();
    expect(row.readNullable<String>('hand_set_fields'), isNull);
  });
}
