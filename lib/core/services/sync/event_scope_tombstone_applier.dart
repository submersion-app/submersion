import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

/// Applies a peer's [EventScopeTombstone]: deletes the events it covers and
/// stores it for relay.
class EventScopeTombstoneApplier {
  static final _log = LoggerService.forClass(EventScopeTombstoneApplier);

  /// Ids per DELETE, well under SQLite's bound-variable limit.
  static const int _chunkSize = 500;

  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;

  EventScopeTombstoneApplier({AppDatabase? db, SyncRepository? syncRepository})
    : _dbOverride = db,
      _syncRepository = syncRepository ?? SyncRepository();

  // Lazy, so a restore that swaps the DatabaseService database is picked up.
  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Deletes the events [deletion] covers and returns how many went. Events
  /// pending here (an unpublished local edit) and events the same payload
  /// presents live are kept, as the per-row path keeps them. [deletedAt] is
  /// the delete's time, already defaulted by the caller for an older peer
  /// that sent none.
  Future<int> apply({
    required SyncDeletion deletion,
    required int deletedAt,
    required Set<String> pendingEventIds,
    required Set<String> contradictedEventIds,
  }) async {
    final scope = EventScopeTombstone.tryDecode(deletion.id);
    if (scope == null) {
      _log.warning('Ignoring malformed event scope tombstone ${deletion.id}');
      return 0;
    }
    final deleteHlc = tryParseHlc(deletion.hlc);
    final query = _db.select(_db.diveProfileEvents)
      ..where((t) => t.diveId.equals(scope.diveId));
    final computerId = scope.computerId;
    if (computerId != null) {
      query.where((t) => t.computerId.equals(computerId));
    }
    final doomed = [
      for (final row in await query.get())
        if (!pendingEventIds.contains(row.id) &&
            !contradictedEventIds.contains(row.id) &&
            eventPredatesScopeDelete(
              rowHlc: tryParseHlc(row.hlc),
              rowCreatedAt: row.createdAt,
              deleteHlc: deleteHlc,
              deletedAt: deletedAt,
            ))
          row.id,
    ];
    for (var i = 0; i < doomed.length; i += _chunkSize) {
      final chunk = doomed.sublist(i, (i + _chunkSize).clamp(0, doomed.length));
      await (_db.delete(
        _db.diveProfileEvents,
      )..where((t) => t.id.isIn(chunk))).go();
    }
    await _syncRepository.relayScopedDeletion(
      recordId: deletion.id,
      deletedAt: deletedAt,
      originHlc: deletion.hlc,
    );
    return doomed.length;
  }
}
