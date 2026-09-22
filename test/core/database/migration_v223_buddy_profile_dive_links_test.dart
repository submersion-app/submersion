import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v223 is at or below the current schema version and in the ladder', () {
    // Relaxed once v224 (the media fact clocks) landed on top; the newest
    // rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(223));
    expect(AppDatabase.migrationVersions, contains(223));
    expect(AppDatabase.migrationStepCount(222), greaterThanOrEqualTo(1));
  });

  test('these columns are additive and did not move the sync floor', () {
    // The floor is 224, raised by the media fact clocks, whose own test
    // owns that number. This rung did not raise it: an older reader simply
    // never sees a buddy's profile link or a dive's outing. Asserting the
    // current value keeps the pair honest, so moving the floor fails both
    // tests rather than silently passing this one.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
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

  test('a v222 database upgrades with both columns', () async {
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
    expect(version.read<int>('user_version'), AppDatabase.currentSchemaVersion);
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
