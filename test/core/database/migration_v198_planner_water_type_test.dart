import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v198 is the current schema version and is in the ladder', () {
    // Renumbered from 193: main landed the transmitter-serial and
    // media_species.hlc rungs at 194 and 195 while this branch was open, 196
    // is held by another open branch, and a rung at or below the shipped
    // version never runs its onUpgrade step. Relaxed to
    // greaterThanOrEqualTo once v199 (certification dual credentials) landed
    // on top; the newest rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(198));
    expect(AppDatabase.migrationVersions, contains(198));
  });

  test(
    'a fresh database has diver_settings.default_planner_water_type as salt',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'default_planner_water_type',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), contains('salt'));
    },
  );

  test(
    'a database stranded before v198 gains the column via beforeOpen',
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
      expect(names, contains('default_planner_water_type'));
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
