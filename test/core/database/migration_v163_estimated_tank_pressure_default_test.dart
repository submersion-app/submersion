import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Minimal pre-v163 diver_settings stamped at v161, so opening it runs the
/// 161 -> 163 rung of the ladder rather than only the beforeOpen backstop.
NativeDatabase _dbAt161() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 161');
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

/// v163 adds the switch that suppresses synthesized "(est.)" tank pressure
/// lines on the profile chart (issue #731). v162 is skipped rather than
/// missing: main was at v161 when this branch was cut, and the open PR #1287
/// (issue #1090) had already written 162 on its own branch.
void main() {
  test('v163 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(163));
    expect(AppDatabase.migrationVersions, contains(163));
  });

  test(
    'a fresh database has diver_settings.default_show_estimated_tank_pressure',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('default_show_estimated_tank_pressure'));
    },
  );

  test('the column defaults to showing estimates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'default_show_estimated_tank_pressure',
    );
    // Estimates shipped always-on, so defaulting to 1 means upgrading does not
    // silently remove a line a diver was already reading.
    expect(column.read<String?>('dflt_value'), '1');
  });

  test(
    'a database stranded before v163 gains the column via beforeOpen',
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
      expect(names, contains('default_show_estimated_tank_pressure'));
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

  test(
    'the 161 -> 163 upgrade keeps estimates on for an existing row',
    () async {
      final db = AppDatabase(_dbAt161());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      expect(
        cols.map((c) => c.read<String>('name')),
        contains('default_show_estimated_tank_pressure'),
      );

      // This open runs both the ladder rung and the beforeOpen backstop, so it
      // also proves the assert does not try to re-add a column the migration
      // just created.
      final row = await db
          .customSelect(
            'SELECT default_show_estimated_tank_pressure FROM diver_settings',
          )
          .getSingle();
      expect(row.read<bool>('default_show_estimated_tank_pressure'), isTrue);
    },
  );
}
