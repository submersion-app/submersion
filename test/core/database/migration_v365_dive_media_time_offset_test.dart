import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v365 adds `dives.media_time_offset_seconds` (issue #4539): the seconds
/// added to each photo's capture time before it is placed on the dive, which
/// corrects a camera whose clock disagrees with the dive computer's. NOT NULL
/// with a default of 0, so every existing dive keeps placing media unshifted.
void main() {
  test('v365 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(365));
    expect(AppDatabase.migrationVersions, contains(365));
  });

  test(
    'a fresh database has the column, NOT NULL with a default of 0',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('dives')").get();
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'media_time_offset_seconds',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), '0');
    },
  );

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing dive upgrades to no shift', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 363');
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
        .customSelect(
          "SELECT media_time_offset_seconds FROM dives WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.read<int>('media_time_offset_seconds'), 0);
  });
}
