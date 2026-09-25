import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v229: equipment_sets.show_figure, the per-set switch for the diver figure
/// (issue #2326). Off by default, and off for every set that existed before
/// the column: the figure is opt-in, never switched on for a diver's
/// existing sets.
void main() {
  Future<Set<String>> setColumns(AppDatabase db) async {
    final cols = await db
        .customSelect("PRAGMA table_info('equipment_sets')")
        .get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  NativeDatabase strandedAt(int? userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      if (userVersion != null) {
        rawDb.execute('PRAGMA user_version = $userVersion');
      }
      rawDb.execute('''
        CREATE TABLE equipment_sets (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute(
        "INSERT INTO equipment_sets (id, name, created_at, updated_at) "
        "VALUES ('old', 'Reef set', 1, 1)",
      );
    },
  );

  test('v229 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 229);
    expect(AppDatabase.migrationVersions, contains(229));
    // 228 is held by open PRs, so this rung follows 227 directly.
    expect(AppDatabase.migrationVersions, isNot(contains(228)));
    expect(AppDatabase.migrationStepCount(227), 1);
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has the column, not null, off by default', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('equipment_sets')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName, contains('show_figure'));
    expect(byName['show_figure']!.read<int>('notnull'), 1);
    expect(byName['show_figure']!.read<String?>('dflt_value'), '0');
  });

  test('a v227 database upgrades, and an existing set reads off', () async {
    final db = AppDatabase(strandedAt(227));
    addTearDown(db.close);

    expect(await setColumns(db), contains('show_figure'));
    final row = await db
        .customSelect("SELECT show_figure FROM equipment_sets WHERE id = 'old'")
        .getSingle();
    expect(row.read<int>('show_figure'), 0);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), AppDatabase.currentSchemaVersion);
  });

  test(
    'a database stranded without the column regains it via beforeOpen',
    () async {
      final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
      addTearDown(db.close);

      expect(await setColumns(db), contains('show_figure'));
    },
  );
}
