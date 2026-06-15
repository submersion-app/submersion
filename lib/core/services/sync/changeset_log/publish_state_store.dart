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

  /// Drop publish state for [provider] -- used on backend switch so the device
  /// republishes a base as if new on the new backend.
  Future<void> resetForProvider(String provider) async {
    await (_db.delete(
      _db.localPublishStates,
    )..where((t) => t.provider.equals(provider))).go();
  }
}
