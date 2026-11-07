import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v344 adds `nav_tracks.source_file` (issue #4231): the original file a
/// route was imported from, so its points can be derived again and the file
/// exported unchanged. Nullable with no backfill: a route imported before
/// keeps none until it is updated from its file.
void main() {
  test('v344 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(344));
    expect(AppDatabase.migrationVersions, contains(344));
  });

  test('the compatibility floor does not move for a nullable column', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(344));
  });

  test('a fresh database has the column as a nullable BLOB', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('nav_tracks')").get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'source_file',
    );
    expect(column.read<String>('type'), 'BLOB');
    expect(column.read<int>('notnull'), 0);
  });

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing route upgrades with no source file', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 342');
        rawDb.execute('''
          CREATE TABLE nav_tracks (
            id TEXT NOT NULL PRIMARY KEY, dive_id TEXT,
            start_time INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO nav_tracks (id, created_at, updated_at) "
          "VALUES ('t1', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT source_file FROM nav_tracks WHERE id = 't1'")
        .getSingle();
    expect(row.data['source_file'], isNull);
  });
}
