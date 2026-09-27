part of '../app_database_migrations.dart';

/// Dive computers, data sources, imported files and raw data.
extension DataSourceMigrations on AppDatabase {
  /// v175: dive_computers.equipment_id (gear twins). Idempotent; safe to call
  /// from both onUpgrade and the beforeOpen backstop. Nullable with no default,
  /// because a null means "this computer has no gear item", which is also what
  /// a user deleting the gear item leaves behind.
  ///
  /// The REFERENCES clause is not decoration. Without it an upgraded database
  /// gets a bare TEXT column while a freshly created one gets the FK from the
  /// table definition, so `onDelete: setNull` would hold only for new installs
  /// and existing users would be left with `equipment_id` pointing at a deleted
  /// row. SQLite permits a REFERENCES clause on ADD COLUMN precisely because
  /// this column is nullable and defaults to NULL. Mirrors the v158
  /// `_assertProfileSourceIdColumn` precedent.
  ///
  /// It is added ONLY when `equipment` actually exists. SQLite accepts a
  /// reference to a missing table at ALTER time and then fails every later
  /// write to `dive_computers` with "no such table: main.equipment" once
  /// foreign keys are on, which would break minimal fixtures and any database
  /// caught mid-upgrade. Every real database has `equipment`, so production
  /// always takes the FK branch; the bare fallback is harmless where it
  /// applies, because a database with no `equipment` table has no gear rows
  /// whose deletion the FK would need to cascade.
  Future<void> _assertDiveComputerEquipmentColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_computers')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('equipment_id')) return;

