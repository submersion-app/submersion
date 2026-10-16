import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Applies a peer's view_configs row without tripping the unique index on
/// (diver_id, view_mode) (issue #3343).
///
/// Rows sync by id, but two devices that each saved the same view while
/// apart mint two ids for it. Upserting the peer's row by id then collided
/// with this device's row on the index and failed the sync. Instead, the
/// group keeps its LOWER id, the rule tags already follow, carrying the
/// config saved last (the id breaking an updatedAt tie). Every device runs the
/// same comparison from its own copy, so the fleet converges on one row
/// without a tombstone: the losing id is a local identity reconciliation,
/// not a deletion the diver made. The beforeOpen backstop collapses existing
/// duplicates by the same rule.
Future<void> applyViewConfigRecord(AppDatabase db, ViewConfig remote) async {
  final rivals =
      await (db.select(db.viewConfigs)..where(
            (t) =>
                t.diverId.equals(remote.diverId) &
                t.viewMode.equals(remote.viewMode) &
                t.id.equals(remote.id).not(),
          ))
          .get();
  if (rivals.isEmpty) {
    await db.into(db.viewConfigs).insertOnConflictUpdate(remote);
    return;
  }

  final group = [remote, ...rivals];
  final survivorId = ([for (final row in group) row.id]..sort()).first;
  final newest = group.reduce(_newerOf);
  await db.transaction(() async {
    // Every id but the survivor goes, the peer's own included: an older
    // local copy of it would otherwise still hold the view's index slot.
    await (db.delete(db.viewConfigs)..where(
          (t) =>
              t.id.isIn([for (final row in group) row.id]) &
              t.id.equals(survivorId).not(),
        ))
        .go();
    await db
        .into(db.viewConfigs)
        .insertOnConflictUpdate(newest.copyWith(id: survivorId));
  });
}

/// The row saved last, the lower id winning a tie so every device agrees.
ViewConfig _newerOf(ViewConfig a, ViewConfig b) {
  final byTime = a.updatedAt.compareTo(b.updatedAt);
  if (byTime != 0) return byTime > 0 ? a : b;
  return a.id.compareTo(b.id) <= 0 ? a : b;
}
