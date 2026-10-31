import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v330 adds `buddies.excluded_from_rankings` (issue #3624): a diver can keep
/// a buddy, such as a placeholder for someone whose name they forgot, out of
/// the buddy rankings while the dives still count as buddy dives. NOT NULL
/// with a false default, so every existing buddy stays ranked.
void main() {
  test('v330 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(330));
    expect(AppDatabase.migrationVersions, contains(330));
  });

  test(
    'a fresh database has the column, NOT NULL with a false default',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('buddies')").get();
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'excluded_from_rankings',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), '0');
    },
  );

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing buddy upgrades to ranked', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 327');
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            email TEXT, phone TEXT, photo_path TEXT,
            notes TEXT NOT NULL DEFAULT '',
            is_favorite INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO buddies (id, name, created_at, updated_at) "
          "VALUES ('b1', 'B1', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT excluded_from_rankings FROM buddies WHERE id = 'b1'",
        )
        .getSingle();
    expect(row.read<int>('excluded_from_rankings'), 0);
  });
}
