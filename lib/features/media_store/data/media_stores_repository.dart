import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// The active store descriptor, secret-free (design spec section 13).
typedef MediaStoreDescriptor = ({
  String id,
  String providerType,
  String displayHint,
  DateTime? lastSweepAt,
});

/// Synced `media_stores` rows: the secret-free announcement that this
/// library has a media store, so other devices can prompt to connect.
class MediaStoresRepository {
  MediaStoresRepository({AppDatabase? database, SyncRepository? syncRepository})
    : _database = database,
      _syncRepository = syncRepository ?? SyncRepository();

  final AppDatabase? _database;
  final SyncRepository _syncRepository;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  Future<void> upsertActive({
    required String storeId,
    required String providerType,
    required String displayHint,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.mediaStores)
        .insertOnConflictUpdate(
          MediaStoresCompanion(
            id: Value(storeId),
            providerType: Value(providerType),
            displayHint: Value(displayHint),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'mediaStores',
      recordId: storeId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// The most recently updated descriptor, or null when the library has no
  /// media store announced.
  Future<MediaStoreDescriptor?> getActive() async {
    final row =
        await (_db.select(_db.mediaStores)
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return (
      id: row.id,
      providerType: row.providerType,
      displayHint: row.displayHint,
      lastSweepAt: row.lastSweepAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastSweepAt!),
    );
  }

  /// Records a completed Verify Library sweep (orphan-prevention spec
  /// 6.4). Synced, so one device's sweep satisfies the fleet-wide 30-day
  /// cadence for every device.
  Future<void> stampLastSweep(String storeId, DateTime at) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.mediaStores,
    )..where((t) => t.id.equals(storeId))).write(
      MediaStoresCompanion(
        lastSweepAt: Value(at.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'mediaStores',
      recordId: storeId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
}
