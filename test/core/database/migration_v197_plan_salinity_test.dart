import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v197 is in the ladder', () {
    // Renumbered from 192: main landed the transmitter-serial and
    // media_species.hlc rungs at 194 and 195 while this branch was open, and
    // 196 is held by another open branch.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(197));
    expect(AppDatabase.migrationVersions, contains(197));
  });

  test('a fresh database has dive_plans.salinity_ppt as nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dive_plans')").get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'salinity_ppt',
    );
    expect(column.read<int>('notnull'), 0);
  });

  test(
    'a database stranded before v197 gains salinity_ppt via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dive_plans (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            gf_low INTEGER NOT NULL,
            gf_high INTEGER NOT NULL,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('dive_plans')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('salinity_ppt'));
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
