import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _columns = {
  'ccr_setpoint_low': '0.7',
  'ccr_setpoint_high': '1.3',
  'ccr_diluent_mod_pp_o2': '1.6',
};

void main() {
  test('v231 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 231);
    expect(AppDatabase.migrationVersions, contains(231));
    expect(AppDatabase.migrationStepCount(230), 1);
  });

  test('the columns are additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has the CCR ppO2 limits with defaults', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    for (final entry in _columns.entries) {
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == entry.key,
      );
      expect(column.read<int>('notnull'), 1, reason: entry.key);
      expect(
        column.read<String?>('dflt_value'),
        contains(entry.value),
        reason: entry.key,
      );
    }
  });

  test('a database stranded before v231 gains the columns', () async {
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
    expect(names, containsAll(_columns.keys));
  });
}
