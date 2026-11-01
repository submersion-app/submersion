part of '../app_database_migrations.dart';

/// Multiple checklists per trip (issue #3356): a trip's single flat
/// checklist becomes one of several named `TripChecklist`s, each owning its
/// own sections and items. Follows the same idempotent shape as
/// [ChecklistSectionMigrations] (issue #3360): guarded table/column
/// creation, a `checklist_id IS NULL` guard on the backfill UPDATE,
/// deterministic checklist ids so a rerun never duplicates, and a
/// column-exists guard on the final DROP COLUMN, so it is called from both
/// its onUpgrade rung and the beforeOpen backstop.
extension TripChecklistMigrations on AppDatabase {
  /// v336: trip_checklists, plus trip_checklist_sections.checklist_id and
  /// trip_checklist_items.checklist_id, replacing the direct trip_id both
  /// tables carried since issue #3360. A trip with existing sections or
  /// items gets one backfilled default checklist (see
  /// [kDefaultTripChecklistName]); a trip with neither gets none, matching
  /// how a brand-new trip starts with zero checklists today.
  Future<void> _assertAndBackfillTripChecklists() async {
    // Created unconditionally, unlike ChecklistSectionMigrations' tables:
    // trip_checklists is the parent of the checklist concept itself, so a
    // database that has never had a trips table (or any trip-owned rows to
    // backfill from) still ends up with the empty table, matching what a
    // brand-new install's schema creates from scratch.
    await Migrator(this).createTable(tripChecklists);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_checklists_trip_id '
      'ON trip_checklists(trip_id)',
    );
    if (!await _tableExists('trips')) return;

    final hasSections = await _tableExists('trip_checklist_sections');
    final hasItems = await _tableExists('trip_checklist_items');
    if (!hasSections && !hasItems) return;

    if (hasSections) {
      await _addColumnIfMissing(
        'trip_checklist_sections',
        'checklist_id',
        'TEXT REFERENCES trip_checklists(id)',
      );
    }
    if (hasItems) {
      await _addColumnIfMissing(
        'trip_checklist_items',
        'checklist_id',
        'TEXT REFERENCES trip_checklists(id)',
      );
    }

    // False once a prior run dropped trip_id, which is every later open.
    final sectionsNameTrip = await _columnExists(
      'trip_checklist_sections',
      'trip_id',
    );
    final itemsNameTrip = await _columnExists(
      'trip_checklist_items',
      'trip_id',
    );
    final tripIds = <String>{};
    if (sectionsNameTrip) {
      final rows = await customSelect(
        'SELECT DISTINCT trip_id FROM trip_checklist_sections '
        'WHERE checklist_id IS NULL',
      ).get();
      tripIds.addAll(rows.map((r) => r.read<String>('trip_id')));
    }
    if (itemsNameTrip) {
      final rows = await customSelect(
        'SELECT DISTINCT trip_id FROM trip_checklist_items '
        'WHERE checklist_id IS NULL',
      ).get();
      tripIds.addAll(rows.map((r) => r.read<String>('trip_id')));
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final tripId in tripIds) {
      final checklistId = defaultTripChecklistId(tripId);
      await customStatement(
        'INSERT INTO trip_checklists '
        '(id, trip_id, name, sort_order, created_at, updated_at) '
        'VALUES (?, ?, ?, 0, ?, ?) '
        'ON CONFLICT(id) DO NOTHING',
        [checklistId, tripId, kDefaultTripChecklistName, now, now],
      );
      // Clearing hlc marks the row unstamped, matching the new checklist
      // row's own state, so SyncRepository.backfillMissingHlc picks up both
      // (see the identical reasoning in _backfillTextGroupedSections).
      if (sectionsNameTrip) {
        await customStatement(
          'UPDATE trip_checklist_sections SET checklist_id = ?, hlc = NULL '
          'WHERE trip_id = ? AND checklist_id IS NULL',
          [checklistId, tripId],
        );
      }
      if (itemsNameTrip) {
        await customStatement(
          'UPDATE trip_checklist_items SET checklist_id = ?, hlc = NULL '
          'WHERE trip_id = ? AND checklist_id IS NULL',
          [checklistId, tripId],
        );
      }
    }

    // The ladder drops the change log triggers before it starts, but a
    // database that reaches this from beforeOpen still has them, and SQLite
    // will not drop a column a trigger names. _assertChangeLog, which runs
    // last in beforeOpen, puts them back generated for the new schema.
    if (sectionsNameTrip || itemsNameTrip) await dropChangeLogTriggers(this);

