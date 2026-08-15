import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v151 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(151));
    expect(AppDatabase.migrationVersions, contains(151));
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
    'a database stranded before v151 gains the columns via beforeOpen',
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

  test('the v151 onUpgrade step adds the columns to a v150 database', () async {
    // Stamp user_version=150 so drift runs onUpgrade(150, 151) - the
    // migration step itself, not just the beforeOpen backstop, and isolated
    // to this single step rather than replaying main's v149/v150 blocks.
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
        rawDb.execute('PRAGMA user_version = 150');
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
