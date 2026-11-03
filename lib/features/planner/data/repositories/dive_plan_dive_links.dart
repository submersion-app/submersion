import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// `dive_plans.source_dive_id` ("plan from this dive") and `linked_dive_id`
/// (plan-vs-actual) reference `dives` with no ON DELETE action, and plans are
/// not owned by a diver in practice. Under `PRAGMA foreign_keys = ON` a plan
/// pointing at a dive fails that dive's delete with SqliteException(787), so
/// every path that deletes dives clears the links first.
const List<String> _diveLinkColumns = ['source_dive_id', 'linked_dive_id'];

/// `dive_plan_series.followed_dive_id` (issue #3565) references `dives` with
/// no ON DELETE action as well, so it is cleared with the plans' links.
const String _seriesDiveLinkColumn = 'followed_dive_id';

/// A table whose rows hold the links being cleared: its SQL name, the Drift
/// table whose watchers must refresh, and its sync entity type.
typedef _LinkTarget = ({String table, TableInfo info, String entityType});

_LinkTarget _planTarget(AppDatabase db) =>
    (table: 'dive_plans', info: db.divePlans, entityType: 'divePlans');

_LinkTarget _seriesTarget(AppDatabase db) => (
  table: 'dive_plan_series',
  info: db.divePlanSeries,
  entityType: 'divePlanSeries',
);

/// Clears the links dive plans and saved dive series hold to [diveIds],
/// stamping and marking each row so the change reaches peers. Run it inside
/// the caller's transaction, before the dives are deleted.
Future<void> clearPlanLinksToDives(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> diveIds, {
  required int now,
}) async {
  await _clearLinksToIds(
    db,
    syncRepository,
    target: _planTarget(db),
    columns: _diveLinkColumns,
    ids: diveIds,
    now: now,
  );
  await _clearLinksToIds(
    db,
    syncRepository,
    target: _seriesTarget(db),
    columns: const [_seriesDiveLinkColumn],
    ids: diveIds,
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
}) => _clearLinksToIds(
  db,
  syncRepository,
  target: _planTarget(db),
  columns: const ['site_id'],
  ids: siteIds,
  now: now,
);

/// Clears the links surviving dive plans hold to [diverId]'s dives and
/// private sites, and the dives surviving dive series follow, stamping and
/// marking each row so the change reaches peers. Run it inside the caller's
/// transaction, after shared sites have moved to a surviving diver and the
/// diver's own plans and series are deleted (they must not be published),
/// and before the dives and sites are deleted.
///
/// `dive_plans.site_id` references `dive_sites` with no ON DELETE action
/// too, so a plan set at one of the diver's sites would otherwise fail the
/// deletion of that site.
Future<void> clearPlanLinksToDiverRows(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) async {
  // stats-scope-exempt: deletion cascade cleanup.
  const diverDives = 'SELECT id FROM dives WHERE diver_id = ?';
  const diverSites = 'SELECT id FROM dive_sites WHERE diver_id = ?';
  final plans = _planTarget(db);
  final planIds = await _clearLinks(
    db,
    target: plans,
    links: [
      for (final column in _diveLinkColumns) (column, diverDives),
      ('site_id', diverSites),
    ],
    args: [diverId],
    now: now,
  );
  await _markPending(syncRepository, plans, planIds, now: now);
  final series = _seriesTarget(db);
  final seriesIds = await _clearLinks(
    db,
    target: series,
    links: const [(_seriesDiveLinkColumn, diverDives)],
    args: [diverId],
    now: now,
  );
  await _markPending(syncRepository, series, seriesIds, now: now);
}

/// Frees the surviving dive plans that are dives of [diverId]'s saved
/// series, stamping and marking each plan so the change reaches peers: each
/// becomes a one-dive series of its own. Run it inside the caller's
/// transaction, after the diver's own plans are deleted and before the
/// series are: `dive_plans.series_id` references `dive_plan_series` with no
/// ON DELETE action.
Future<void> clearPlanLinksToDiverSeries(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) async {
  final plans = _planTarget(db);
  final planIds = await _clearLinks(
    db,
    target: plans,
    links: const [
      ('series_id', 'SELECT id FROM dive_plan_series WHERE diver_id = ?'),
    ],
    args: [diverId],
    now: now,
  );
  await _markPending(syncRepository, plans, planIds, now: now);
}

/// Clears each of [columns] on the [target] rows whose column names one of
/// [ids].
///
/// Chunked: a bulk delete can pass more ids than SQLite binds in one
/// statement (issue #1953). A row cleared in two chunks, through both of
/// its dive links, is still marked pending once.
Future<void> _clearLinksToIds(
  AppDatabase db,
  SyncRepository syncRepository, {
  required _LinkTarget target,
  required List<String> columns,
  required List<String> ids,
  required int now,
}) async {
  if (ids.isEmpty) return;
  final rowIds = <String>{};
  for (final chunk in seriesIdChunks(ids)) {
    final placeholders = List.filled(chunk.length, '?').join(', ');
    rowIds.addAll(
      await _clearLinks(
        db,
        target: target,
        links: [for (final column in columns) (column, placeholders)],
        args: chunk,
        now: now,
      ),
    );
  }
  await _markPending(syncRepository, target, rowIds, now: now);
}

/// Sets each (column, ids) link of [links] to NULL on the [target] rows
/// whose column is in `ids`, the body of an `IN (...)` list (placeholders or
/// a subquery) bound by [args]. Returns the rows it changed, for
/// [_markPending].
Future<Set<String>> _clearLinks(
  AppDatabase db, {
  required _LinkTarget target,
  required List<(String, String)> links,
  required List<String> args,
  required int now,
}) async {
  final rowIds = <String>{};
  for (final (column, ids) in links) {
    final where = '$column IN ($ids)';
    final rows = await db
        .customSelect(
          'SELECT id FROM ${target.table} WHERE $where',
          variables: [for (final a in args) Variable.withString(a)],
        )
        .get();
    if (rows.isEmpty) continue;
    // customUpdate, not customStatement: naming the table is what tells its
    // watchers (the saved-plans list watches `dive_plans`) to refresh.
    await db.customUpdate(
      'UPDATE ${target.table} SET $column = NULL, updated_at = ? '
      'WHERE $where',
      variables: [
        Variable.withInt(now),
        for (final a in args) Variable.withString(a),
      ],
      updates: {target.info},
    );
    rowIds.addAll(rows.map((r) => r.read<String>('id')));
  }
  return rowIds;
}

Future<void> _markPending(
  SyncRepository syncRepository,
  _LinkTarget target,
  Set<String> rowIds, {
  required int now,
}) async {
  for (final id in rowIds) {
    await syncRepository.markRecordPending(
      entityType: target.entityType,
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
