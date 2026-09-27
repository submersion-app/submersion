import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v237 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 237);
    expect(AppDatabase.migrationVersions, contains(237));
    expect(AppDatabase.migrationStepCount(233), 1);
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has the switch, off', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'show_dive_figure',
    );
    expect(column.read<int>('notnull'), 1);
    expect(column.read<String?>('dflt_value'), contains('0'));
  });

  test('a database stranded before v237 gains the column', () async {
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
    expect(names, contains('show_dive_figure'));
  });
}
