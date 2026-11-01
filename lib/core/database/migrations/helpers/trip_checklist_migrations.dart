part of '../app_database_migrations.dart';

/// Multiple checklists per trip (issue #3356): a trip's single flat
/// checklist becomes one of several named `TripChecklist`s, each owning its
/// own sections and items. Follows the same idempotent shape as
/// [ChecklistSectionMigrations] (issue #3360): guarded table/column
/// creation, a `checklist_id IS NULL` guard on the backfill UPDATE,
/// deterministic checklist ids so a rerun never duplicates, and a
/// column-exists guard on the final DROP COLUMN -- so it is called from
/// both its onUpgrade rung and the beforeOpen backstop.
extension TripChecklistMigrations on AppDatabase {
  /// A stable id for a trip's backfilled default checklist, derived from the
  /// trip id alone (one default checklist per trip), so a rerun after an
  /// interrupted migration -- or an independent run on another device --
  /// converges on the same row instead of creating a duplicate. Same
  /// convention as [_deterministicSectionId].
  String _deterministicChecklistId(String tripId) {
    final digest = sha1
        .convert(utf8.encode(tripId))
        .toString()
        .substring(0, 12);
    return 'checklist-$digest';
  }

  /// v332: trip_checklists, plus trip_checklist_sections.checklist_id and
  /// trip_checklist_items.checklist_id, replacing the direct trip_id both
  /// tables carried since issue #3360. A trip with existing sections or
  /// items gets one backfilled default checklist named "Checklist" (not
  /// localized: migrations run before any UI context exists, and the diver
  /// can rename it like any other checklist); a trip with neither gets none,
  /// matching how a brand-new trip starts with zero checklists today.
  Future<void> _assertAndBackfillTripChecklists() async {
    // Runs the v297 step first, idempotently: a database stamped v297 or
    // later without that rung ever truly running (old >= 297 skips it in
    // the onUpgrade ladder; the parallel-branch-collision case the
    // beforeOpen backstops exist for) would otherwise still have trip_id
    // directly on trip_checklist_items/sections once this function gets
    // there, and this function would convert that trip_id to checklist_id
    // without ever having created trip_checklist_sections or backfilled
    // section_id from category -- leaving both stuck permanently, since
    // _assertAndBackfillTripChecklistSections itself only knows how to
    // migrate FROM trip_id, which would already be gone.
    await _assertAndBackfillTripChecklistSections();
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

    // Only reachable with trip_id still present: _addColumnIfMissing above
    // no-ops once a prior run already dropped it, and so does this select.
    final tripIds = <String>{};
    if (hasSections &&
        await _columnExists('trip_checklist_sections', 'trip_id')) {
      final rows = await customSelect(
        'SELECT DISTINCT trip_id FROM trip_checklist_sections '
        'WHERE checklist_id IS NULL',
      ).get();
      tripIds.addAll(rows.map((r) => r.read<String>('trip_id')));
    }
    if (hasItems && await _columnExists('trip_checklist_items', 'trip_id')) {
      final rows = await customSelect(
        'SELECT DISTINCT trip_id FROM trip_checklist_items '
        'WHERE checklist_id IS NULL',
      ).get();
      tripIds.addAll(rows.map((r) => r.read<String>('trip_id')));
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final tripId in tripIds) {
      final checklistId = _deterministicChecklistId(tripId);
      await customStatement(
        'INSERT INTO trip_checklists '
        '(id, trip_id, name, sort_order, created_at, updated_at) '
        "VALUES (?, ?, 'Checklist', 0, ?, ?) "
        'ON CONFLICT(id) DO NOTHING',
        [checklistId, tripId, now, now],
      );
      // Clearing hlc marks the row unstamped, matching the new checklist
      // row's own state, so SyncRepository.backfillMissingHlc picks up both
      // (see the identical reasoning in _backfillTextGroupedSections).
      if (hasSections) {
        await customStatement(
          'UPDATE trip_checklist_sections SET checklist_id = ?, hlc = NULL '
          'WHERE trip_id = ? AND checklist_id IS NULL',
          [checklistId, tripId],
        );
      }
      if (hasItems) {
        await customStatement(
          'UPDATE trip_checklist_items SET checklist_id = ?, hlc = NULL '
          'WHERE trip_id = ? AND checklist_id IS NULL',
          [checklistId, tripId],
        );
      }
    }

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
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_trip_checklist_items_checklist_id '
        'ON trip_checklist_items(checklist_id)',
      );
    }
  }
}
