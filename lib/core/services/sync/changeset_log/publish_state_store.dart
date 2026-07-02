import 'package:drift/drift.dart' show Value;

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
  /// library's [adoptedHlcHigh]. The writer always sets `baseSeq` when it
  /// publishes, so the null uniquely marks "adopted, nothing of our own to
  /// publish yet" -- which SyncService uses to skip re-uploading a redundant
  /// full base (a copy of the epoch the peers already hold, #358). Call after
  /// `resetSyncState` has cleared any prior row (so this inserts fresh).
  Future<void> markAdoptedPendingBase(
    String provider,
    String? adoptedHlcHigh,
  ) async {
    await _db
        .into(_db.localPublishStates)
        .insertOnConflictUpdate(
          LocalPublishStatesCompanion(
            provider: Value(provider),
            publishedHlcHigh: Value(adoptedHlcHigh),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            // baseSeq intentionally absent (null): the deferred marker.
          ),
        );
  }

  /// Drop publish state for [provider] -- used on backend switch so the device
  /// republishes a base as if new on the new backend.
  Future<void> resetForProvider(String provider) async {
    await (_db.delete(
      _db.localPublishStates,
    )..where((t) => t.provider.equals(provider))).go();
  }
}
