import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Reads and writes this device's per-provider publish position (the upload
/// side of sync state; per-peer cursors are the download side).
class PublishStateStore {
  PublishStateStore(this._db);

  final AppDatabase _db;

  Future<LocalPublishState?> get(String provider) {
    return (_db.select(
      _db.localPublishStates,
    )..where((t) => t.provider.equals(provider))).getSingleOrNull();
  }

  /// Upsert by provider. The companion must set `provider`; only the fields it
  /// carries are written (insertOnConflictUpdate updates present columns).
  Future<void> upsert(LocalPublishStatesCompanion entry) async {
    await _db.into(_db.localPublishStates).insertOnConflictUpdate(entry);
  }

  /// Record the post-adopt "deferred self-base" marker for [provider]: a row
  /// with a NULL `baseSeq` (no base published yet) carrying the adopted
  /// library's [adoptedHlcHigh]. Only adopt writes a null `baseSeq` -- the
  /// writer either sets it (base publish, compaction) or preserves the null
  /// while publishing post-adopt changesets without a base -- so a null here
  /// always means "adopted, no self-base yet". SyncService uses it to skip a
  /// publish with nothing to say, and ChangesetWriter uses it to publish
  /// deltas against [adoptedHlcHigh] instead of re-uploading a redundant full
  /// base (a copy of the epoch the peers already hold, #358). Call after
  /// `resetSyncState` has cleared any prior row (so this inserts fresh).
  Future<void> markAdoptedPendingBase(
    String provider,
    String? adoptedHlcHigh,
  ) async {
    // Write every base column EXPLICITLY rather than omitting baseSeq: with
    // insertOnConflictUpdate, absent columns keep their prior values, so an
    // unexpected pre-existing row would retain a non-null baseSeq (and stale
    // base metadata) and silently defeat the null-baseSeq marker. Fully
    // specifying the row makes the marker unambiguous whether it inserts or
    // updates -- a fresh "adopted, no self-base yet" state.
    await _db
        .into(_db.localPublishStates)
        .insertOnConflictUpdate(
          LocalPublishStatesCompanion(
            provider: Value(provider),
            baseSeq: const Value(null),
            basePartCount: const Value(null),
            baseBytes: const Value(null),
            headSeq: const Value(0),
            publishedHlcHigh: Value(adoptedHlcHigh),
            changesetBytesSinceBase: const Value(0),
            relayFloorHlc: const Value(null),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// Nearby sync applied rows as old as [lowestAppliedHlc]. On every
  /// backend whose published clock is newer, lower the relay floor to just
  /// below it (the clock's time and counter with no writer, which sorts
  /// before every clock of that instant), so the next publish carries them.
  /// The published clock itself never moves down. One conditional UPDATE,
  /// so two sessions lowering it at once cannot leave the higher floor.
  Future<void> pullBackRelayFloor(String lowestAppliedHlc) async {
    if (lowestAppliedHlc.length < 23) return;
    final floor = lowestAppliedHlc.substring(0, 23);
    await (_db.update(_db.localPublishStates)..where(
          (t) =>
              t.publishedHlcHigh.isBiggerThanValue(lowestAppliedHlc) &
              (t.relayFloorHlc.isNull() |
                  t.relayFloorHlc.isBiggerThanValue(floor)),
        ))
        .write(LocalPublishStatesCompanion(relayFloorHlc: Value(floor)));
  }

  /// The relay floor served its one export: cleared, unless it changed
  /// since [ifEquals] was read.
  Future<void> clearRelayFloor(String provider, {required String ifEquals}) =>
      (_db.update(_db.localPublishStates)..where(
            (t) =>
                t.provider.equals(provider) & t.relayFloorHlc.equals(ifEquals),
          ))
          .write(const LocalPublishStatesCompanion(relayFloorHlc: Value(null)));

  /// Whether a publish row exists for any provider. Written by the first
  /// base publish or adopt, so a true here is proof this device has synced
  /// even when it never had a peer (a single-device cloud library leaves no
  /// peer cursor, only this row).
  Future<bool> hasAny() async {
    final row =
        await (_db.selectOnly(_db.localPublishStates)
              ..addColumns([_db.localPublishStates.provider])
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Drop publish state for [provider] -- used on backend switch so the device
  /// republishes a base as if new on the new backend.
  Future<void> resetForProvider(String provider) async {
    await (_db.delete(
      _db.localPublishStates,
    )..where((t) => t.provider.equals(provider))).go();
  }
}
