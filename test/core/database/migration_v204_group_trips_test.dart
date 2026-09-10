import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v204 is the current schema version and is in the ladder', () {
    // Renumbered twice: #1677 took v200, then the cell linearity link (201),
    // condition intelligence (202) and equipment assemblies (203) all landed
    // while this branch was open. A rung at or below the shipped version
    // never runs its onUpgrade step, so this one has to sit on top.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(204));
    expect(AppDatabase.migrationVersions, contains(204));
  });

  test(
    'a fresh database has diver_settings.group_trips_in_dive_list, off',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'group_trips_in_dive_list',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), contains('0'));
    },
  );

  test(
    'a database stranded before v204 gains the column via beforeOpen',
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
      expect(names, contains('group_trips_in_dive_list'));
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
