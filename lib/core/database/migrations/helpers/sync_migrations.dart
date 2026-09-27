part of '../app_database_migrations.dart';

/// Sync clocks and sync bookkeeping.
extension SyncMigrations on AppDatabase {
  /// v207 (issue #1728): `updated_at` on the three composite-natural-key gear
  /// junctions, backfilled from the parent row each one rides.
  ///
  /// These junctions are the only clockless children a stale tombstone can
  /// still match, because their key is the natural pair rather than a fresh
  /// uuid. With no age signal, `SyncService._applyRemoteDeletions` applied a
  /// remote tombstone unconditionally and `_mergeEntity` could never revive
  /// the row, so one dropped link became permanent, library-wide data loss.
  ///
  /// The backfill value is the parent's `updated_at`: the junction is
  /// rewritten wholesale whenever its parent is saved, so that is the age the
  /// link would have carried had the column always existed. Rows whose parent
  /// is missing keep NULL, which is exactly the pre-rung behavior (no signal).
  ///
  /// Idempotent, and safe to re-run from the beforeOpen backstop. The
  /// backfill runs only for a table whose column this call just added, so a
  /// steady-state open costs one PRAGMA per junction and never a table scan,
  /// and a link re-stamped since the rung is never dragged back to its
  /// parent's clock. onUpgrade runs inside a transaction, so a crash between
  /// the ALTER and the UPDATE rolls back both rather than stranding a table
  /// with the column but no values.
  Future<void> _assertJunctionUpdatedAtColumns() async {
    const parents = {
      'dive_equipment': ('dives', 'dive_id'),
      'equipment_set_items': ('equipment_sets', 'set_id'),
      'dive_plan_equipment': ('dive_plans', 'plan_id'),
    };
    final tables = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get()).map((r) => r.read<String>('name')).toSet();

    for (final entry in parents.entries) {
      final table = entry.key;
      final (parentTable, foreignKey) = entry.value;
      if (!tables.contains(table)) continue;
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (names.contains('updated_at')) continue;
      await customStatement('ALTER TABLE $table ADD COLUMN updated_at INTEGER');
      if (!tables.contains(parentTable)) continue;
      // The parent must also HAVE an updated_at. Minimal old-schema fixtures
      // (and genuinely ancient databases) carry a parent table stripped to
      // its id, and selecting a column that is not there aborts the whole
      // open with a SQL logic error. Nothing to backfill from is not a
      // failure: the rows keep NULL, which is the pre-rung behavior.
      final parentCols = await customSelect(
        "PRAGMA table_info('$parentTable')",
      ).get();
      final parentNames = parentCols.map((c) => c.read<String>('name')).toSet();
      if (!parentNames.contains('updated_at')) continue;
      await customStatement(
        'UPDATE $table SET updated_at = ('
        'SELECT p.updated_at FROM $parentTable p WHERE p.id = $table.$foreignKey'
        ') WHERE updated_at IS NULL',
      );
    }
  }

  /// v210: an `hlc` column on every child table exported through its
  /// parent (SyncDataSerializer.parentGatedChildEntities), and an
  /// `origin_hlc` on the deletion log. Idempotent; called
  /// from the v210 onUpgrade block and the beforeOpen backstop. A table a
  /// partial fixture lacks is skipped by [_addColumnIfMissing].
  Future<void> _assertChildHlcColumns() async {
    for (final table in const [
      'dive_tanks',
      'dive_equipment',
      'dive_plan_equipment',
      'dive_weights',
      'equipment_set_items',
      'dive_buddies',
      'course_requirement_dives',
      'dive_tags',
      'dive_dive_types',
      'weight_preset_entries',
      'tide_records',
      'sightings',
      'dive_custom_fields',
      'dive_data_sources',
      'site_species',
      'site_site_types',
      'site_tags',
      'equipment_tags',
      'equipment_shares',
      'equipment_ownership_events',
      'dive_profile_events',
      'dive_safety_reviews',
      'dive_safety_findings',
      'gas_switches',
      'dive_center_gear_notes',
    ]) {
      await _addColumnIfMissing(table, 'hlc', 'TEXT');
    }
    // And the clock of a delete, which the tombstone paths compare with
    // them (DeletionLog.originHlc).
    await _addColumnIfMissing('deletion_log', 'origin_hlc', 'TEXT');
  }

  /// v114: collapse duplicate tombstones (newest deleted_at per entity_type +
  /// record_id wins) and (re-)assert the unique index that keeps the deletion
  /// log collapsed. Cheap when the index already exists; the dedupe DELETE
  /// only runs when index creation fails *and* actual duplicates are present.
  /// Any other index-creation failure (corruption, disk full, locked DB) is
  /// rethrown unchanged rather than masked behind a destructive DELETE. Called
  /// from the v114 upgrade and the beforeOpen backstop (parallel-branch
  /// schema-version collisions heal here, mirroring the v111 backstop).
  Future<void> ensureDeletionLogIndex() async {
    // Self-guarding when the table is absent (minimal migration-test
    // fixtures), mirroring the other beforeOpen backstop helpers.
    final table = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='deletion_log'",
    ).get();
    if (table.isEmpty) return;
    const createIndex =
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_deletion_log_entity_record '
        'ON deletion_log (entity_type, record_id)';
    try {
      await customStatement(createIndex);
    } catch (_) {
      // The only expected cause is pre-existing duplicate (entity_type,
      // record_id) rows -- a DB written before the unique index existed
      // (parallel-branch collision, or logDeletion duplicates from before the
      // v114 upsert). Confirm duplicates are actually present before running
      // the dedupe DELETE; if there are none, the failure is something else
      // (corruption, disk full, locked) that must surface, not be swallowed.
      final hasDuplicates = await customSelect(
        'SELECT 1 FROM deletion_log GROUP BY entity_type, record_id '
        'HAVING COUNT(*) > 1 LIMIT 1',
      ).get();
      if (hasDuplicates.isEmpty) rethrow;
      await customStatement('''
        DELETE FROM deletion_log WHERE rowid NOT IN (
          SELECT rowid FROM (
            SELECT rowid, ROW_NUMBER() OVER (
              PARTITION BY entity_type, record_id
              ORDER BY deleted_at DESC, COALESCE(hlc, '') DESC, rowid DESC
            ) AS rn FROM deletion_log
          ) WHERE rn = 1
        )
      ''');
      await customStatement(createIndex);
    }
  }
}
