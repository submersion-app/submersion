import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';

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

  /// Entries some worker in this process has claimed ([claimNextPending]) and
  /// not yet released, per database. Keyed on the database object, so every
  /// repository over one database shares them (production builds several)
  /// and two databases never do.
  static final Expando<Set<int>> _leases = Expando('media queue leases');

  Set<int> get _held => _leases[_db] ??= <int>{};

  static final Expando<_HoldBoard> _boards = Expando('media queue holds');

  _HoldBoard get _board => _boards[_db] ??= _HoldBoard();

  /// Why the drain over this database is holding, or null when it is not.
  /// In memory like the leases: it describes this process's worker, and the
  /// next process's first drain derives it again.
  MediaTransferHold? get currentHold => _board.hold;

  /// Records (or, with null, clears) the drain's hold. Every repository over
  /// this database sees it, and every open [watchSummary] re-emits.
  ///
  /// [owner] names who recorded it, so [clearHoldOwnedBy] can clear only
  /// its own: several workers can share one database for a moment (a
  /// rebuild), and one retiring must not wipe the reason its replacement
  /// just recorded.
  void recordHold(MediaTransferHold? hold, {Object? owner}) =>
      _board.set(hold, owner: owner);

  /// Clears the hold if [owner] recorded the current one; otherwise leaves
  /// it alone.
  void clearHoldOwnedBy(Object owner) {
    final board = _board;
    if (identical(board.owner, owner)) board.set(null);
  }

  /// Selects the next due row no one holds and claims it for the caller,
  /// who must [release] it once done with it. Until then no other caller in
  /// this process selects it ([nextPending] and this skip it) and
  /// [requeueStale] leaves it alone.
  ///
  /// Exclusive: two workers draining one queue at once (a runtime rebuild
  /// leaves the superseded one running) never take the same row. The claim
  /// is checked and taken synchronously once the query returns, so nothing
  /// can run between the two; a row another caller claimed while this one
  /// was reading is skipped by asking again.
  ///
  /// The read that found the row may be stale: another worker can claim,
  /// finish and release it while the query is in flight. So the row is read
  /// again once claimed, and kept only while still pending and due; the
  /// fresh row is what the caller gets. That second read cannot be stale:
  /// with the claim held no one else takes the row, and a previous holder
  /// released it only after its final state was written.
  Future<MediaTransferQueueEntry?> claimNextPending(DateTime now) async {
    while (true) {
      final entry = await nextPending(now);
      if (entry == null) return null;
      if (!_held.add(entry.id)) continue;
      final MediaTransferQueueEntry? fresh;
      try {
        fresh = await _dueRow(entry.id, now);
      } on Object {
        // No caller will ever hold this claim, so it goes back now; kept, it
        // would hide the row from every later drain in the process.
        release(entry.id);
        rethrow;
      }
      if (fresh != null) return fresh;
      // Settled or re-deferred since the read: not this caller's to take.
      release(entry.id);
    }
  }

  /// Whether [id] is claimed in this process, for tests that cannot ask
  /// the database (it is what failed).
  @visibleForTesting
  bool isClaimedForTesting(int id) => _held.contains(id);

  Future<MediaTransferQueueEntry?> _dueRow(int id, DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    return (_db.select(_db.mediaTransferQueue)..where(
          (t) =>
              t.id.equals(id) &
              t.state.equals('pending') &
              (t.nextAttemptAt.isNull() |
                  t.nextAttemptAt.isSmallerOrEqualValue(nowMs)),
        ))
        .getSingleOrNull();
  }

  /// Gives back a claim from [claimNextPending] whose row no transfer
  /// touched (a gate stop, a deferral). Releasing an id that is not held
  /// does nothing.
  void release(int id) => _held.remove(id);

  /// Gives back the claim of a transfer that has settled, and announces it
  /// on [claimReleases], so an idle worker over this database can come back
  /// for what the row settled into: a transfer can settle long after the
  /// drain that started it finished, even after its worker was replaced,
  /// and a backoff it left behind has no other wakeup.
  void releaseSettled(int id) {
    if (_held.remove(id)) _releaseSignal.add(null);
  }

  static final Expando<StreamController<void>> _releaseSignals = Expando(
    'media queue claim releases',
  );

  // Synchronous, so a worker still draining sees its own release while its
  // drain is marked running, and ignores it.
  StreamController<void> get _releaseSignal =>
      _releaseSignals[_db] ??= StreamController<void>.broadcast(sync: true);

  /// Fires each time a transfer over this database settles and gives back
  /// its claim ([releaseSettled]).
  Stream<void> get claimReleases => _releaseSignal.stream;

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

  /// Enqueue for reverse repair (verify sweep, orphan-prevention spec
  /// 6.2): like [enqueueUpload], but a terminally failed row is re-armed
  /// with a fresh attempt budget via [retry]. The sweep just observed the
  /// remote object is missing - new evidence that a fresh attempt is
  /// warranted, exactly the judgment an explicit user retry expresses.
  /// Without this, a failed row would swallow the repair: nextPending
  /// never selects 'failed', yet the intent would count as queued.
  Future<int> enqueueRepairUpload({required String mediaId}) {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.mediaTransferQueue)..where(
                (t) =>
                    t.mediaId.equals(mediaId) &
                    t.direction.equals('upload') &
                    t.state.isIn(['pending', 'transferring', 'failed']),
              ))
              .getSingleOrNull();
      if (existing != null) {
        if (existing.state == 'failed') await retry(existing.id);
        return existing.id;
      }
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

  /// Enqueues a remote-blob delete intent (orphan-prevention spec 5.1).
  /// One entry covers all tiers (original + thumb + rendition) of one
  /// content hash. Idempotent per hash for every live state, mirroring
  /// enqueueUpload's semantics: pending/transferring/failed delete rows
  /// are reused (the sweep is the backstop for terminal failures); only
  /// 'done' allows a fresh insert. [originalExt] and [renditionExt] are
  /// captured here because the media row is gone by drain time.
  Future<int> enqueueDelete({
    required String mediaId,
    required String contentHash,
    required String originalExt,
    required String renditionExt,
  }) {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.mediaTransferQueue)
                ..where(
                  (t) =>
                      t.direction.equals('delete') &
                      t.contentHash.equals(contentHash) &
                      t.state.isIn(['pending', 'transferring', 'failed']),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return existing.id;

      final now = DateTime.now().millisecondsSinceEpoch;
      return _db
          .into(_db.mediaTransferQueue)
          .insert(
            MediaTransferQueueCompanion.insert(
              mediaId: mediaId,
              direction: const Value('delete'),
              contentHash: Value(contentHash),
              payloadJson: Value(
                jsonEncode({
                  'originalExt': originalExt,
                  'renditionExt': renditionExt,
                }),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  /// Whether any row is still outstanding: pending (due or deferred) or
  /// stranded in transferring. The resume gate's question, because each of
  /// those needs a built runtime to move: a drain to take or reclaim it, or
  /// the worker's wakeup to come back for it.
  Future<bool> hasOutstandingWork() async {
    final row =
        await (_db.select(_db.mediaTransferQueue)
              ..where((t) => t.state.isIn(['pending', 'transferring']))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// The next due row no worker in this process has claimed. Workers take
  /// rows through [claimNextPending]; this is the read-only question "is
  /// there work a drain could take right now".
  Future<MediaTransferQueueEntry?> nextPending(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    final held = _held.toList();
    return (_db.select(_db.mediaTransferQueue)
          ..where((t) {
            final due =
                t.state.equals('pending') &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(nowMs));
            return held.isEmpty ? due : due & t.id.isNotIn(held);
          })
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

  /// [retryAfter] overrides the default minute-scale backoff for failures
  /// whose underlying cause is itself rate-limited on a much longer clock.
  /// Asset resolution is the motivating case: once it records a media item as
  /// unresolved it refuses to re-scan the gallery for 24h/3d/7d, so a retry on
  /// the default 1/5/30/60-minute ladder cannot reach the gallery at all - it
  /// short-circuits to the same failure and silently burns one of the five
  /// attempts. Passing a [retryAfter] longer than that lockout keeps the
  /// attempt cap meaningful by ensuring every attempt is a real one.
  /// Returns true when this failure was the terminal one (attempt budget
  /// exhausted, state now 'failed') so callers can run terminal-only
  /// cleanup such as abandoning a resumable upload session.
  Future<bool> markFailed(int id, String error, {Duration? retryAfter}) async {
    final row = await (_db.select(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).getSingle();
    final attempts = row.attempts + 1;
    final terminal = attempts >= _maxAttempts;
    final backoff =
        retryAfter ??
        Duration(
          minutes:
              _backoffMinutes[(attempts - 1).clamp(
                0,
                _backoffMinutes.length - 1,
              )],
        );
    final now = DateTime.now();
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: Value(terminal ? 'failed' : 'pending'),
        attempts: Value(attempts),
        nextAttemptAt: Value(
          terminal ? null : now.add(backoff).millisecondsSinceEpoch,
        ),
        errorMessage: Value(error),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
    return terminal;
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

  /// Newest upload row for [mediaId] in any state, or null when none.
  /// Delete rows are excluded: they describe a dead row's blob, not this
  /// item's transfer status.
  Stream<MediaTransferQueueEntry?> watchLatestForMedia(String mediaId) {
    return (_db.select(_db.mediaTransferQueue)
          ..where(
            (t) => t.mediaId.equals(mediaId) & t.direction.equals('upload'),
          )
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

  /// Crash recovery: returns rows stranded in 'transferring' back to
  /// 'pending'. A drain can be interrupted (app killed or backgrounded
  /// mid-upload) after markTransferring but before markDone/markFailed, and
  /// nextPending only selects 'pending', so such a row is invisible to the
  /// drainer forever and can be neither retried (failed-only) nor cleared
  /// (done-only) from the Transfers UI.
  ///
  /// Safe to run at any time: rows a worker in this process has claimed
  /// ([claimNextPending]) are skipped, so only a row no live transfer owns
  /// (its process died) is reclaimed. The worker runs this at the start of
  /// every drain.
  ///
  /// A reclaimed row is made immediately due with its stale progress
  /// cleared, but keeps its resume point so a resumable adapter can pick up
  /// where it left off. Any leftover error message is cleared too: a row can
  /// reach 'transferring' still carrying an earlier attempt's error (markFailed
  /// sets it, markTransferring does not clear it), and the Transfers UI shows
  /// errorMessage whenever it is non-null - a row reclaimed after an
  /// interruption must not display a failure it recovered from. Attempts are
  /// untouched: an interruption is not a failed attempt (contrast markFailed),
  /// yet a genuinely broken item must still count toward its cap (contrast
  /// retry). Returns the number of rows reclaimed.
  Future<int> requeueStale() async {
    final transferring =
        await (_db.selectOnly(_db.mediaTransferQueue)
              ..addColumns([_db.mediaTransferQueue.id])
              ..where(_db.mediaTransferQueue.state.equals('transferring')))
            .map((row) => row.read(_db.mediaTransferQueue.id)!)
            .get();
    // Claims are consulted AFTER the read, with no await between: a live
    // row is claimed before it is marked transferring and released only
    // after its final state is written, so a row still transferring and
    // unclaimed now is stranded. A claim snapshot taken before the read
    // could miss a row claimed and marked during it.
    final held = _held;
    final stranded = [
      for (final id in transferring)
        if (!held.contains(id)) id,
    ];
    if (stranded.isEmpty) return 0;
    // By id, and still transferring: a stranded row cannot be claimed in
    // the meantime (only pending rows are), so this touches nothing live.
    return (_db.update(_db.mediaTransferQueue)
          ..where((t) => t.id.isIn(stranded) & t.state.equals('transferring')))
        .write(
          MediaTransferQueueCompanion(
            state: const Value('pending'),
            progressBytes: const Value(null),
            totalBytes: const Value(null),
            nextAttemptAt: const Value(null),
            errorMessage: const Value(null),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// Connectivity/policy postponement: unlike markFailed, no attempt is
  /// consumed - the entry is simply not due until [until].
  ///
  /// [reason] is written as the entry's error when given, so a postponement
  /// the user should know about (a budget expiry) is not silent; a policy
  /// deferral passes none and leaves any earlier error in place.
  ///
  /// Only while the row is still in play (pending or transferring): a
  /// budget-expired transfer can settle between its timeout and this write,
  /// and a deferral landing after it would write over what it settled to,
  /// burying a failed row's real error or leaving one on a done row.
  ///
  /// [ifAttempts] makes it a compare-and-set on the attempt count the
  /// caller saw: a non-terminal failure leaves the row pending too, with
  /// its own retry time and error, and moves the count, which is how a
  /// deferral landing after it knows to leave it alone.
  Future<void> defer(
    int id,
    DateTime until, {
    String? reason,
    int? ifAttempts,
  }) async {
    await (_db.update(_db.mediaTransferQueue)..where((t) {
          final inPlay =
              t.id.equals(id) & t.state.isIn(const ['pending', 'transferring']);
          return ifAttempts == null
              ? inPlay
              : inPlay & t.attempts.equals(ifAttempts);
        }))
        .write(
          MediaTransferQueueCompanion(
            nextAttemptAt: Value(until.millisecondsSinceEpoch),
            errorMessage: reason == null ? const Value.absent() : Value(reason),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// Fails [id] terminally with [error], counting no attempt: for an entry
  /// this device can never process, where a retry ladder would only burn
  /// time before saying the same thing. The Transfers page's Retry is the
  /// way back in.
  Future<void> fail(int id, String error) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: const Value('failed'),
        nextAttemptAt: const Value(null),
        errorMessage: Value(error),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<int> deleteDone() => (_db.delete(
    _db.mediaTransferQueue,
  )..where((t) => t.state.equals('done'))).go();

  /// Removes a single queue entry.
  ///
  /// The queue is local bookkeeping, not synced data, so a plain delete is
  /// enough -- no tombstone. Callers must not delete a row that is currently
  /// `transferring`; see the guard in the transfers page.
  Future<int> delete(int id) =>
      (_db.delete(_db.mediaTransferQueue)..where((t) => t.id.equals(id))).go();

  /// Live split of the outstanding queue for the settings page.
  ///
  /// Replaces a plain pending+transferring count, which reported a row
  /// parked in a multi-hour retry backoff as work in progress. Due-ness is
  /// evaluated per emission against [now]; a row that becomes due purely by
  /// the passage of time does not re-emit on its own, which is why the
  /// worker arms a timer at [earliestPendingWakeup] - that drain writes,
  /// and the write is what refreshes this stream. A change of hold
  /// ([recordHold]) re-emits too, with no row written.
  Stream<MediaTransferSummary> watchSummary({DateTime Function()? now}) {
    final clock = now ?? DateTime.now;
    final query = _db.select(_db.mediaTransferQueue)
      ..where((t) => t.state.isIn(['pending', 'transferring']));
    final board = _board;
    return Stream.multi((controller) {
      List<MediaTransferQueueEntry>? rows;
      void emit() {
        final current = rows;
        if (current != null) {
          controller.add(_summarize(current, clock(), board.hold));
        }
      }

      final rowSub = query.watch().listen((next) {
        rows = next;
        emit();
      }, onError: controller.addError);
      final holdSub = board.changes.listen((_) => emit());
      controller.onCancel = () async {
        await holdSub.cancel();
        await rowSub.cancel();
      };
    });
  }

  static MediaTransferSummary _summarize(
    List<MediaTransferQueueEntry> rows,
    DateTime now,
    MediaTransferHold? hold,
  ) {
    final nowMs = now.millisecondsSinceEpoch;
    var transferring = 0;
    var queued = 0;
    var waiting = 0;
    String? reason;
    int? reasonAt;
    // Single pass, no intermediate list: this re-runs on every queue write,
    // and a backfill writes once per row transition over the whole library.
    for (final row in rows) {
      final until = row.nextAttemptAt;
      if (row.state == 'transferring') {
        transferring++;
      } else if (until != null && until > nowMs) {
        waiting++;
        // Newest wins: of several parked rows, the freshest failure is the
        // one someone opening this page is looking for.
        final error = row.errorMessage;
        if (error != null && (reasonAt == null || row.updatedAt > reasonAt)) {
          reason = error;
          reasonAt = row.updatedAt;
        }
      } else {
        queued++;
      }
    }
    return MediaTransferSummary(
      transferring: transferring,
      queued: queued,
      waiting: waiting,
      waitingReason: hold?.message ?? reason,
      hold: hold,
    );
  }

  /// The soonest future attempt time among pending rows, or null when no
  /// pending row is waiting on one. Drives the worker's retry wakeup.
  ///
  /// Deliberately excludes rows that are already due. Those are the drain's
  /// own job, and a drain that left one behind did so because it was
  /// suspended - offline, or a failed preflight - both of which have their
  /// own triggers. Arming a timer for an already-due row would spin a tight
  /// loop against a drain that keeps declining to run.
  ///
  /// That leaves a row whose backoff expired *during* a drain that ran fine
  /// answering to neither this query nor the drain's own (#1210). Closing that
  /// gap is the caller's job rather than this query's, because only the worker
  /// knows which of the two cases its drain was. See the immediate-wakeup
  /// branch of `MediaStoreWorker._armWakeup`, in media_store_worker.dart.
  Future<DateTime?> earliestPendingWakeup(DateTime now) async {
    final soonest = _db.mediaTransferQueue.nextAttemptAt.min();
    final query = _db.selectOnly(_db.mediaTransferQueue)
      ..addColumns([soonest])
      ..where(
        _db.mediaTransferQueue.state.equals('pending') &
            // A null nextAttemptAt fails this comparison in SQL, which is
            // exactly right: an undeferred row is due, not a wakeup.
            _db.mediaTransferQueue.nextAttemptAt.isBiggerThanValue(
              now.millisecondsSinceEpoch,
            ),
      );
    final row = await query.getSingleOrNull();
    final ms = row?.read(soonest);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
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

/// The hold for one database, and a tick whenever it changes.
class _HoldBoard {
  MediaTransferHold? hold;

  /// Who recorded [hold], or null when it is clear or no owner was named.
  Object? owner;

  /// Synchronous, so a summary re-emits within the recordHold call that
  /// changed it, not a microtask later behind a row write.
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<void> get changes => _changes.stream;

  void set(MediaTransferHold? next, {Object? owner}) {
    this.owner = next == null ? null : owner;
    if (next == hold) return;
    hold = next;
    _changes.add(null);
  }
}
