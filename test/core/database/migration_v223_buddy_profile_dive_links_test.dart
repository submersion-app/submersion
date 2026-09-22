import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v223 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 223);
    expect(AppDatabase.migrationVersions, contains(223));
    expect(AppDatabase.migrationStepCount(222), 1);
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('a fresh database has both columns, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final buddyCols = await db
        .customSelect("PRAGMA table_info('buddies')")
        .get();
    final buddyByName = {for (final c in buddyCols) c.read<String>('name'): c};
    expect(buddyByName, contains('linked_diver_id'));
    expect(buddyByName['linked_diver_id']!.read<int>('notnull'), 0);

    final diveCols = await db.customSelect("PRAGMA table_info('dives')").get();
    final diveByName = {for (final c in diveCols) c.read<String>('name'): c};
    expect(diveByName, contains('outing_id'));
    expect(diveByName['outing_id']!.read<int>('notnull'), 0);
  });

  test(
    'buddies.linked_diver_id references divers with ON DELETE SET NULL',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final fks = await db
          .customSelect("PRAGMA foreign_key_list('buddies')")
          .get();
      final link = fks.firstWhere(
        (r) => r.read<String>('from') == 'linked_diver_id',
      );
      expect(link.read<String>('table'), 'divers');
      expect(link.read<String>('on_delete'), 'SET NULL');
    },
  );

  test('a v222 database upgrades to v223 with both columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 222');
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT REFERENCES divers (id),
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final buddyCols = await db
        .customSelect("PRAGMA table_info('buddies')")
        .get();
    expect(
      buddyCols.map((c) => c.read<String>('name')),
      contains('linked_diver_id'),
    );
    final diveCols = await db.customSelect("PRAGMA table_info('dives')").get();
    expect(diveCols.map((c) => c.read<String>('name')), contains('outing_id'));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 223);
  });

  test('the asserts are no-ops when the tables are absent', () async {
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