    final equipmentCols = await customSelect(
      "PRAGMA table_info('equipment')",
    ).get();
    final reference = equipmentCols.isEmpty
        ? ''
        : ' REFERENCES equipment(id) ON DELETE SET NULL';
    await customStatement(
      'ALTER TABLE dive_computers ADD COLUMN equipment_id TEXT$reference',
    );
  }

  /// Data self-heal: synthesize a primary [DiveDataSources] row for any dive
  /// that has profile samples but no data-source row. Older file imports (and
  /// any import path predating dive_data_sources) wrote samples without the
  /// metadata row, which stranded the grouped-by-source view that the 3D
  /// scene, spatial map, and computer-compare all read -- they spun forever on
  /// a null scene. The 2D chart survived because it reads dive.profile directly.
  ///
  /// Reads `dive_profile_series`, not the retired row-per-sample
  /// `dive_profiles`: v183 dropped that table, so the pre-183 guard and
  /// predicate would have made this helper a permanent no-op. The rung packs
  /// before it drops, so a dive that had primary legacy rows has a primary
  /// series row and is still healed.
  ///
  /// Runs on every open; a cheap no-op once healed (the NOT EXISTS guard leaves
  /// nothing to insert). Local-only by design: the id is deterministic
  /// (`legacy-src-<diveId>`), so every device heals to the identical row
  /// without syncing, and a device on an older build simply heals itself after
  /// upgrade. It never touches the parent dive's HLC, so it does not trigger a
  /// fleet re-sync of the healed dives. imported_at/created_at are Drift
  /// dateTime() columns stored as unix SECONDS (unlike the dives table's plain
  /// millisecond int columns), hence strftime('%s') without the *1000.
  Future<void> _backfillMissingDataSources() async {
    // Self-guard for partial/legacy schemas (migration tests and databases
    // caught mid-upgrade): skip unless all three tables exist. beforeOpen runs
    // for every open, including old-version fixtures where these tables may not
    // exist yet.
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('dives', 'dive_profile_series', 'dive_data_sources')",
    ).get();
    final present = tables.map((r) => r.read<String>('name')).toSet();
    if (!present.containsAll({
      'dives',
      'dive_profile_series',
      'dive_data_sources',
    })) {
      return;
    }
    // Column guard as well as table guard. A minimal fixture (and a database
    // caught mid-upgrade) can carry a dive_data_sources that predates these
    // columns, and beforeOpen's own _assertProfileSeriesSchema will have
    // created dive_profile_series for it, so the table check alone is not
    // enough: the INSERT below would abort the open.
    final sourceCols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final sourceColNames = sourceCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (!sourceColNames.containsAll(const {
      'id',
      'dive_id',
      'is_primary',
      'imported_at',
      'created_at',
    })) {
      return;
    }
    // The same column guard on the OTHER side of the statement. A
    // dive_profile_series a parallel branch shaped differently, or a fixture
    // that stands one up by hand, survives beforeOpen's IF NOT EXISTS DDL
    // untouched, so its presence says nothing about its shape. These are the
    // two columns the EXISTS predicate below reads; the rest of the series
    // row (source_id, computer_id, the summary scalars, the blob) this
    // helper never names.
    final seriesCols = await customSelect(
      "PRAGMA table_info('dive_profile_series')",
    ).get();
    final seriesColNames = seriesCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (!seriesColNames.containsAll(const {'dive_id', 'is_primary'})) {
      return;
    }
    await customStatement('''
      INSERT OR IGNORE INTO dive_data_sources
        (id, dive_id, is_primary, imported_at, created_at)
      SELECT '$kLegacyDataSourceIdPrefix' || d.id, d.id, 1, n.now_s, n.now_s
      FROM dives d
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) AS now_s
      ) n
      WHERE EXISTS (
        SELECT 1 FROM dive_profile_series s
        WHERE s.dive_id = d.id AND s.is_primary = 1
      )
      AND NOT EXISTS (
        SELECT 1 FROM dive_data_sources s WHERE s.dive_id = d.id
      )
    ''');
  }

  /// Data self-heal: adopt each dive's computer attribution from its data-source
  /// rows when `dives.computer_id` is null.
  ///
  /// The download path only began stamping `dives.computer_id` in v1.6 (commit
  /// 9ddb281); before that every child row (profiles, tanks, data source)
  /// carried the computer id but the parent dive did not. Those dives are
  /// invisible to the "dives from this computer" filter, which keys on the
  /// parent column (issue #1064), and to the consolidation service's
  /// same-computer guard.
  ///
  /// Runs on every open; a cheap no-op once healed (the `IN` set is empty when
  /// no dive is missing attribution). Local-only by design: the value is
  /// derived from already-synced `dive_data_sources` rows, so every device
  /// heals to the identical id independently. It never touches the dive's HLC,
  /// so healing does not trigger a fleet re-sync.
  ///
  /// The primary source wins, with the source id as a tiebreak so devices
  /// resolve a multi-source dive to the same computer rather than whichever row
  /// SQLite happened to visit first.
  ///
  /// Runs after `ensurePerformanceIndexes` so the correlated subquery uses
  /// idx_dive_data_sources_dive_id rather than scanning a million-row table on
  /// a fresh or restored database. Order relative to
  /// [_backfillMissingDataSources] is immaterial: the rows that helper
  /// synthesizes carry no computer_id, so they never satisfy the `IN` set here.
  Future<void> _backfillDiveComputerIds() async {
    // PRAGMA-guarded like every other self-heal helper. beforeOpen runs for
    // every open, including minimal old-schema test fixtures and databases
    // caught mid-upgrade. Unlike _backfillMissingDataSources, which only names
    // columns that have existed since those tables were created, this statement
    // reads computer_id on both sides, so a table-existence check is not
    // enough: PRAGMA table_info returns empty for a missing table, so probing
    // the columns covers both cases.
    final diveCols = await customSelect("PRAGMA table_info('dives')").get();
    if (!diveCols.map((c) => c.read<String>('name')).contains('computer_id')) {
      return;
    }
    final sourceCols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final sourceColNames = sourceCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (!sourceColNames.contains('computer_id') ||
        !sourceColNames.contains('dive_id') ||
        !sourceColNames.contains('is_primary')) {
      return;
    }

    await customStatement('''
      UPDATE dives SET computer_id = (
        SELECT s.computer_id FROM dive_data_sources s
        WHERE s.dive_id = dives.id AND s.computer_id IS NOT NULL
        ORDER BY s.is_primary DESC, s.id
        LIMIT 1
      )
      WHERE computer_id IS NULL
        AND id IN (
          SELECT dive_id FROM dive_data_sources WHERE computer_id IS NOT NULL
        )
    ''');
  }

  /// Test-only hook exercising the #1064 attribution self-heal directly.
  Future<void> backfillDiveComputerIdsForTest() => _backfillDiveComputerIds();

  /// Register the dive computers that file-imported dives name (issue
  /// #1288). Body lives in `imported_computer_backfill.dart`.
  Future<void> _backfillImportedDiveComputers() =>
      backfillImportedDiveComputers(this);

  /// Test-only hook exercising the #1288 registration self-heal directly.
  Future<void> backfillImportedDiveComputersForTest() =>
      _backfillImportedDiveComputers();

  /// Idempotent DDL for the v159 dive_data_sources.time_offset_seconds
  /// column (issue #1177). Same dual-call contract (onUpgrade + beforeOpen
  /// backstop) as the other column-assert helpers. Nullable with no default,
  /// so every pre-existing row reads back as "no offset applied".
  Future<void> _assertDataSourceTimeOffsetColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('time_offset_seconds')) {
      await customStatement(
        'ALTER TABLE dive_data_sources ADD COLUMN time_offset_seconds INTEGER',
      );
    }
  }

  /// Idempotent DDL for the v184 dive_data_sources.merge_source_slot column
  /// (issue #1451). Same dual-call contract (onUpgrade + beforeOpen backstop)
  /// as the other column-assert helpers. Nullable with no default, so every
  /// pre-existing row reads back as "not carried by a merge".
  Future<void> _assertDataSourceMergeSlotColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('merge_source_slot')) {
      await customStatement(
        'ALTER TABLE dive_data_sources ADD COLUMN merge_source_slot INTEGER',
      );
    }
  }

  /// Idempotent DDL for the v208 imported-file store (issue #478): the
  /// `imported_files` table and the `dive_data_sources.imported_file_id`
  /// reference that names a row in it. Same dual-call contract (onUpgrade +
  /// beforeOpen backstop) as the other assert helpers.
  ///
  /// No declared foreign key on the reference; see
  /// [DiveDataSources.importedFileId] for why. The index is what keeps the
  /// refcount sweep off a full scan of the sources table.
  Future<void> _assertImportedFilesSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS imported_files (
        id TEXT NOT NULL PRIMARY KEY,
        bytes BLOB NOT NULL,
        file_name TEXT,
        byte_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    final cols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('imported_file_id')) {
      await customStatement(
        'ALTER TABLE dive_data_sources ADD COLUMN imported_file_id TEXT',
      );
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_data_sources_imported_file '
      'ON dive_data_sources (imported_file_id)',
    );
  }

  /// Stamp `merge_source_slot = 0` on the provenance rows of dives that were
  /// combined before v184 shipped, so their halves collapse to one display
  /// source the way a post-v184 combine does (issue #1451).
  ///
  /// Nothing recorded the marker at the time, so the rows have to be
  /// recognized by shape. A dive qualifies only when all three hold:
  ///
  ///  - it has two or more `dive_data_sources` rows, and
  ///  - none of them is primary. Every importer writes its own row with
  ///    `is_primary = 1` (dive_import_service, uddf_entity_importer,
  ///    saveComputerReading) and a consolidation leaves the target's primary
  ///    row alone, so "no primary at all" is the signature of
  ///    `DiveMergeService.apply`, which writes every carried row
  ///    `isPrimary: false`, and
  ///  - every row has an entry and an exit time, and no two of those spans
  ///    overlap, and
  ///  - no row carries a non-zero `time_offset_seconds`.
  ///
  /// The span test is what makes this safe. Combined halves are consecutive
  /// slices of one timeline, so their spans are disjoint; two computers
  /// recording one dive cover the same minutes, so theirs overlap. Without
  /// it, a consolidation whose target row was never marked primary would
  /// collapse to a single chip and the chart would go back to drawing the
  /// interleaved union of both computers (issue #543). A dive whose rows
  /// carry no entry/exit times cannot be classified either way and is left
  /// alone: it keeps exactly today's behavior.
  ///
  /// The offset test closes the one hole in that reasoning.
  /// `DiveConsolidationService` shifts a folded-in dive's SAMPLES by
  /// `time_offset_seconds` but copies its `entry_time`/`exit_time` over
  /// verbatim, so a secondary whose clock was badly out has a stored span
  /// that misses the target's even though the two cover the same minutes.
  /// The span test would read that as a Combine. A non-zero offset is the
  /// trace consolidation leaves and a Combine never writes, so requiring
  /// zero across the dive rules that shape out. It costs a few false
  /// negatives -- a pre-v184 dive that was consolidated and then combined is
  /// now skipped -- and a skipped dive simply keeps today's display, which
  /// is the safe direction to be wrong in for a one-shot write over user
  /// data.
  ///
  /// Runs once on the v184 rung, not from the beforeOpen backstop: it writes
  /// rows rather than asserting DDL, and every merge performed after the
  /// upgrade stamps its own slots.
  ///
  /// Guarded on the columns it reads, like every other migration helper here.
  /// A database whose `dive_data_sources` a parallel branch shaped without
  /// entry/exit times must still open: the classification has no input there,
  /// so skipping is the same answer as running.
  Future<void> _backfillMergeSourceSlots() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    const required = {
      'dive_id',
      'is_primary',
      'entry_time',
      'exit_time',
      'time_offset_seconds',
      'merge_source_slot',
    };
    if (!names.containsAll(required)) return;
    await customStatement(
      'UPDATE dive_data_sources SET merge_source_slot = 0 '
      'WHERE merge_source_slot IS NULL '
      'AND dive_id IN ('
      '  SELECT dive_id FROM dive_data_sources'
      '  GROUP BY dive_id'
      '  HAVING COUNT(*) >= 2'
      '     AND SUM(CASE WHEN is_primary THEN 1 ELSE 0 END) = 0'
      '     AND SUM(CASE WHEN entry_time IS NULL OR exit_time IS NULL'
      '                  THEN 1 ELSE 0 END) = 0'
      '     AND SUM(CASE WHEN COALESCE(time_offset_seconds, 0) <> 0'
      '                  THEN 1 ELSE 0 END) = 0'
      ') '
      'AND dive_id NOT IN ('
      '  SELECT a.dive_id FROM dive_data_sources a'
      '  JOIN dive_data_sources b'
      '    ON b.dive_id = a.dive_id AND b.id <> a.id'
      '  WHERE a.entry_time < b.exit_time AND b.entry_time < a.exit_time'
      ')',
    );
  }

  /// v190: rewrite `dive_data_sources.raw_data` in its compressed at-rest
  /// form (issue #227).
  ///
  /// PRAGMA-guarded like every other data rung, so a partial schema no-ops
  /// rather than throwing. Rows already carrying the magic are skipped, which
  /// is what makes a second run free and an interrupted run cost only the
  /// work it already did.
  ///
  /// Every row is guarded on its own. An unguarded pack step in the v182
  /// profile-series rung could leave a database that would not open, which is
  /// the worst outcome available to a migration and the one this rung is
  /// closest to repeating. A row that will not pack is left exactly as it is
  /// and logged; nothing about it justifies refusing to open the diver's log.
  ///
  /// Paged with a keyset cursor rather than read whole: a large library holds
  /// thousands of blobs, and loading every one into memory to save space
  /// would be a strange way to go about it.
  Future<void> _recompressRawDiveData() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('id') || !names.contains('raw_data')) return;

    const pageSize = 200;
    String? cursor;
    while (true) {
      final page = await customSelect(
        'SELECT id, raw_data FROM dive_data_sources '
        'WHERE raw_data IS NOT NULL${cursor == null ? '' : ' AND id > ?'} '
        'ORDER BY id LIMIT $pageSize',
        variables: [if (cursor != null) Variable(cursor)],
      ).get();
      if (page.isEmpty) break;
      cursor = page.last.read<String>('id');

      for (final row in page) {
        final id = row.read<String>('id');
        final stored = row.read<Uint8List>('raw_data');
        if (isCompressedRawDiveData(stored)) continue;
        try {
          final packed = encodeRawDiveData(stored);
          if (packed.length >= stored.length) continue;
          await customStatement(
            'UPDATE dive_data_sources SET raw_data = ? WHERE id = ?',
            [packed, id],
          );
          _recompressedRawBlobs = true;
        } catch (e, stackTrace) {
          _rawBlobsLeftUncompressed++;
          developer.log(
            'v190 left raw_data on dive_data_sources row $id uncompressed; '
            'the bytes are intact and still readable',
            name: 'AppDatabase',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
      if (page.length < pageSize) break;
    }
  }

  bool get _recompressedRawBlobs => _migrationOutcome.recompressedRawBlobs;
  set _recompressedRawBlobs(bool value) =>
      _migrationOutcome.recompressedRawBlobs = value;

  int get _rawBlobsLeftUncompressed =>
      _migrationOutcome.rawBlobsLeftUncompressed;
  set _rawBlobsLeftUncompressed(int value) =>
      _migrationOutcome.rawBlobsLeftUncompressed = value;

  /// How many rows the v190 rung could not pack on this connection.
  ///
  /// Counted rather than only logged: a swallowed exception with nothing but
  /// a log line is invisible to any test, and the one thing worth proving
  /// about this rung is that a row it cannot pack changes nothing else.
  int get rawBlobsLeftUncompressed => _rawBlobsLeftUncompressed;

  /// True once this connection's v190 rung has actually shrunk at least one
  /// `raw_data` blob.
  ///
  /// The rewritten pages go to the freelist, and only a VACUUM returns them
  /// to the filesystem. Keyed off the event rather than the stored version
  /// for the same reason as [droppedLegacySampleTables]: a file with no raw
  /// data crosses this rung without earning a reclaim, and rewriting it would
  /// cost a diver a full-file VACUUM for nothing.
  bool get recompressedRawBlobs => _recompressedRawBlobs;

  /// True when this connection did something whose freed pages are still held
  /// by the file. The single signal [DatabaseService] reads to decide whether
  /// its one VACUUM is worth taking.
  bool get hasUnreclaimedPages =>
      droppedLegacySampleTables || recompressedRawBlobs;

  /// What earned this connection's pending reclaim, for a log line that has
  /// to name a cause.
  ///
  /// Both causes can be true of one upgrade, and neither has to be: a file
  /// old enough to plan a VACUUM gets one even when its v183 rung skipped the
  /// drop, and a message naming a step that did not run is worse than one
  /// saying so. Kept beside [hasUnreclaimedPages] so a future reclaiming rung
  /// that adds itself to the gate is looking straight at the string it also
  /// has to extend.
  String get unreclaimedPagesReason {
    final causes = [
      if (droppedLegacySampleTables) 'the legacy sample tables were dropped',
      if (recompressedRawBlobs) 'raw dive data was recompressed',
    ];
    if (causes.isEmpty) return 'no reclaiming step reported on this connection';
    return causes.join(' and ');
  }

  /// Test hook: run the v190 recompression on demand so tests can assert it
  /// is idempotent. Not used in production; the migration calls the private
  /// method.
  Future<void> recompressRawDiveDataForTest() => _recompressRawDiveData();

  /// v233: dive_data_sources.source_diver_key (issue #1921). Idempotent, so
  /// it is safe from both onUpgrade and the beforeOpen backstop, and a no-op
  /// when the table does not exist yet.
  Future<void> _assertSourceDiverKeyColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('source_diver_key')) {
      await customStatement(
        'ALTER TABLE dive_data_sources ADD COLUMN source_diver_key TEXT',
      );
    }
  }
}
