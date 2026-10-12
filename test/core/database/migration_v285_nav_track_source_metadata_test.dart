import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v285: nav_tracks.source_metadata (issue #3047), a source's undocumented
/// fields kept as-is. Column only, no backfill: existing routes read null.
/// Renumbered from 282, which PR #3133 holds; 283 and 284 shipped first.
/// The sync floor does not move: an older peer omits the column, and both
/// apply paths keep a column a payload omits.
void main() {
  Future<Set<String>> columns(AppDatabase db) async {
    final rows = await db.customSelect("PRAGMA table_info('nav_tracks')").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// A file stranded at [userVersion] whose nav_tracks lacks the column and
  /// holds one route.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY, diver_id TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE nav_tracks (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT, start_time INTEGER)',
      );
      rawDb.execute("INSERT INTO nav_tracks (id) VALUES ('r1')");
    },
  );

  Future<String?> metadataOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect("SELECT source_metadata FROM nav_tracks WHERE id = '$id'")
        .getSingle();
    return row.read<String?>('source_metadata');
  }

  test('v285 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(285));
    expect(AppDatabase.migrationVersions, contains(285));
    // Compared with whichever rung sits directly below this one, so the
    // test survives a rung renumbered in beneath it.
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(285) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(285) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(285));
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await columns(db), contains('source_metadata'));
  });

  test(
    'upgrading from v283 adds the column; existing routes read null',
    () async {
      final db = AppDatabase(strandedAt(283));
      addTearDown(db.close);
      expect(await columns(db), contains('source_metadata'));
      expect(await metadataOf(db, 'r1'), isNull);
    },
  );

  test('a database already at v285 without the column regains it', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columns(db), contains('source_metadata'));
    expect(await metadataOf(db, 'r1'), isNull);
  });
}
