import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  Future<Set<String>> diverSettingsColumns(AppDatabase db) async {
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  NativeDatabase strandedAt(int? userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      if (userVersion != null) {
        rawDb.execute('PRAGMA user_version = $userVersion');
      }
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
    },
  );

  test('v227 is at or below the current schema version and in the ladder', () {
    // Relaxed once v228 (cylinder fills) landed on top; the newest rung owns
    // the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(227));
    expect(AppDatabase.migrationVersions, contains(227));
    expect(AppDatabase.migrationStepCount(226), greaterThanOrEqualTo(1));
  });

  test('this rung is additive and did not move the sync floor', () {
    // The floor is owned by the v224 media fact clocks. An older reader
    // simply shows every built-in preset.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has the column, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName, contains('hidden_tank_preset_ids'));
    expect(byName['hidden_tank_preset_ids']!.read<int>('notnull'), 0);
  });

  test('a v226 database upgrades and gains the column', () async {
    final db = AppDatabase(strandedAt(226));
    addTearDown(db.close);

    expect(await diverSettingsColumns(db), contains('hidden_tank_preset_ids'));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), AppDatabase.currentSchemaVersion);
  });

  test(
    'a database stranded without the column regains it via beforeOpen',
    () async {
      // Already at the current version, e.g. after a version collision on a
      // parallel branch: no rung runs, only the backstop can add the column.
      final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
      addTearDown(db.close);

      expect(
        await diverSettingsColumns(db),
        contains('hidden_tank_preset_ids'),
      );
    },
  );
}
