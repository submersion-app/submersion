import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v149 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(149));
    expect(AppDatabase.migrationVersions, contains(149));
  });

  test(
    'a fresh database has certifications.agency_custom/level_custom',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('certifications')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('agency_custom'));
      expect(names, contains('level_custom'));
    },
  );

  test(
    'a database stranded before v149 gains the columns via beforeOpen',
    () async {
      // Only the columns this migration touches are omitted; the beforeOpen
      // backstop must add them even when onUpgrade never ran.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            level TEXT
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('certifications')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('agency_custom'));
      expect(names, contains('level_custom'));
    },
  );

  test('the v149 onUpgrade step adds the columns to a v148 database', () async {
    // Stamp user_version=148 so drift runs onUpgrade(148, 149) - the
    // migration step itself, not just the beforeOpen backstop.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            level TEXT
          )
        ''');
        rawDb.execute('PRAGMA user_version = 148');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('certifications')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('agency_custom'));
    expect(names, contains('level_custom'));
  });

  test(
    'the assert is a no-op when the certifications table is absent',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('CREATE TABLE unrelated (id TEXT)');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      // Opening must not throw on a minimal fixture.
      await db.customSelect('SELECT 1').get();
    },
  );
}
