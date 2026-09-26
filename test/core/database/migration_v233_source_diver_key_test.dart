import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v233 adds dive_data_sources.source_diver_key, the diver a multi-diver
/// logbook attributed the source's dive to, so a resync replays that
/// diver's dive and not a buddy's (issue #1921).
void main() {
  Future<Set<String>> sourceColumns(AppDatabase db) async {
    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('''
        CREATE TABLE dive_data_sources (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          imported_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
    },
  );

  test('v233 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 233);
    expect(AppDatabase.migrationVersions, contains(233));
    // 232 is claimed by several open branches, so this rung skips it.
    expect(AppDatabase.migrationStepCount(231), 1);
  });

  test('this rung is additive and did not move the sync floor', () {
    // The floor is owned by the v224 media fact clocks. An older reader
    // ignores the column, and its resync falls back to the ambiguity check.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has the column, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName, contains('source_diver_key'));
    expect(byName['source_diver_key']!.read<int>('notnull'), 0);
  });

  test('a v231 database upgrades and gains the column', () async {
    final db = AppDatabase(strandedAt(231));
    addTearDown(db.close);

    expect(await sourceColumns(db), contains('source_diver_key'));
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

      expect(await sourceColumns(db), contains('source_diver_key'));
    },
  );
}
