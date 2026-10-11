import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v283: dive_profile_series.activated_at (issue #3189), the synced
/// key a primary swap ranks a source's profile generations by.
void main() {
  /// A v281 database: three series of one dive, plus the local revision
  /// history that marks one demoted series as an edit.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 281');
      rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute('''
        CREATE TABLE dive_profile_series (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          is_primary INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute("INSERT INTO dives (id) VALUES ('dive-1')");
      rawDb.execute('''
        INSERT INTO dive_profile_series
          (id, dive_id, computer_id, is_primary, created_at, updated_at)
        VALUES ('live', 'dive-1', NULL, 1, 100, 400),
               ('demoted-edit', 'dive-1', NULL, 0, 200, 500),
               ('demoted-original', 'dive-1', NULL, 0, 50, 600),
               ('demoted-legacy-edit', 'dive-1', NULL, 0, 300, 700)
      ''');
      rawDb.execute('''
        CREATE TABLE dive_profile_series_history (
          series_id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          parent_series_id TEXT,
          root_series_id TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          revision_kind TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        INSERT INTO dive_profile_series_history
          (series_id, dive_id, parent_series_id, root_series_id,
           content_hash, revision_kind, created_at)
        VALUES ('live', 'dive-1', NULL, 'live', 'h1', 'legacy', 100),
               ('demoted-edit', 'dive-1', 'demoted-original',
                'demoted-original', 'h2', 'Edit: profile_editor', 200),
               ('demoted-original', 'dive-1', NULL, 'demoted-original',
                'h3', 'legacy', 50),
               ('demoted-legacy-edit', 'dive-1', 'demoted-original',
                'demoted-original', 'h4', 'edit:profile_editor', 300)
      ''');
    },
  );

  test('v283 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(283));
    expect(AppDatabase.migrationVersions, contains(283));
    expect(
      AppDatabase.migrationStepCount(281),
      greaterThan(AppDatabase.migrationStepCount(283)),
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(283));
  });

  test('upgrading from v281 backfills the activation times', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id, activated_at FROM dive_profile_series ORDER BY id',
        )
        .get();
    expect(
      {for (final r in rows) r.read<String>('id'): r.data['activated_at']},
      {
        // Primary: its synced updated_at, the same on every device.
        'live': 400,
        // A demoted edit the history knows of: its synced created_at.
        'demoted-edit': 200,
        // The legacy lower-case spelling counts too.
        'demoted-legacy-edit': 300,
        // Never live as far as anything recorded says.
        'demoted-original': null,
      },
    );
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profile_series')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('activated_at'));
  });
}
