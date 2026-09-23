import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v220 is in the ladder', () {
    // The newest rung owns the exact currentSchemaVersion/step-count
    // assertions; relaxed here once v221 (rental gear memory) landed on top.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(220));
    expect(AppDatabase.migrationVersions, contains(220));
    expect(AppDatabase.migrationStepCount(219), greaterThanOrEqualTo(1));
  });

  test('the column is additive, so the sync floor does not move', () {
    // The floor moved to 224 with the media fact clocks; this rung
    // still did not move it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has the column, defaulting to off', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('equipment_sets')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName, contains('auto_apply_on_computer_import'));
    expect(byName['auto_apply_on_computer_import']!.read<int>('notnull'), 1);
  });

  test(
    'a database stranded before v220 gains the column via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE equipment_sets (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('equipment_sets')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('auto_apply_on_computer_import'));
    },
  );

  test(
    'a v219 database upgrades and gains the column, defaulting to off',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 219');
          rawDb.execute('''
          CREATE TABLE equipment_sets (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('equipment_sets')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('auto_apply_on_computer_import'));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(
        version.read<int>('user_version'),
        AppDatabase.currentSchemaVersion,
      );
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
}
