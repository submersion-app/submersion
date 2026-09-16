import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// `dive_plans.source_dive_id` ("plan from this dive") and `linked_dive_id`
/// (plan-vs-actual) reference `dives` with no ON DELETE action, and plans are
/// not owned by a diver in practice. Under `PRAGMA foreign_keys = ON` a plan
/// pointing at a dive fails that dive's delete with SqliteException(787), so
/// every path that deletes dives clears the links first.
const List<String> _diveLinkColumns = ['source_dive_id', 'linked_dive_id'];

/// Clears the links dive plans hold to [diveIds], stamping and marking each
/// plan so the change reaches peers. Run it inside the caller's transaction,
/// before the dives are deleted.
Future<void> clearPlanLinksToDives(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> diveIds, {
  required int now,
}) async {
  if (diveIds.isEmpty) return;
  final placeholders = List.filled(diveIds.length, '?').join(', ');
  await _clearPlanLinks(
    db,
    syncRepository,
    links: [for (final column in _diveLinkColumns) (column, placeholders)],
    args: diveIds,
    now: now,
  );
}

/// Clears the site of the dive plans set at [siteIds], stamping and marking
/// each plan so the change reaches peers. Run it inside the caller's
/// transaction, before the sites are deleted: `dive_plans.site_id`
/// references `dive_sites` with no ON DELETE action.
Future<void> clearPlanLinksToSites(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> siteIds, {
  required int now,
}) async {
  if (siteIds.isEmpty) return;
  await _clearPlanLinks(
    db,
    syncRepository,
    links: [('site_id', List.filled(siteIds.length, '?').join(', '))],
    args: siteIds,
    now: now,
  );
}

/// Clears the links surviving dive plans hold to [diverId]'s dives and
/// private sites, stamping and marking each plan so the change reaches
/// peers. Run it inside the caller's transaction, after shared sites have
/// moved to a surviving diver and the diver's own plans are deleted (they
/// must not be published), and before the dives and sites are deleted.
///
/// `dive_plans.site_id` references `dive_sites` with no ON DELETE action
/// too, so a plan set at one of the diver's sites would otherwise fail the
/// deletion of that site.
Future<void> clearPlanLinksToDiverRows(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) {
  // stats-scope-exempt: deletion cascade cleanup.
  const diverDives = 'SELECT id FROM dives WHERE diver_id = ?';
  const diverSites = 'SELECT id FROM dive_sites WHERE diver_id = ?';
  return _clearPlanLinks(
    db,
    syncRepository,
    links: [
      for (final column in _diveLinkColumns) (column, diverDives),
      ('site_id', diverSites),
    ],
    args: [diverId],
    now: now,
  );
}

/// Sets each (column, ids) link of [links] to NULL on the plans whose column
/// is in `ids`, the body of an `IN (...)` list (placeholders or a subquery)
/// bound by [args].
Future<void> _clearPlanLinks(
  AppDatabase db,
  SyncRepository syncRepository, {
  required List<(String, String)> links,
  required List<String> args,
  required int now,
}) async {
  final planIds = <String>{};
  for (final (column, ids) in links) {
    final where = '$column IN ($ids)';
    final rows = await db
        .customSelect(
          'SELECT id FROM dive_plans WHERE $where',
          variables: [for (final a in args) Variable.withString(a)],
        )
        .get();
    if (rows.isEmpty) continue;
    // customUpdate, not customStatement: naming the table is what tells the
    // saved-plans list (which watches `dive_plans`) to refresh.
    await db.customUpdate(
      'UPDATE dive_plans SET $column = NULL, updated_at = ? WHERE $where',
      variables: [
        Variable.withInt(now),
        for (final a in args) Variable.withString(a),
      ],
      updates: {db.divePlans},
    );
    planIds.addAll(rows.map((r) => r.read<String>('id')));
  }
  for (final id in planIds) {
    await syncRepository.markRecordPending(
      entityType: 'divePlans',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
