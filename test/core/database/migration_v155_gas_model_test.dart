import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Minimal pre-v155 diver_settings stamped at v154, so opening it runs the
/// 154 -> 155 rung of the ladder rather than only the beforeOpen backstop.
///
/// 154 rather than 153 because #1104 claimed 154 on main while this branch
/// was open; stamping at 154 keeps the fixture scoped to this migration
/// instead of also triggering that one.
NativeDatabase _dbAt154() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 154');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      rawDb.execute(
        "INSERT INTO diver_settings (id, created_at, updated_at) "
        "VALUES ('ds1', 0, 0)",
      );
    },
  );
}

/// v155 adds the gas model preference to diver_settings (issue #828).
void main() {
  test('v155 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(155));
    expect(AppDatabase.migrationVersions, contains(155));
  });

  test('a fresh database has diver_settings.gas_model', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('gas_model'));
  });

  test('the column defaults to real gas', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'gas_model',
    );
    // Defaulting to the real model reproduces the compressibility-corrected
    // math the app used unconditionally before the preference existed, so
    // upgrading does not move anybody's logged SAC.
    expect(column.read<String?>('dflt_value'), contains('real'));
  });

  test(
    'a database stranded before v155 gains the column via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('gas_model'));
    },
  );

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });

  test('the 154 -> 155 upgrade adds the column to an existing row', () async {
    final db = AppDatabase(_dbAt154());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('gas_model'));

    // A diver who already had settings keeps the pre-#828 behavior rather
    // than silently switching to the other gas model. This open runs both the
    // ladder rung and the beforeOpen backstop, so it also proves the assert
    // does not try to re-add a column the migration just created.
    final row = await db
        .customSelect('SELECT gas_model FROM diver_settings')
        .getSingle();
    expect(row.read<String>('gas_model'), 'real');
  });
}