    // SQLite refuses DROP COLUMN while a separately-created index still
    // references it ("error in index ... after drop column"), so the old
    // trip_id indexes (idx_trip_checklist_sections_trip_id from the v297
    // rung, idx_trip_checklist_items_trip_id from performance_indexes.dart)
    // must go first. New indexes on checklist_id replace them below.
    if (hasSections) {
      await customStatement(
        'DROP INDEX IF EXISTS idx_trip_checklist_sections_trip_id',
      );
      await _dropColumnIfExists('trip_checklist_sections', 'trip_id');
      await _requireChecklistId('trip_checklist_sections');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_trip_checklist_sections_checklist_id '
        'ON trip_checklist_sections(checklist_id)',
      );
    }
    if (hasItems) {
      await customStatement(
        'DROP INDEX IF EXISTS idx_trip_checklist_items_trip_id',
      );
      await _dropColumnIfExists('trip_checklist_items', 'trip_id');
      await _requireChecklistId('trip_checklist_items');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_trip_checklist_items_checklist_id '
        'ON trip_checklist_items(checklist_id)',
      );
    }
  }

  /// Gives [table].checklist_id the NOT NULL a fresh install has, which
  /// ADD COLUMN cannot: a column with a REFERENCES clause must default to
  /// NULL while foreign keys are on. It matters beyond tidiness.
  /// repairDanglingForeignKeys reads the constraint to decide between
  /// deleting an orphan and clearing its link, and Drift cannot read a row
  /// back with a null in this column, so a cleared link would fail every
  /// full export of the table.
  ///
  /// Rebuilds from the stored definition, not the Drift class, for the same
  /// reason [_assertAndBackfillTripChecklistSections] builds from raw SQL:
  /// this rung has to keep working after that class changes.
  Future<void> _requireChecklistId(String table) async {
    final required = await customSelect(
      'SELECT "notnull" AS required FROM pragma_table_info(?) '
      "WHERE name = 'checklist_id'",
      variables: [Variable<String>(table)],
    ).get();
    if (required.isEmpty || required.single.read<int>('required') == 1) return;

    final stored = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table)],
    ).getSingle();
    final createSql = stored.read<String>('sql');
    final clause = RegExp(
      r'(^|[\s,(])("?checklist_id"?\s+TEXT)(\s+REFERENCES\s)',
      caseSensitive: false,
    );
    final header = RegExp(
      '^CREATE\\s+TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?"?$table"?',
      caseSensitive: false,
    );
    if (clause.allMatches(createSql).length != 1 ||
        !header.hasMatch(createSql)) {
      developer.log(
        '$table.checklist_id: stored definition not in a recognised shape, '
        'left nullable',
        name: 'AppDatabase',
      );
      return;
    }
    final scratch = '${table}_v336';
    final rebuiltSql = createSql
        .replaceFirstMapped(clause, (m) => '${m[1]}${m[2]} NOT NULL${m[3]}')
        .replaceFirst(header, 'CREATE TABLE $scratch');
    final dependents = await customSelect(
      'SELECT sql FROM sqlite_master WHERE tbl_name = ? '
      "AND type IN ('index', 'trigger') AND sql IS NOT NULL",
      variables: [Variable<String>(table)],
    ).get();

    Future<bool> enforced() async =>
        (await customSelect(
          'PRAGMA foreign_keys',
        ).getSingle()).read<int>('foreign_keys') ==
        1;
    final wasEnforced = await enforced();
    if (wasEnforced) {
      await customStatement('PRAGMA foreign_keys = OFF');
      // A no-op inside a transaction. Refuse rather than let the DROP TABLE
      // below clear every item's section link through its ON DELETE SET NULL.
      if (await enforced()) {
        developer.log(
          '$table.checklist_id: foreign keys could not be switched off, '
          'rebuild deferred to a later open',
          name: 'AppDatabase',
        );
        return;
      }
    }
    try {
      await transaction(() async {
        await customStatement('DROP TABLE IF EXISTS $scratch');
        await customStatement(rebuiltSql);
        await customStatement(
          'INSERT INTO $scratch SELECT * FROM $table '
          'WHERE checklist_id IS NOT NULL',
        );
        await customStatement('DROP TABLE $table');
        await customStatement('ALTER TABLE $scratch RENAME TO $table');
        for (final row in dependents) {
          await customStatement(row.read<String>('sql'));
        }
      });
    } finally {
      if (wasEnforced) await customStatement('PRAGMA foreign_keys = ON');
    }
  }
}
