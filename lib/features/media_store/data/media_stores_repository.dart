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

  /// The roster row the store lives on; null for a store announced before
  /// it was recorded.
  String? accountId,
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

  /// Emits whenever the `media_stores` table changes so providers holding the
  /// active store refresh after a sync switches or retires it.
  Stream<void> watchStoresChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.mediaStores));

  Future<void> upsertActive({
    required String storeId,
    required String providerType,
    required String displayHint,
    String? accountId,
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
            // Absent, not null, when unknown: a reattach that does not know
            // the account never clears the recorded one.
            accountId: accountId == null
                ? const Value.absent()
                : Value(accountId),
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
    return row == null ? null : _toDescriptor(row);
  }

  /// The descriptor of store [storeId], or null when this library has none
  /// for it.
  Future<MediaStoreDescriptor?> getById(String storeId) async {
    final row = await (_db.select(
      _db.mediaStores,
    )..where((t) => t.id.equals(storeId))).getSingleOrNull();
    return row == null ? null : _toDescriptor(row);
  }

  MediaStoreDescriptor _toDescriptor(MediaStore row) {
    return (
      id: row.id,
      providerType: row.providerType,
      displayHint: row.displayHint,
      lastSweepAt: row.lastSweepAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastSweepAt!),
      accountId: row.accountId,
    );
  }

  /// Records [accountId] as the roster row store [storeId] lives on, when
  /// its descriptor names none: a store announced before descriptors
  /// recorded their account. Leaves updatedAt alone, as [stampLastSweep]
  /// does: filling in a fact is not a new announcement.
  Future<void> recordAccount(String storeId, String accountId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final written =
        await (_db.update(_db.mediaStores)
              ..where((t) => t.id.equals(storeId) & t.accountId.isNull()))
            .write(MediaStoresCompanion(accountId: Value(accountId)));
    if (written == 0) return;
    await _syncRepository.markRecordPending(
      entityType: 'mediaStores',
      recordId: storeId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// The most recently announced store living on one of [accountIds], or
  /// null when the library has none there.
  Future<MediaStoreDescriptor?> latestOnAccounts(
    Iterable<String> accountIds,
  ) async {
    final ids = accountIds.toList();
    if (ids.isEmpty) return null;
    final row =
        await (_db.select(_db.mediaStores)
              ..where((t) => t.accountId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDescriptor(row);
  }

  /// Records a completed Verify Library sweep (orphan-prevention spec
  /// 6.4). Synced, so one device's sweep satisfies the fleet-wide 30-day
  /// cadence for every device. Leaves updatedAt alone: it orders the
  /// descriptors for [getActive], and a stamp is not a new announcement.
  Future<void> stampLastSweep(String storeId, DateTime at) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.mediaStores,
    )..where((t) => t.id.equals(storeId))).write(
      MediaStoresCompanion(lastSweepAt: Value(at.millisecondsSinceEpoch)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'mediaStores',
      recordId: storeId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
}
