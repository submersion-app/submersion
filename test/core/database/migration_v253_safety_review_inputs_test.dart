import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v253: dive_safety_reviews.inputs_hash, the fingerprint of the diver
/// settings a safety review was computed from (issue #2592). Column only, no
/// backfill: a review without one is recomputed on next view. 251 is
/// dive_tanks.source_id (#2716) and 252 is nav_tracks.diver_id (#2703). The
/// sync floor does not move: the column is nullable, and the receiving
/// overlay keeps it when an older peer omits it.
void main() {
  /// A database at [userVersion] (252 or later, so no earlier rung runs)
  /// whose safety review table predates the column.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE dive_safety_reviews ('
        'dive_id TEXT NOT NULL PRIMARY KEY, '
        'engine_version INTEGER NOT NULL, '
        'reviewed_at INTEGER NOT NULL, '
        'hlc TEXT)',
      );
      rawDb.execute("INSERT INTO dives (id) VALUES ('d1')");
      rawDb.execute(
        'INSERT INTO dive_safety_reviews (dive_id, engine_version, '
        "reviewed_at) VALUES ('d1', 2, 1000)",
      );
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v253 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 253);
    expect(AppDatabase.migrationVersions, contains(253));
    expect(AppDatabase.migrationStepCount(252), 1);
    // 252 (nav_tracks.diver_id, #2703) sits directly below this rung.
    expect(AppDatabase.migrationStepCount(251), 2);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_safety_reviews'), contains('inputs_hash'));
  });

  test('upgrading from v252 adds the column; an existing review has none, '
      'so it recomputes on next view', () async {
    final db = AppDatabase(strandedAt(252));
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_safety_reviews'), contains('inputs_hash'));
    final row = await db
        .customSelect(
          "SELECT inputs_hash FROM dive_safety_reviews WHERE dive_id = 'd1'",
        )
        .getSingle();
    expect(row.read<String?>('inputs_hash'), isNull);
  });

  test('a database already at v253 without the column gains it on open '
      '(the beforeOpen backstop)', () async {
    final db = AppDatabase(strandedAt(253));
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_safety_reviews'), contains('inputs_hash'));
  });
}
