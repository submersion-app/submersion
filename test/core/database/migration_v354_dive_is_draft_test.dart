import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v354 adds `dives.is_draft` (issue #637): a dive marked at the site, with
/// entry and exit times but no dive computer readings yet. NOT NULL with a
/// false default, so every existing dive stays an ordinary logged dive.
void main() {
  test('v354 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(354));
    expect(AppDatabase.migrationVersions, contains(354));
  });

  test(
    'a fresh database has the column, NOT NULL with a false default',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('dives')").get();
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'is_draft',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), '0');
    },
  );

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing dive upgrades to not a draft', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 351');
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
        .customSelect("SELECT is_draft FROM dives WHERE id = 'd1'")
        .getSingle();
    expect(row.read<int>('is_draft'), 0);
  });

  /// v354 also creates dive_health_records, Apple Health readings per dive.
  test('an upgraded database has the health records table', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 351');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_health_records')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      containsAll(['dive_id', 'heart_rate_samples', 'settled', 'hlc']),
    );
  });
}
