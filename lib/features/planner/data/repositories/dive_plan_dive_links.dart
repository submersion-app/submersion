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
  await _clearPlanLinks(
    db,
    syncRepository,
    diveIdsSql: List.filled(diveIds.length, '?').join(', '),
    args: diveIds,
    now: now,
  );
}

/// Clears the links surviving dive plans hold to [diverId]'s dives, stamping
/// and marking each plan so the change reaches peers. Run it inside the
/// caller's transaction, after the diver's own plans are deleted (they must
/// not be published) and before the dives are deleted.
Future<void> clearPlanLinksToDiverDives(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) => _clearPlanLinks(
  db,
  syncRepository,
  // stats-scope-exempt: deletion cascade cleanup.
  diveIdsSql: 'SELECT id FROM dives WHERE diver_id = ?',
  args: [diverId],
  now: now,
);

/// [diveIdsSql] is the body of an `IN (...)` list: placeholders or a
/// subquery, bound by [args].
Future<void> _clearPlanLinks(
  AppDatabase db,
  SyncRepository syncRepository, {
  required String diveIdsSql,
  required List<String> args,
  required int now,
}) async {
  final planIds = <String>{};
  for (final column in _diveLinkColumns) {
    final where = '$column IN ($diveIdsSql)';
    final rows = await db
        .customSelect(
          'SELECT id FROM dive_plans WHERE $where',
          variables: [for (final a in args) Variable.withString(a)],
        )
        .get();
    if (rows.isEmpty) continue;
    await db.customStatement(
      'UPDATE dive_plans SET $column = NULL, updated_at = ? WHERE $where',
      [now, ...args],
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
