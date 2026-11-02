import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// Keeps the diver's own profile events through the paths that replace a
/// dive's events wholesale (#4109): a file resync, a computer re-parse and a
/// native re-download each delete the computer's rows and re-insert the
/// fresh parse, but a row with `source = user` (an annotation, a hand-added
/// bookmark) is nobody's to replace.
///
/// Each path logs one dive-wide scope tombstone (#1926), and a peer applying
/// it deletes every event whose clock is older. So the survivors are
/// re-stamped right after the tombstone, with [restampUserEvents], and carry
/// a newer clock to every peer.

/// The where clause that leaves user-authored rows alone.
Expression<bool> nonUserEvent($DiveProfileEventsTable t) =>
    t.source.equals(EventSource.user.name).not();

/// The ids of the dive's events that are not user-authored, on one computer
/// when [computerId] is given.
Future<List<String>> nonUserEventIds(
  AppDatabase db,
  String diveId, {
  String? computerId,
}) {
  final query = db.selectOnly(db.diveProfileEvents)
    ..addColumns([db.diveProfileEvents.id])
    ..where(
      db.diveProfileEvents.diveId.equals(diveId) &
          nonUserEvent(db.diveProfileEvents) &
          (computerId == null
              ? const Constant(true)
              : db.diveProfileEvents.computerId.equals(computerId)),
    );
  return query.map((row) => row.read(db.diveProfileEvents.id)!).get();
}

/// Marks every user-authored event of the dive pending, so each carries a
/// clock newer than a scope tombstone logged just before.
Future<void> restampUserEvents({
  required AppDatabase db,
  required SyncRepository sync,
  required String diveId,
  required int now,
}) async {
  final rows =
      await (db.select(db.diveProfileEvents)..where(
            (t) =>
                t.diveId.equals(diveId) &
                t.source.equals(EventSource.user.name),
          ))
          .get();
  for (final row in rows) {
    await sync.markRecordPending(
      entityType: 'diveProfileEvents',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
}
