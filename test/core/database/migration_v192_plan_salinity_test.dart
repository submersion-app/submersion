import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v192 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(192));
    expect(AppDatabase.migrationVersions, contains(192));
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
    'a database stranded before v192 gains salinity_ppt via beforeOpen',
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
}
