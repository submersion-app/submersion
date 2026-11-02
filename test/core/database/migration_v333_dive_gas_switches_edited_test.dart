import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v333 adds `dives.gas_switches_edited` (issue #32): set once the diver
/// saves a change to a dive's gas switches, after which a re-parse and a
/// file resync leave the switch list alone. NOT NULL with a false default,
/// so every existing dive keeps today's behaviour.
void main() {
  test('v333 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(333));
    expect(AppDatabase.migrationVersions, contains(333));
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
        (c) => c.read<String>('name') == 'gas_switches_edited',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), '0');
    },
  );

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing dive upgrades to unedited', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 330');
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
        .customSelect("SELECT gas_switches_edited FROM dives WHERE id = 'd1'")
        .getSingle();
    expect(row.read<int>('gas_switches_edited'), 0);
  });
}
