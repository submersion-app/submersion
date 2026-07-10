import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

/// Row type alias so callers do not depend on the Drift-generated name.
typedef MediaTransferQueueEntry = MediaTransferQueueData;

/// Backoff schedule in minutes, indexed by (attempts - 1) and clamped.
const List<int> _backoffMinutes = [1, 5, 30, 60];

/// Attempts after which an entry becomes terminally 'failed'.
const int _maxAttempts = 5;

/// Per-device upload/download queue over the local cache database.
/// States: 'pending' | 'transferring' | 'done' | 'failed'.
class MediaTransferQueueRepository {
  MediaTransferQueueRepository({LocalCacheDatabase? database})
    : _database = database;

  final LocalCacheDatabase? _database;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  Future<int> enqueueUpload({required String mediaId}) async {
    final existing =
        await (_db.select(_db.mediaTransferQueue)..where(
              (t) =>
                  t.mediaId.equals(mediaId) &
                  t.direction.equals('upload') &
                  t.state.isIn(['pending', 'transferring']),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final now = DateTime.now().millisecondsSinceEpoch;
    return _db
        .into(_db.mediaTransferQueue)
        .insert(
          MediaTransferQueueCompanion.insert(
            mediaId: mediaId,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<MediaTransferQueueEntry?> nextPending(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    return (_db.select(_db.mediaTransferQueue)
          ..where(
            (t) =>
                t.state.equals('pending') &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(nowMs)),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> markTransferring(int id) => _setState(id, 'transferring');

  Future<void> markDone(int id) => _setState(id, 'done');

  Future<void> markFailed(int id, String error) async {
    final row = await (_db.select(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).getSingle();
    final attempts = row.attempts + 1;
    final terminal = attempts >= _maxAttempts;
    final backoff =
        _backoffMinutes[(attempts - 1).clamp(0, _backoffMinutes.length - 1)];
    final now = DateTime.now();
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: Value(terminal ? 'failed' : 'pending'),
        attempts: Value(attempts),
        nextAttemptAt: Value(
          terminal
              ? null
              : now.add(Duration(minutes: backoff)).millisecondsSinceEpoch,
        ),
        errorMessage: Value(error),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<MediaTransferQueueEntry>> allForTesting() =>
      _db.select(_db.mediaTransferQueue).get();

  Future<void> _setState(int id, String state) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: Value(state),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
