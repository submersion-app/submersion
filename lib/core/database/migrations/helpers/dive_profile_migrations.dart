part of '../app_database_migrations.dart';

/// Profile series, profile events and the legacy sample tables.
extension DiveProfileMigrations on AppDatabase {
  /// v240: scoped event tombstones select events by dive (#1926). Guarded
  /// on the table, as the other backstops are, for migration fixtures that
  /// build only part of the schema.
  Future<void> _assertProfileEventsDiveIdIndex() async {
    if (!await _tableExists('dive_profile_events')) return;
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_profile_events_dive_id '
      'ON dive_profile_events (dive_id)',
    );
  }

  /// v182: the packed profile series tables.
  ///
  /// Raw idempotent DDL so it doubles as the beforeOpen backstop for a
  /// database stranded at 182 by a parallel branch. The DDL must agree with
  /// the Drift declarations column for column; the v182 migration test
  /// compares the two on a fresh database.
  ///
  /// Each table waits for its own foreign-key parents. A child table whose
  /// parent is absent poisons the parents that ARE present: SQLite resolves
  /// the child's references when a cascade fires, so `DELETE FROM dives`
  /// would fail with "no such table: main.dive_tanks" on a partial schema
  /// (the older migration-test fixtures, and a database caught mid-upgrade).
  /// Every real database has carried all four parents for many versions, and
  /// the beforeOpen backstop creates whatever was skipped on the next open.
  Future<void> _assertProfileSeriesSchema() async {
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final present = tables.map((r) => r.read<String>('name')).toSet();
    if (present.containsAll(const {
      'dives',
      'dive_computers',
      'dive_data_sources',
    })) {
      await _assertDiveProfileSeriesTable();
    }
    if (present.containsAll(const {'dives', 'dive_computers', 'dive_tanks'})) {
      await _assertTankPressureSeriesTable();
    }
  }

  Future<void> _assertDiveProfileSeriesTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS dive_profile_series (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE,
        computer_id TEXT REFERENCES dive_computers (id) ON DELETE SET NULL,
        source_id TEXT REFERENCES dive_data_sources (id) ON DELETE SET NULL,
        is_primary INTEGER NOT NULL DEFAULT 1 CHECK (is_primary IN (0, 1)),
        sample_count INTEGER NOT NULL,
        start_timestamp INTEGER NOT NULL,
        end_timestamp INTEGER NOT NULL,
        max_depth REAL NOT NULL,
        first_depth REAL NOT NULL,
        last_depth REAL NOT NULL,
        has_deco_type INTEGER NOT NULL DEFAULT 0
          CHECK (has_deco_type IN (0, 1)),
        has_deco_stop INTEGER NOT NULL DEFAULT 0
          CHECK (has_deco_stop IN (0, 1)),
        has_positive_ceiling INTEGER NOT NULL DEFAULT 0
          CHECK (has_positive_ceiling IN (0, 1)),
        codec_version INTEGER NOT NULL,
        samples BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_profile_series_dive_primary '
      'ON dive_profile_series (dive_id, is_primary)',
    );
    // Backs findComputerDivesContainingTime's same-computer lookup (the
    // Dunkerque re-download check), which otherwise scans every series row
    // for the affected computer on each incoming dive during import.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_profile_series_computer '
      'ON dive_profile_series (computer_id)',
    );
  }

  /// v183: drops the row-per-sample profile table.
  ///
  /// Called from the v183 rung and from the `beforeOpen` backstop, and in
  /// both places only once the pack has returned normally AND
  /// `dive_profile_series` exists. Both conditions are load-bearing. A pack
  /// that threw packed nothing, and a pack that ran with no series table to
  /// pack into ALSO packed nothing: `_assertProfileSeriesSchema` skips a
  /// series table whose foreign-key parents are absent, and the packer's
  /// unpacked-dive scan then reports no work rather than failing. Dropping
  /// on either would destroy the only copy of those samples.
  ///
  /// Idempotent (`IF EXISTS` throughout), so a ladder that failed later and
  /// retried from the top runs this again harmlessly.
  ///
  /// Split from [_purgeLegacySampleBookkeeping] because the two have
  /// different preconditions: the bookkeeping purge is always correct, while
  /// dropping the table is only safe once the samples in it are packed.
  /// Split from [_dropLegacyTankTable] because the two legacy tables have
  /// different parents, so one can be packable on a database where the other
  /// is not.
  Future<void> _dropLegacyProfileTable() async {
    final present = await _tableExists('dive_profiles');
    await customStatement('DROP INDEX IF EXISTS idx_dive_profiles_dive_id');
    await customStatement('DROP TABLE IF EXISTS dive_profiles');
    if (present) _droppedLegacySampleTables = true;
  }

  /// v183: drops the row-per-sample tank pressure table. The mirror of
  /// [_dropLegacyProfileTable], gated on `tank_pressure_series` existing
  /// (that table waits for `dive_tanks`, which `dive_profile_series` does
  /// not need).
  Future<void> _dropLegacyTankTable() async {
    final present = await _tableExists('tank_pressure_profiles');
    await customStatement('DROP INDEX IF EXISTS idx_tank_pressure_dive_tank');
    await customStatement('DROP TABLE IF EXISTS tank_pressure_profiles');
    if (present) _droppedLegacySampleTables = true;
  }

  bool get _droppedLegacySampleTables =>
      _migrationOutcome.droppedLegacySampleTables;
  set _droppedLegacySampleTables(bool value) =>
      _migrationOutcome.droppedLegacySampleTables = value;

  /// True once this connection has actually dropped a row-per-sample legacy
  /// table, whether from the v183 rung or from the beforeOpen backstop.
  ///
  /// The pages those tables held are most of an older file, and only a
  /// VACUUM returns them to the filesystem. Which open performs the drop is
  /// not something the stored schema version can answer: the rung is allowed
  /// to skip it (its pack threw, the series table's foreign-key parents were
  /// absent, or the residue count found rows no series covered), and the
  /// backstop then drops on the first later open whose pack succeeds, by
  /// which time the file is long since stamped 183. So the reclamation keys
  /// off this, the event itself. See [DatabaseService].
  bool get droppedLegacySampleTables => _droppedLegacySampleTables;

  /// Drops whichever legacy sample table the pack has provably moved into
  /// its series table. Never both unconditionally: on a database missing one
  /// side's foreign-key parents only one series table exists, and the other
  /// legacy table is still the only copy of its samples.
  ///
  /// Two gates per table, and both are load-bearing. The series table must
  /// exist, and [countLegacyRowsAwaitingPack] must find no legacy row that a
  /// series row does not cover. A pack that returned normally is not proof
  /// the rows moved: an orphaned pressure row is skipped, a dive that
  /// already had a series row is never revisited so a second computer's rows
  /// stay behind, and `INSERT OR IGNORE` can pack nothing at all into a
  /// series table a parallel branch shaped differently. Dropping on any of
  /// those destroys the only copy.
  Future<void> _dropPackedLegacySampleTables() async {
    final residue = await countLegacyRowsAwaitingPack(this);
    if (await _tableExists('dive_profile_series')) {
      if (residue.profiles == 0) {
        await _dropLegacyProfileTable();
      } else {
        developer.log(
          'Keeping dive_profiles: ${residue.profiles} row(s) no series row '
          'covers. A later open retries the pack.',
          name: 'AppDatabase',
        );
      }
    }
    if (await _tableExists('tank_pressure_series')) {
      if (residue.tanks == 0) {
        await _dropLegacyTankTable();
      } else {
        developer.log(
          'Keeping tank_pressure_profiles: ${residue.tanks} row(s) no series '
          'row covers. A later open retries the pack.',
          name: 'AppDatabase',
        );
      }
    }
  }

  /// v183: deletes the sync bookkeeping of the retired sample entities.
  ///
  /// The `sync_records` rows are this device's pending outbound work for
  /// entity types this build no longer exports. Left behind they would be
  /// published forever and never acknowledged.
  ///
  /// The `deletion_log` rows did double duty, and the second job is the one
  /// worth naming: outbound they are tombstones peers apply, and INBOUND they
  /// were the resurrection guard for these two entity types, the rows
  /// SyncService's merge consults to keep a peer's copy of a sample this
  /// device deleted from coming back. Purging them retires that guard, which
  /// is safe because there is nothing left for it to guard. A `diveProfiles`
  /// or `tankPressureProfiles` row from an older peer no longer reaches a
  /// live table at all: those entity types are inbound-only
  /// (SyncService.inboundOnlyLegacyEntities), their rows land in the TEMP
  /// staging tables of `legacy_sample_staging.dart`, and the packer builds a
  /// series only for a dive that has none, so a stale legacy row cannot
  /// overwrite or revive a series this device holds. Deleting samples in this
  /// build tombstones `diveProfileSeries` / `tankPressureSeries` instead, and
  /// those tombstones are untouched here.
  ///
  /// The compatibility floor (183) is NOT what makes this safe. That gate is
  /// one-directional: it stops readers below 183 from applying our payloads,
  /// not older peers' payloads from reaching us. The staging shim above is
  /// what handles those, and it is what has to be retired before the floor
  /// argument would ever apply.
  ///
  /// UNCONDITIONAL in the rung: this is bookkeeping about rows nothing
  /// exports any more, so it is correct whether or not the pack that guards
  /// the table drop succeeded.
  ///
  /// Guarded per table like every other migration helper: a minimal
  /// old-schema fixture (and a database that reached this rung through a
  /// guarded path) can lack the sync bookkeeping entirely, and a DELETE
  /// naming a missing table aborts the whole ladder.
  /// sync_records ONLY. The deletion_log rows for these two entities stay,
  /// because they are still load-bearing on the receive side: a peer below
  /// the floor keeps publishing row-per-sample rows, and _mergeEntity's
  /// local-deletion guard is what stops one this device already deleted
  /// from being staged and packed back into a series. Purging them removed
  /// that guard while the inbound shim still exists. (Nothing is at risk on
  /// the send side either way: peers below 183 are held and apply none of
  /// this device's payloads, so those tombstones were never reaching them.)
  /// They can go with the shim.
  Future<void> _purgeLegacySampleBookkeeping() async {
    final exists = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'sync_records'",
    ).get();
    if (exists.isEmpty) return;
    await customStatement(
      "DELETE FROM sync_records WHERE entity_type IN ('diveProfiles', "
      "'tankPressureProfiles')",
    );
  }

  /// True when either retired row-per-sample table is still present.
  Future<bool> _legacySampleTablesPresent() async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('dive_profiles', 'tank_pressure_profiles')",
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _assertTankPressureSeriesTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS tank_pressure_series (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE,
        tank_id TEXT NOT NULL REFERENCES dive_tanks (id) ON DELETE CASCADE,
        computer_id TEXT REFERENCES dive_computers (id) ON DELETE SET NULL,
        sample_count INTEGER NOT NULL,
        start_timestamp INTEGER NOT NULL,
        end_timestamp INTEGER NOT NULL,
        codec_version INTEGER NOT NULL,
        samples BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tank_pressure_series_dive_tank '
      'ON tank_pressure_series (dive_id, tank_id)',
    );
  }

  Future<void> _assertO2CellMillivoltColumns() async {
    final cols = await customSelect("PRAGMA table_info('dive_profiles')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    for (var n = 1; n <= 6; n++) {
      if (!names.contains('o2_sensor_mv$n')) {
        await customStatement(
          'ALTER TABLE dive_profiles ADD COLUMN o2_sensor_mv$n INTEGER',
        );
      }
    }
  }

  /// v177: dive_profiles.rbt is documented in seconds, and the Subsurface and
  /// UDDF importers store seconds, but libdivecomputer reports RBT/GTR in
  /// minutes and every libdc path (download, reparse, raw-log import) wrote
  /// the raw value. Rows that came through libdc on a download, reparse or
  /// raw-log import carry raw bytes on their data source, so scale only
  /// them. Shearwater Cloud and MacDive imports also parse through libdc but
  /// persist no raw bytes and no format marker, so their existing rbt rows
  /// cannot be told apart from file imports here; re-importing them writes
  /// seconds.
  Future<void> _scaleLibdcRbtMinutesToSeconds() async {
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('dive_profiles', 'dive_data_sources')",
    ).get();
    if (tables.length < 2) return;
    final cols = await customSelect("PRAGMA table_info('dive_profiles')").get();
    if (!cols.any((c) => c.read<String>('name') == 'rbt')) return;
    await customStatement(
      'UPDATE dive_profiles SET rbt = rbt * 60 '
      'WHERE rbt IS NOT NULL AND dive_id IN '
      '(SELECT dive_id FROM dive_data_sources WHERE raw_data IS NOT NULL)',
    );
  }

  /// Owning-source FK on dive_profiles (issue #1149). PRAGMA-guarded so a
  /// healthy database no-ops and a partial schema does not throw.
  Future<void> _assertProfileSourceIdColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_profiles')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('source_id')) return;
    await customStatement(
      'ALTER TABLE dive_profiles ADD COLUMN source_id TEXT '
      'REFERENCES dive_data_sources(id) ON DELETE SET NULL',
    );
  }

  /// One-time attribution of existing dive_profiles rows to their owning
  /// dive_data_sources row (issue #1149).
  ///
  /// Reproduces the pre-v158 read convention that `getProfilesByDataSource`
  /// implements, so nothing changes owner as a result of the migration:
  ///
  /// 1. A row whose `computer_id` matches a source on the same dive belongs
  ///    to that source.
  /// 2. Everything else -- a null `computer_id` (file imports, manual
  ///    entries, and the rows `saveEditedProfile` writes) or a `computer_id`
  ///    matching no source -- belongs to the dive's primary source.
  ///
  /// Rule 2 is lossy for the one case this FK exists to fix: a dive carrying
  /// two file-imported sources has two indistinguishable null-`computer_id`
  /// row sets, and they all land on the primary. That is exactly where the
  /// old read path already put them, so this is not a regression, and every
  /// row written from v158 on is attributed at insert time instead.
  ///
  /// Runs in the ladder only, never in `beforeOpen`: dive_profiles is the
  /// largest table in the database and an "is anything unowned?" probe on
  /// every open would be a full scan once the answer is no.
  Future<void> _backfillProfileSourceIds() async {
    // Probe BOTH tables' columns, not just dive_profiles'. PRAGMA table_info
    // returns empty for a missing table, so this covers "table absent" and
    // "column absent" in one check -- the same guard _backfillDiveComputerIds
    // uses. Migration-test fixtures and databases caught mid-upgrade routinely
    // hold dive_profiles without dive_data_sources, and the correlated
    // subqueries below would fail with "no such table".
    final cols = await customSelect("PRAGMA table_info('dive_profiles')").get();
    if (!cols.map((c) => c.read<String>('name')).contains('source_id')) return;

    final sourceCols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final sourceNames = sourceCols.map((c) => c.read<String>('name')).toSet();
    if (!sourceNames.containsAll({
      'id',
      'dive_id',
      'computer_id',
      'is_primary',
      'created_at',
    })) {
      return;
    }

    // Deterministic pick so a re-run cannot move a row: primary first, then
    // oldest. Mirrors the ordering getProfilesByDataSource reads sources in.
    const primaryForDive =
        'SELECT s.id FROM dive_data_sources s '
        'WHERE s.dive_id = dive_profiles.dive_id '
        'ORDER BY s.is_primary DESC, s.created_at ASC LIMIT 1';

    await customStatement(
      'UPDATE dive_profiles SET source_id = ('
      'SELECT s.id FROM dive_data_sources s '
      'WHERE s.dive_id = dive_profiles.dive_id '
      'AND s.computer_id = dive_profiles.computer_id '
      'ORDER BY s.is_primary DESC, s.created_at ASC LIMIT 1) '
      'WHERE source_id IS NULL AND computer_id IS NOT NULL '
      'AND EXISTS (SELECT 1 FROM dive_data_sources s '
      'WHERE s.dive_id = dive_profiles.dive_id '
      'AND s.computer_id = dive_profiles.computer_id)',
    );

    await customStatement(
      'UPDATE dive_profiles SET source_id = ($primaryForDive) '
      'WHERE source_id IS NULL '
      'AND EXISTS (SELECT 1 FROM dive_data_sources s '
      'WHERE s.dive_id = dive_profiles.dive_id)',
    );
  }

  /// Test hook: run the v102 stranded-pressure repair on demand so tests can
  /// assert it is idempotent (a second run over already-healed data is a
  /// no-op). Not used in production; the migration invokes the private method.
  Future<void> relinkStrandedTankPressuresForTest() =>
      _relinkStrandedTankPressures();

  /// Re-link tank pressure series stranded under a stale tank id (issue #510).
  ///
  /// A reparse, re-import, or multi-computer consolidation can regenerate a
  /// dive's tanks with fresh UUIDs while its `tank_pressure_profiles` rows keep
  /// the old tank id. The per-cylinder SAC calculation looked those up by exact
  /// tank id and missed them, so SAC by cylinder went blank even though the
  /// pressure data was present (the runtime fix now tolerates this at read
  /// time; this migration heals the stored data once so the exact-id path works
  /// for every future consumer too).
  ///
  /// Mirrors the runtime resolver (`GasAnalysisService`): exact id matches are
  /// left alone; each orphaned series (keyed to an id that is no longer one of
  /// the dive's tanks) is adopted by a still-unmatched current tank, in tank
  /// order. Every reassignment targets a current tank of the same dive, so it
  /// is foreign-key safe. Idempotent: a second run finds no orphans.
  Future<void> _relinkStrandedTankPressures() async {
    // Defensive: both tables predate v102 in any real database, but migration
    // tests (and any partial DB) may reach this block without them. A missing
    // table would make the query below throw and abort the whole upgrade.
    Future<bool> tableExists(String name) async {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(name)],
      ).get();
      return rows.isNotEmpty;
    }

    if (!await tableExists('dive_tanks') ||
        !await tableExists('tank_pressure_profiles')) {
      return;
    }

    // Current tanks per dive (id + order for deterministic assignment).
    final tankRows = await customSelect(
      'SELECT dive_id, id, tank_order FROM dive_tanks',
    ).get();
    final tanksByDive = <String, List<({String id, int order})>>{};
    for (final r in tankRows) {
      (tanksByDive[r.read<String>('dive_id')] ??= []).add((
        id: r.read<String>('id'),
        order: r.read<int>('tank_order'),
      ));
    }
    if (tanksByDive.isEmpty) return;

    // One entry per (dive, pressure tank id), with the earliest sample time so
    // orphans are ordered the same way the runtime resolver iterates them.
    final pressureKeyRows = await customSelect(
      'SELECT dive_id, tank_id, MIN(timestamp) AS first_ts '
      'FROM tank_pressure_profiles GROUP BY dive_id, tank_id',
    ).get();
    final pressureKeysByDive = <String, List<({String tankId, int firstTs})>>{};
    for (final r in pressureKeyRows) {
      (pressureKeysByDive[r.read<String>('dive_id')] ??= []).add((
        tankId: r.read<String>('tank_id'),
        firstTs: r.read<int>('first_ts'),
      ));
    }

    for (final entry in pressureKeysByDive.entries) {
      final diveId = entry.key;
      final tanks = tanksByDive[diveId];
      if (tanks == null || tanks.isEmpty) continue;

      final currentIds = {for (final t in tanks) t.id};
      final matchedIds = {
        for (final k in entry.value)
          if (currentIds.contains(k.tankId)) k.tankId,
      };

      final orphans =
          [
            for (final k in entry.value)
              if (!currentIds.contains(k.tankId)) k,
          ]..sort((a, b) {
            final byTime = a.firstTs.compareTo(b.firstTs);
            return byTime != 0 ? byTime : a.tankId.compareTo(b.tankId);
          });
      if (orphans.isEmpty) continue;

      final unmatchedTanks =
          [
            for (final t in tanks)
              if (!matchedIds.contains(t.id)) t,
          ]..sort((a, b) {
            // id tie-break so tanks sharing the default order (0) pair
            // deterministically -- Dart's sort is not stable.
            final byOrder = a.order.compareTo(b.order);
            return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
          });
      if (unmatchedTanks.isEmpty) continue;

      final count = orphans.length < unmatchedTanks.length
          ? orphans.length
          : unmatchedTanks.length;
      for (var i = 0; i < count; i++) {
        await customStatement(
          'UPDATE tank_pressure_profiles SET tank_id = ? '
          'WHERE dive_id = ? AND tank_id = ?',
          [unmatchedTanks[i].id, diveId, orphans[i].tankId],
        );
      }
    }
  }
}
