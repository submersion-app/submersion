import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Reads and writes per-peer download cursors (one row per peer x provider):
/// how far this device has consumed each peer's changeset log.
class PeerCursorStore {
  PeerCursorStore(this._db);

  final AppDatabase _db;

  Future<SyncPeerCursor?> get(String peerDeviceId, String provider) {
    return (_db.select(_db.syncPeerCursors)..where(
          (t) =>
              t.peerDeviceId.equals(peerDeviceId) & t.provider.equals(provider),
        ))
        .getSingleOrNull();
  }

  Future<List<SyncPeerCursor>> allForProvider(String provider) {
    return (_db.select(
      _db.syncPeerCursors,
    )..where((t) => t.provider.equals(provider))).get();
  }

  Future<void> upsert({
    required String peerDeviceId,
    required String provider,
    int? baseSeqApplied,
    required int lastSeqApplied,
    String? appliedHlcHigh,
  }) async {
    await _db
        .into(_db.syncPeerCursors)
        .insertOnConflictUpdate(
          SyncPeerCursorsCompanion(
            peerDeviceId: Value(peerDeviceId),
            provider: Value(provider),
            baseSeqApplied: Value(baseSeqApplied),
            lastSeqApplied: Value(lastSeqApplied),
            // Absent (not null) when unknown, so a transport-only upsert never
            // clears a previously recorded acknowledgment.
            appliedHlcHigh: appliedHlcHigh == null
                ? const Value.absent()
                : Value(appliedHlcHigh),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// Drops one peer's cursor on one provider (nearby unpair).
  Future<void> remove(String peerDeviceId, String provider) =>
      (_db.delete(_db.syncPeerCursors)..where(
            (t) =>
                t.peerDeviceId.equals(peerDeviceId) &
                t.provider.equals(provider),
          ))
          .go();

  /// Whether any peer cursor exists for any provider. A cursor is written the
  /// first time this device consumes a peer's log, so a true here is proof
  /// the device has synced against at least one other device.
  Future<bool> hasAny() async {
    final row =
        await (_db.selectOnly(_db.syncPeerCursors)
              ..addColumns([_db.syncPeerCursors.peerDeviceId])
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Drop every cursor for [provider] -- used on backend switch and on
  /// stale-restore recovery so the device re-pulls each peer from scratch.
  Future<void> resetForProvider(String provider) async {
    await (_db.delete(
      _db.syncPeerCursors,
    )..where((t) => t.provider.equals(provider))).go();
  }
}
