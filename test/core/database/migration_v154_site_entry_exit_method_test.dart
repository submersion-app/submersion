import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v154 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(154));
    expect(AppDatabase.migrationVersions, contains(154));
  });

  test(
    'a fresh database has the dive_sites entry/exit method columns',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('dive_sites')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('entry_method'));
      expect(names, contains('exit_method'));
    },
  );

  test(
    'a database stranded before v154 gains both columns via beforeOpen',
    () async {
      // Only the columns this migration touches are modelled. The beforeOpen
      // backstop must add them even when onUpgrade never ran, which happens
      // when a parallel branch already stamped this version number.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dive_sites (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            water_type TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('dive_sites')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('entry_method'));
      expect(names, contains('exit_method'));
    },
  );

  test('the assert is a no-op when the dive_sites table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    // Opening must not throw on a minimal fixture.
    await db.customSelect('SELECT 1').get();
  });

  test('the assert leaves exactly one copy of each column', () async {
    // beforeOpen re-runs the helper on every open, so a healthy database must
    // survive the second pass rather than failing on a duplicate column.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final cols = await db.customSelect("PRAGMA table_info('dive_sites')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'entry_method').length, 1);
    expect(names.where((n) => n == 'exit_method').length, 1);
  });
}
