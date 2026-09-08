import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// The sync bookkeeping the v183 rung purges. Hand-written to match the
/// Drift declarations of `SyncRecords` and `DeletionLog` (the fixture in
/// `legacy_profile_fixtures.dart` covers only the profile tables).
void syncBookkeepingDdl(sqlite3.Database rawDb) {
  rawDb.execute('''
    CREATE TABLE IF NOT EXISTS sync_records (
      id TEXT NOT NULL PRIMARY KEY,
      entity_type TEXT NOT NULL,
      record_id TEXT NOT NULL,
      local_updated_at INTEGER NOT NULL,
      synced_at INTEGER,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      conflict_data TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  rawDb.execute('''
    CREATE TABLE IF NOT EXISTS deletion_log (
      id TEXT NOT NULL PRIMARY KEY,
      entity_type TEXT NOT NULL,
      record_id TEXT NOT NULL,
      deleted_at INTEGER NOT NULL,
      hlc TEXT
    )
  ''');
}

/// One pending sync record and one tombstone per legacy entity type, plus a
/// `dives` row of each that must survive.
void seedSyncBookkeeping(sqlite3.Database rawDb) {
  rawDb.execute(
    'INSERT INTO sync_records (id, entity_type, record_id, local_updated_at, '
    'created_at, updated_at) VALUES '
    "('s1', 'diveProfiles', 'p1', 1, 1, 1), "
    "('s2', 'tankPressureProfiles', 'q1', 1, 1, 1), "
    "('s3', 'dives', 'd1', 1, 1, 1)",
  );
  rawDb.execute(
    'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) VALUES '
    "('l1', 'diveProfiles', 'p9', 1), "
    "('l2', 'tankPressureProfiles', 'q9', 1), "
    "('l3', 'dives', 'd9', 1)",
  );
}

/// The two legacy indexes the v183 rung drops by name. `legacyDdlAt180`
/// creates the tables without them, so a database that never ran
/// `ensurePerformanceIndexes` would make the DROP INDEX assertions vacuous.
void legacyIndexes(sqlite3.Database rawDb) {
  rawDb.execute(
    'CREATE INDEX IF NOT EXISTS idx_dive_profiles_dive_id '
    'ON dive_profiles(dive_id)',
  );
  rawDb.execute(
    'CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank '
    'ON tank_pressure_profiles(dive_id, tank_id, timestamp)',
  );
}

/// A `dive_profile_series` without its `samples` column: the backstop's
/// IF NOT EXISTS DDL leaves it alone and every packer INSERT fails. Same
/// trick as backstop_resilience_test.dart.
void malformedSeriesTable(sqlite3.Database rawDb) {
  rawDb.execute('''
    CREATE TABLE dive_profile_series (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL,
      computer_id TEXT,
      source_id TEXT,
      is_primary INTEGER NOT NULL DEFAULT 1
    )
  ''');
}

List<Object?> columnOf(sqlite3.Database rawDb, String sql, String column) {
  return rawDb.select(sql).map((r) => r[column]).toList();
}

int scalar(sqlite3.Database rawDb, String sql) {
  return rawDb.select(sql).first.values.first! as int;
}

void main() {
  test(
    'the v183 rung drops the legacy tables and purges their bookkeeping',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      legacyDdlAt180(raw, userVersion: 182);
      legacyIndexes(raw);
      seedParents(raw);
      // Legacy rows a device stamped 182 may still be holding: either the
      // v182 rung packed them and left them behind, or a parallel branch
      // claimed 182 first and they were never packed at all. Both must reach
      // the series tables before the drop.
      seedProfiles(raw);
      seedPressures(raw);
      syncBookkeepingDdl(raw);
      seedSyncBookkeeping(raw);

      final db = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      await db.customSelect('SELECT 1').get();

      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name IN ('dive_profiles', "
          "'tank_pressure_profiles')",
        ),
        isEmpty,
      );
      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN "
          "('idx_dive_profiles_dive_id', 'idx_tank_pressure_dive_tank')",
        ),
        isEmpty,
      );
      expect(
        columnOf(raw, 'SELECT entity_type FROM sync_records', 'entity_type'),
        ['dives'],
      );
      // The legacy tombstones STAY: _mergeEntity's local-deletion guard
      // uses them to stop a peer below the floor from staging and packing a
      // row this device already deleted. Only the export bookkeeping goes.
      expect(
        columnOf(
          raw,
          'SELECT entity_type FROM deletion_log ORDER BY entity_type',
          'entity_type',
        ),
        ['diveProfiles', 'dives', 'tankPressureProfiles'],
      );
      expect(
        scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'),
        greaterThan(0),
      );
      expect(
        scalar(raw, 'SELECT COUNT(*) AS n FROM tank_pressure_series'),
        greaterThan(0),
      );
      expect(
        scalar(raw, 'PRAGMA user_version'),
        AppDatabase.currentSchemaVersion,
      );

      await db.close();
    },
  );

  test('re-running the ladder at 183 is a no-op', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    legacyIndexes(raw);
    seedParents(raw);
    seedProfiles(raw);
    seedPressures(raw);
    syncBookkeepingDdl(raw);
    seedSyncBookkeeping(raw);

    // Two Drift executors over one SQLite handle: the first runs the ladder,
    // the second finds a database already at 183 and must not throw on the
    // tables and bookkeeping that are already gone.
    final first = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await first.customSelect('SELECT 1').get();
    await first.close();

    final profileSeries = scalar(
      raw,
      'SELECT COUNT(*) AS n FROM dive_profile_series',
    );
    final tankSeries = scalar(
      raw,
      'SELECT COUNT(*) AS n FROM tank_pressure_series',
    );
    final syncRecords = scalar(raw, 'SELECT COUNT(*) AS n FROM sync_records');
    final tombstones = scalar(raw, 'SELECT COUNT(*) AS n FROM deletion_log');

    final second = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(second.close);
    await expectLater(second.customSelect('SELECT 1').get(), completes);

    expect(
      scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'),
      profileSeries,
    );
    expect(
      scalar(raw, 'SELECT COUNT(*) AS n FROM tank_pressure_series'),
      tankSeries,
    );
    expect(scalar(raw, 'SELECT COUNT(*) AS n FROM sync_records'), syncRecords);
    expect(scalar(raw, 'SELECT COUNT(*) AS n FROM deletion_log'), tombstones);
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name IN ('dive_profiles', "
        "'tank_pressure_profiles')",
      ),
      isEmpty,
    );
    expect(
      scalar(raw, 'PRAGMA user_version'),
      AppDatabase.currentSchemaVersion,
    );
  });

  test(
    'a database that skipped the v182 rung still packs before the drop',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      legacyDdlAt180(raw, userVersion: 181);
      legacyIndexes(raw);
      seedParents(raw);
      seedProfiles(raw);
      seedPressures(raw);

      final db = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name IN ('dive_profiles', "
          "'tank_pressure_profiles')",
        ),
        isEmpty,
      );
      // seedProfiles writes 11 rows in four identity groups, one pair of them
      // an exact duplicate; seedPressures writes 4 rows in two groups, again
      // with one exact duplicate. The packed sample counts are the seeded rows
      // minus those duplicates.
      expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'), 4);
      expect(
        scalar(raw, 'SELECT SUM(sample_count) AS n FROM dive_profile_series'),
        10,
      );
      expect(scalar(raw, 'SELECT COUNT(*) AS n FROM tank_pressure_series'), 2);
      expect(
        scalar(raw, 'SELECT SUM(sample_count) AS n FROM tank_pressure_series'),
        3,
      );
      expect(
        scalar(raw, 'PRAGMA user_version'),
        AppDatabase.currentSchemaVersion,
      );
    },
  );

  test('a table the pack cannot write keeps its legacy table, and the other '
      'still packs', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    legacyIndexes(raw);
    seedParents(raw);
    seedProfiles(raw);
    seedPressures(raw);
    syncBookkeepingDdl(raw);
    seedSyncBookkeeping(raw);
    // A dive_profile_series a parallel branch shaped differently: the
    // IF NOT EXISTS DDL leaves it alone and every packer INSERT fails.
    malformedSeriesTable(raw);

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), completes);

    expect(
      scalar(raw, 'PRAGMA user_version'),
      AppDatabase.currentSchemaVersion,
    );
    // Only dive_profiles is unpackable here. Its samples are still only in
    // the legacy table, so its drop is skipped rather than destroying them.
    // The pressures are packed per dive independently of it, which is the
    // point: one unwritable series table must not cost the other's rows.
    expect(
      columnOf(
        raw,
        "SELECT name FROM sqlite_master WHERE name IN ('dive_profiles', "
            "'tank_pressure_profiles') ORDER BY name",
        'name',
      ),
      ['dive_profiles'],
    );
    expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profiles'), 11);
    expect(
      scalar(raw, 'SELECT COUNT(*) AS n FROM tank_pressure_series'),
      greaterThan(0),
    );
    // The bookkeeping purge does not depend on the pack: those rows describe
    // entities this build no longer exports either way.
    expect(
      columnOf(raw, 'SELECT entity_type FROM sync_records', 'entity_type'),
      ['dives'],
    );
    expect(
      columnOf(
        raw,
        'SELECT entity_type FROM deletion_log ORDER BY entity_type',
        'entity_type',
      ),
      ['diveProfiles', 'dives', 'tankPressureProfiles'],
    );
  });

  test('the backstop drops the legacy tables on the first later open whose '
      'pack succeeds', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    legacyIndexes(raw);
    seedParents(raw);
    seedProfiles(raw);
    seedPressures(raw);
    syncBookkeepingDdl(raw);
    seedSyncBookkeeping(raw);
    malformedSeriesTable(raw);

    // First open: the rung's pack throws, so the tables survive at 183.
    final first = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await first.customSelect('SELECT 1').get();
    await first.close();
    expect(
      scalar(raw, 'PRAGMA user_version'),
      AppDatabase.currentSchemaVersion,
    );
    expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profiles'), 11);

    // The malformed series table is repaired (dropped, so the backstop's
    // IF NOT EXISTS DDL recreates it correctly). The rung never runs again,
    // so only the backstop can finish the job.
    raw.execute('DROP TABLE dive_profile_series');

    final second = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(second.close);
    await second.customSelect('SELECT 1').get();

    expect(
      scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'),
      greaterThan(0),
    );
    expect(
      scalar(raw, 'SELECT SUM(sample_count) AS n FROM dive_profile_series'),
      10,
    );
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name IN ('dive_profiles', "
        "'tank_pressure_profiles')",
      ),
      isEmpty,
    );
  });

  test('a missing dive_data_sources keeps dive_profiles: nothing packed its '
      'samples', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    legacyIndexes(raw);
    seedParents(raw);
    seedProfiles(raw);
    seedPressures(raw);
    // _assertProfileSeriesSchema waits for every foreign-key parent, so with
    // dive_data_sources gone dive_profile_series is never created, the packer
    // finds no table to pack into and returns normally having packed nothing.
    // The drop has to wait with it or the samples go with the table.
    raw.execute('DROP TABLE dive_data_sources');

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    expect(
      scalar(raw, 'PRAGMA user_version'),
      AppDatabase.currentSchemaVersion,
    );
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'dive_profile_series'",
      ),
      isEmpty,
    );
    expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profiles'), 11);
    // dive_tanks is still there, so the tank half packed and its legacy table
    // is free to go: the two tables are gated independently.
    expect(
      scalar(raw, 'SELECT SUM(sample_count) AS n FROM tank_pressure_series'),
      3,
    );
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'tank_pressure_profiles'",
      ),
      isEmpty,
    );
  });

  test('a missing dive_tanks keeps tank_pressure_profiles: the mirror of the '
      'profile case', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    legacyIndexes(raw);
    seedParents(raw);
    seedProfiles(raw);
    seedPressures(raw);
    raw.execute('DROP TABLE dive_tanks');

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    expect(
      scalar(raw, 'PRAGMA user_version'),
      AppDatabase.currentSchemaVersion,
    );
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'tank_pressure_series'",
      ),
      isEmpty,
    );
    expect(scalar(raw, 'SELECT COUNT(*) AS n FROM tank_pressure_profiles'), 4);
    expect(
      scalar(raw, 'SELECT SUM(sample_count) AS n FROM dive_profile_series'),
      10,
    );
    expect(
      raw.select("SELECT name FROM sqlite_master WHERE name = 'dive_profiles'"),
      isEmpty,
    );
  });

  test(
    'the backstop keeps a legacy table whose series table is absent',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      // Already at 183, so no rung runs: beforeOpen is the only code that
      // touches this database, and its drop needs the same per-table gate.
      legacyDdlAt180(raw, userVersion: 183);
      legacyIndexes(raw);
      seedParents(raw);
      seedProfiles(raw);
      seedPressures(raw);
      raw.execute('DROP TABLE dive_tanks');

      final db = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      expect(
        scalar(raw, 'SELECT COUNT(*) AS n FROM tank_pressure_profiles'),
        4,
      );
      expect(
        scalar(raw, 'SELECT SUM(sample_count) AS n FROM dive_profile_series'),
        10,
      );
      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name = 'dive_profiles'",
        ),
        isEmpty,
      );
    },
  );

  test('a v182 pack that cannot write its series still reaches 183 and keeps '
      'the legacy table', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    // Below 182, so the v182 rung itself runs. A pre-existing
    // dive_profile_series without its samples column, the shape
    // backstop_resilience_test uses: CREATE TABLE IF NOT EXISTS leaves it
    // alone, so every packer INSERT fails. An unguarded rung would let
    // that out of onUpgrade and leave a database that cannot be opened on
    // any relaunch, and the row is perfectly READABLE, so dropping the
    // legacy table would destroy the only copy of it.
    legacyDdlAt180(raw, userVersion: 181);
    seedParents(raw);
    raw.execute(
      'INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, '
      "depth) VALUES ('p1', 'd1', 1, 0, 1.0)",
    );
    malformedSeriesTable(raw);

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), completes);

    expect(
      scalar(raw, 'PRAGMA user_version'),
      AppDatabase.currentSchemaVersion,
    );
    expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profiles'), 1);
  });

  test('an orphaned tank pressure row keeps its legacy table', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    legacyIndexes(raw);
    seedParents(raw);
    seedProfiles(raw);
    seedPressures(raw);
    // A pressure row whose tank is no longer in dive_tanks. The packer
    // skips it (no insert could carry the foreign key), so dropping the
    // table would destroy the only copy.
    raw.execute(
      'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
      "pressure, computer_id) VALUES ('q9', 'd1', 't9', 0, 150.0, NULL)",
    );

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    expect(
      scalar(
        raw,
        "SELECT COUNT(*) AS n FROM tank_pressure_profiles WHERE id = 'q9'",
      ),
      1,
    );
    // The profile side is independent and still drops.
    expect(
      raw.select("SELECT name FROM sqlite_master WHERE name = 'dive_profiles'"),
      isEmpty,
    );
    expect(
      scalar(raw, 'PRAGMA user_version'),
      AppDatabase.currentSchemaVersion,
    );
  });

  test(
    'a dive packed for one computer later packs the other\'s rows',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      legacyDdlAt180(raw, userVersion: 182);
      seedParents(raw);
      // First open: only c1 has legacy rows, so d1 packs and both legacy
      // tables go.
      raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
        'is_primary, timestamp, depth) VALUES '
        "('p1', 'd1', 'c1', 's1', 1, 0, 0.0), "
        "('p2', 'd1', 'c1', 's1', 1, 10, 12.0)",
      );
      final first = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      await first.customSelect('SELECT 1').get();
      await first.close();
      expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'), 1);

      // A second computer's legacy rows arrive afterwards (a restore, or a
      // parallel branch that reached 182 by its own rung). The scan asks
      // whether each row's IDENTITY is covered, not just its dive, so these
      // pack into their own series rather than sitting in a table no reader
      // looks at; only then is the legacy table covered and dropped.
      createLegacyProfileTables(raw);
      raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
        'is_primary, timestamp, depth) VALUES '
        "('p3', 'd1', 'c2', 's2', 0, 0, 0.0), "
        "('p4', 'd1', 'c2', 's2', 0, 10, 11.0)",
      );

      final second = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();

      expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'), 2);
      expect(
        columnOf(
          raw,
          'SELECT computer_id FROM dive_profile_series ORDER BY computer_id',
          'computer_id',
        ),
        ['c1', 'c2'],
      );
      // c1's original series is untouched: re-visiting the dive must not
      // write a second copy of an identity that already has one.
      expect(
        scalar(
          raw,
          "SELECT sample_count AS n FROM dive_profile_series "
          "WHERE computer_id = 'c1'",
        ),
        2,
      );
      // Every legacy row is now represented, so the table goes.
      expect(
        columnOf(
          raw,
          "SELECT name FROM sqlite_master WHERE name = 'dive_profiles'",
          'name',
        ),
        isEmpty,
      );
    },
  );

  test('v183 is present in the migration ladder', () {
    // v183 is now a past migration; the latest-version tripwire lives in the
    // newest migration's test (migration_v191_plan_ascent_rates_test.dart),
    // so assert membership rather than equality.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(183));
    expect(AppDatabase.migrationVersions, contains(183));
    // The wire compatibility floor lands on 183, not on the 182 rung that
    // replaced the two synced entities: no released build was ever stamped
    // 182, and only a reader that has run v183 has lost the legacy
    // deletion_log guard, so 183 is the oldest schema that can safely apply
    // this build's payloads.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 183);
  });
}
