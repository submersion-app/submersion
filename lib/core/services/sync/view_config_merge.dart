import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart'
    show tryParseHlc;

/// Applies a peer's view_configs row without tripping the unique index on
/// (diver_id, view_mode) (issue #3343).
///
/// Rows sync by id, but two devices that each saved the same view while
/// apart mint two ids for it. Upserting the peer's row by id then collided
/// with this device's row on the index and failed the sync. Instead, the
/// group keeps its LOWER id, the rule tags already follow, carrying the
/// config saved last (see [_newerOf]). Every device runs the
/// same comparison from its own copy, so the fleet converges on one row
/// without a tombstone: the losing id is a local identity reconciliation,
/// not a deletion the diver made. The beforeOpen backstop collapses existing
/// duplicates by the same rule.
///
/// When the config kept is this device's rather than the peer's, the
/// survivor is queued for sync: the peer still holds its older config, and
/// a local edit that lived on the losing id would otherwise never reach it.
Future<void> applyViewConfigRecord(
  AppDatabase db,
  ViewConfig remote, {
  required SyncRepository syncRepository,
}) async {
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
    if (!identical(newest, remote)) {
      await syncRepository.markRecordPending(
        entityType: 'viewConfigs',
        recordId: survivorId,
        localUpdatedAt: newest.updatedAt,
      );
    }
  });
}

/// The row saved last. The HLC decides, as it does for every other synced
/// row: a row with one beats a legacy row without, and two clocks compare as
/// clocks, which wall-clock skew and same-millisecond writes cannot fool.
/// Rows without one fall back to updatedAt, and the lower id wins a full tie
/// so every device agrees. The beforeOpen collapse orders rows the same way.
ViewConfig _newerOf(ViewConfig a, ViewConfig b) {
  final clockA = tryParseHlc(a.hlc);
  final clockB = tryParseHlc(b.hlc);
  if ((clockA == null) != (clockB == null)) return clockA != null ? a : b;
  if (clockA != null && clockB != null) {
    final byClock = clockA.compareTo(clockB);
    if (byClock != 0) return byClock > 0 ? a : b;
  }
  final byTime = a.updatedAt.compareTo(b.updatedAt);
  if (byTime != 0) return byTime > 0 ? a : b;
  return a.id.compareTo(b.id) <= 0 ? a : b;
}
