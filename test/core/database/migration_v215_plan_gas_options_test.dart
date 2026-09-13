import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v215 is the current schema version and is in the ladder', () {
    // Renumbered repeatedly (202, 212) as main shipped 211 and 213 while this
    // branch was open, including the 212 main had reserved for it: a rung at
    // or below the shipped version never runs its onUpgrade step.
    // Stop-minimums took 214. The newest rung owns the exact assertion;
    // relax it to greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 215);
    expect(AppDatabase.migrationVersions, contains(215));
  });

  test('a fresh database has the dive_plans gas-options columns with the '
      'expected defaults and nullability', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dive_plans')").get();
    final byName = {for (final c in cols) c.read<String>('name'): c};

    for (final name in [
      'sac_factor',
      'problem_solving_minutes',
      'pp_o2_bottom',
      'pp_o2_deco',
      'best_mix_end_meters',
      'o2_narcotic',
    ]) {
      expect(byName, contains(name));
    }

    // Non-nullable, defaulted columns.
    expect(byName['sac_factor']!.read<int>('notnull'), 1);
    expect(byName['problem_solving_minutes']!.read<int>('notnull'), 1);
    expect(byName['best_mix_end_meters']!.read<int>('notnull'), 1);

    // Nullable override columns.
    expect(byName['pp_o2_bottom']!.read<int>('notnull'), 0);
    expect(byName['pp_o2_deco']!.read<int>('notnull'), 0);
    expect(byName['o2_narcotic']!.read<int>('notnull'), 0);
  });

  test(
    'a database stranded before v215 gains the columns via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dive_plans (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            gf_low INTEGER NOT NULL,
            gf_high INTEGER NOT NULL,
            ascent_rate REAL NOT NULL DEFAULT 9.0,
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
      expect(
        names,
        containsAll([
          'sac_factor',
          'problem_solving_minutes',
          'pp_o2_bottom',
          'pp_o2_deco',
          'best_mix_end_meters',
          'o2_narcotic',
        ]),
      );
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
