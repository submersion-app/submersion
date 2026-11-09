import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v353: dive_profile_series.is_edit (issue #4386), the synced mark
/// that a series is the diver's manual edit.
void main() {
  /// A v352 database: a live edit over the demoted parse it corrects.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 352');
      rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute('''
        CREATE TABLE dive_profile_series (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          is_primary INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute("INSERT INTO dives (id) VALUES ('dive-1')");
      rawDb.execute('''
        INSERT INTO dive_profile_series
          (id, dive_id, computer_id, is_primary, created_at, updated_at)
        VALUES ('edit', 'dive-1', NULL, 1, 200, 200),
               ('parse', 'dive-1', NULL, 0, 100, 200)
      ''');
    },
  );

  test('v353 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(353));
    expect(AppDatabase.migrationVersions, contains(353));
    expect(
      AppDatabase.migrationStepCount(352),
      greaterThan(AppDatabase.migrationStepCount(353)),
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(353));
  });

  test('upgrading from v352 adds the column and marks nothing', () async {
    // No backfill: a series written before the rung is unknown, and keeps
    // the shape rule that told an edit apart until now.
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final rows = await db
        .customSelect('SELECT id, is_edit FROM dive_profile_series ORDER BY id')
        .get();
    expect(
      {for (final r in rows) r.read<String>('id'): r.data['is_edit']},
      {'edit': null, 'parse': null},
    );
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profile_series')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('is_edit'));
  });
}
