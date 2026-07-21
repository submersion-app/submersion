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

  /// Idempotent per mediaId for every live state: pending/transferring
  /// rows are reused, and a terminally 'failed' row is returned as-is so
  /// backfill or re-import cannot resurrect it with a fresh attempt
  /// budget (explicit retry() is the way back in). Only 'done' rows allow
  /// a new enqueue. Transactional so concurrent enqueues cannot both miss
  /// the select and insert duplicates.
  Future<int> enqueueUpload({required String mediaId}) {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.mediaTransferQueue)..where(
                (t) =>
                    t.mediaId.equals(mediaId) &
                    t.direction.equals('upload') &
                    t.state.isIn(['pending', 'transferring', 'failed']),
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
    });
  }

  /// Forces a fresh upload of [mediaId] at [overrideLevel], replacing any
  /// existing upload row (any state). Used by the per-item re-upload
  /// override; unlike enqueueUpload it bypasses the terminal-state guard.
  Future<int> enqueueReupload({
    required String mediaId,
    required String overrideLevel,
  }) {
    return _db.transaction(() async {
      await (_db.delete(_db.mediaTransferQueue)..where(
            (t) => t.mediaId.equals(mediaId) & t.direction.equals('upload'),
          ))
          .go();
      final now = DateTime.now().millisecondsSinceEpoch;
      return _db
          .into(_db.mediaTransferQueue)
          .insert(
            MediaTransferQueueCompanion.insert(
              mediaId: mediaId,
              overrideLevel: Value(overrideLevel),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
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

  /// Completion also clears resume/progress state and any error message
  /// from earlier attempts: a finished transfer must not leak a stale
  /// resume point into a future re-enqueue of the same media, and a done
  /// row must not display a failure it recovered from.
  Future<void> markDone(int id) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: const Value('done'),
        resumeStateJson: const Value(null),
        progressBytes: const Value(null),
        totalBytes: const Value(null),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Persists (or clears, with null) the adapter's opaque resume point.
  /// markFailed, retry, and defer all PRESERVE it - resuming after a
  /// failure is the entire point.
  Future<void> updateResumeState(int id, String? resumeStateJson) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        resumeStateJson: Value(resumeStateJson),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> updateProgress(
    int id, {
    required int transferredBytes,
    int? totalBytes,
  }) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        progressBytes: Value(transferredBytes),
        totalBytes: Value(totalBytes),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

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

  /// Transfers view feed: active work first, history last.
  Stream<List<MediaTransferQueueEntry>> watchEntries() {
    const rank = {'transferring': 0, 'pending': 1, 'failed': 2, 'done': 3};
    return _db.select(_db.mediaTransferQueue).watch().map((rows) {
      final sorted = [...rows]
        ..sort((a, b) {
          final byState = (rank[a.state] ?? 3).compareTo(rank[b.state] ?? 3);
          if (byState != 0) return byState;
          return b.updatedAt.compareTo(a.updatedAt);
        });
      return sorted;
    });
  }

  /// Newest queue row for [mediaId] in any state, or null when none.
  Stream<MediaTransferQueueEntry?> watchLatestForMedia(String mediaId) {
    return (_db.select(_db.mediaTransferQueue)
          ..where((t) => t.mediaId.equals(mediaId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Puts a terminally failed entry back in play with a clean slate.
  Future<void> retry(int id) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: const Value('pending'),
        attempts: const Value(0),
        nextAttemptAt: const Value(null),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Connectivity/policy postponement: unlike markFailed, no attempt is
  /// consumed - the entry is simply not due until [until].
  Future<void> defer(int id, DateTime until) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        nextAttemptAt: Value(until.millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<int> deleteDone() => (_db.delete(
    _db.mediaTransferQueue,
  )..where((t) => t.state.equals('done'))).go();

  /// Pending + transferring, for backfill progress display.
  Stream<int> watchActiveCount() {
    final count = _db.mediaTransferQueue.id.count();
    final query = _db.selectOnly(_db.mediaTransferQueue)
      ..addColumns([count])
      ..where(_db.mediaTransferQueue.state.isIn(['pending', 'transferring']));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
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
