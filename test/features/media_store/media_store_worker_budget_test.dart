import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_delete_processor.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

/// Processes every entry except the ones named in [hangOn], which are left
/// unresolved for the life of the test - the shape of a transfer that never
/// comes back rather than one that fails.
class _HangingPipeline extends MediaUploadPipeline {
  _HangingPipeline({
    required this.queueRef,
    required this.hangOn,
    required super.mediaRepository,
    required super.queue,
    required super.store,
    required super.registry,
    required super.cache,
    this.markTransferringFirst = true,
  });

  final MediaTransferQueueRepository queueRef;
  final Set<String> hangOn;

  /// Whether a hanging entry gets as far as `markTransferring`. The real
  /// pipeline always does; false models a hang in the queue write itself,
  /// which leaves the row 'pending' and therefore re-selectable.
  final bool markTransferringFirst;

  final processed = <String>[];
  final _stuck = <Completer<UploadOutcome>>[];

  /// How many hanging calls were started, finished or not.
  int get hangs => _stuck.length;

  /// Releases every parked call so the test ends with nothing in flight.
  void releaseAll() {
    for (final completer in _stuck) {
      if (!completer.isCompleted) completer.complete(UploadOutcome.failed);
    }
  }

  @override
  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    if (hangOn.contains(entry.mediaId)) {
      if (markTransferringFirst) await queueRef.markTransferring(entry.id);
      final completer = Completer<UploadOutcome>();
      _stuck.add(completer);
      return completer.future;
    }
    processed.add(entry.mediaId);
    await queueRef.markDone(entry.id);
    return UploadOutcome.uploaded;
  }
}

/// Fails its first attempt back into the queue as immediately due, then
/// succeeds: the shape of a transient failure with no backoff left.
class _FailsOncePipeline extends MediaUploadPipeline {
  _FailsOncePipeline({
    required this.queueRef,
    required super.mediaRepository,
    required super.queue,
    required super.store,
    required super.registry,
    required super.cache,
  });

  final MediaTransferQueueRepository queueRef;
  var attempts = 0;

  @override
  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    attempts++;
    if (attempts == 1) {
      await queueRef.markFailed(entry.id, 'blip', retryAfter: Duration.zero);
      return UploadOutcome.failed;
    }
    await queueRef.markDone(entry.id);
    return UploadOutcome.uploaded;
  }
}

/// Fails its row back into the queue behind an hour's backoff, then never
/// returns: a transfer whose real failure landed just before its budget ran
/// out.
class _FailsThenHangsPipeline extends MediaUploadPipeline {
  _FailsThenHangsPipeline({
    required this.queueRef,
    required super.mediaRepository,
    required super.queue,
    required super.store,
    required super.registry,
    required super.cache,
  });

  final MediaTransferQueueRepository queueRef;
  final _never = Completer<UploadOutcome>();

  void releaseAll() {
    if (!_never.isCompleted) _never.complete(UploadOutcome.failed);
  }

  @override
  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    await queueRef.markFailed(
      entry.id,
      'real failure',
      retryAfter: const Duration(hours: 1),
    );
    return _never.future;
  }
}

/// Marks its row transferring, waits on [release], then fails it back into
/// the queue behind an hour's backoff: a transfer that outlives the budget
/// and fails late.
class _LateFailPipeline extends MediaUploadPipeline {
  _LateFailPipeline({
    required this.queueRef,
    required super.mediaRepository,
    required super.queue,
    required super.store,
    required super.registry,
    required super.cache,
  });

  final MediaTransferQueueRepository queueRef;
  final release = Completer<void>();

  @override
  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    await queueRef.markTransferring(entry.id);
    await release.future;
    await queueRef.markFailed(
      entry.id,
      'late',
      retryAfter: const Duration(hours: 1),
    );
    return UploadOutcome.failed;
  }
}

class _HangingDeleteProcessor extends MediaDeleteProcessor {
  _HangingDeleteProcessor({
    required super.queue,
    required super.store,
    required super.mediaRepository,
  });

  final _stuck = <Completer<void>>[];

  void releaseAll() {
    for (final completer in _stuck) {
      if (!completer.isCompleted) completer.complete();
    }
  }

  @override
  Future<void> process(MediaTransferQueueEntry entry) {
    final completer = Completer<void>();
    _stuck.add(completer);
    return completer.future;
  }
}

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late MediaTransferQueueRepository queue;

  /// Short enough that a test waits it out in real time. The worker's default
  /// is minutes; the seam exists so the budget is assertable at all.
  const budget = Duration(milliseconds: 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('worker_budget');
    queue = MediaTransferQueueRepository(database: cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  _HangingPipeline buildPipeline({
    required Set<String> hangOn,
    bool markTransferringFirst = true,
  }) {
    return _HangingPipeline(
      queueRef: queue,
      hangOn: hangOn,
      markTransferringFirst: markTransferringFirst,
      mediaRepository: mediaRepository,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
  }

  // Issue #1270: the drain is sequential and single-flight, so an upload that
  // never returns holds _running forever and every later kick - connectivity,
  // enqueue, the retry wakeup - becomes a no-op. One unreachable item froze
  // the whole queue, and the next launch's reclaim handed the same row back to
  // the same wedge.
  test('an entry that never completes does not freeze the rest of the '
      'queue', () async {
    await queue.enqueueUpload(mediaId: 'stuck');
    await queue.enqueueUpload(mediaId: 'healthy');
    final pipeline = buildPipeline(hangOn: {'stuck'});
    addTearDown(pipeline.releaseAll);
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(pipeline.processed, ['healthy']);
  });

  // The budget stops the drain WAITING; it cannot stop the upload, because
  // Dart cannot cancel a Future. A hang before markTransferring therefore
  // leaves the row 'pending' and re-selectable, and without the deferral the
  // loop would pick it straight back up and spin.
  test('a budgeted-out entry is deferred so the drain cannot spin on '
      'it', () async {
    await queue.enqueueUpload(mediaId: 'stuck');
    final pipeline = buildPipeline(
      hangOn: {'stuck'},
      markTransferringFirst: false,
    );
    addTearDown(pipeline.releaseAll);
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    final rows = await queue.allForTesting();
    expect(rows.single.state, 'pending');
    expect(rows.single.nextAttemptAt, isNotNull);
    // A budget expiry is a postponement, not a failed attempt: the entry may
    // still be uploading, and burning one of its five attempts would retire a
    // healthy-but-slow item.
    expect(rows.single.attempts, 0);
  });

  // The transfer's own failure landed before the budget ran out: its error
  // and retry time are the truth, and the deferral must not replace them.
  test('a budget expiry does not overwrite a failure the transfer already '
      'recorded', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final pipeline = _FailsThenHangsPipeline(
      queueRef: queue,
      mediaRepository: mediaRepository,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    addTearDown(pipeline.releaseAll);
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    final row = (await queue.allForTesting()).single;
    expect(row.errorMessage, 'real failure');
    expect(
      row.nextAttemptAt,
      greaterThan(
        DateTime.now().add(const Duration(minutes: 55)).millisecondsSinceEpoch,
      ),
      reason: 'the failure\'s hour, not the deferral\'s ten minutes',
    );
  });

  // Spec 7.1: a postponement the user should know about is not silent.
  test('a budget expiry leaves a reason on the entry', () async {
    await queue.enqueueUpload(mediaId: 'stuck');
    final pipeline = buildPipeline(hangOn: {'stuck'});
    addTearDown(pipeline.releaseAll);
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(
      (await queue.allForTesting()).single.errorMessage,
      contains('budget'),
    );
  });

  // The preflight runs before every entry and reads smv1/store.json out of the
  // bucket. Only the S3 adapter carries HTTP timeouts of its own, so on the
  // others a stalled read wedges the drain before any row is touched.
  test('a preflight that never answers suspends the drain instead of '
      'hanging it', () async {
    await queue.enqueueUpload(mediaId: 'healthy');
    final pipeline = buildPipeline(hangOn: const {});
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () => Completer<MediaTransferHoldKind?>().future,
      preflightBudget: budget,
    );
    addTearDown(worker.dispose);

    await expectLater(worker.drain(), completes);
    expect(pipeline.processed, isEmpty);
  });

  // A process killed mid-upload leaves its row in 'transferring', which
  // nextPending never selects (spec 7.1: reclaimed by every drain).
  test('a drain reclaims a row stranded in transferring', () async {
    final id = await queue.enqueueUpload(mediaId: 'stranded');
    await queue.markTransferring(id);
    final pipeline = buildPipeline(hangOn: const {});
    final worker = MediaStoreWorker(queue: queue, pipeline: pipeline);
    addTearDown(worker.dispose);

    await worker.drain();

    expect(pipeline.processed, ['stranded']);
  });

  // The budget stops the drain waiting, not the upload. The next drain's
  // reclaim must leave that row to the transfer still running it, or the
  // item is uploaded twice at once.
  test('a drain does not reclaim the row a timed-out transfer still '
      'runs', () async {
    await queue.enqueueUpload(mediaId: 'stuck');
    final pipeline = buildPipeline(hangOn: {'stuck'});
    addTearDown(pipeline.releaseAll);
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();
    await worker.drain();

    expect(pipeline.hangs, 1);
    expect((await queue.allForTesting()).single.state, 'transferring');
  });

  // A hang BEFORE markTransferring leaves the row pending, deferred only for
  // the defer window. Once that passes, a drain must still not select the row
  // while the first transfer runs.
  test('a timed-out transfer that never marked its row is not taken '
      'twice', () async {
    final id = await queue.enqueueUpload(mediaId: 'stuck');
    final pipeline = buildPipeline(
      hangOn: {'stuck'},
      markTransferringFirst: false,
    );
    addTearDown(pipeline.releaseAll);
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();
    // The defer window passes while the transfer still hangs.
    await queue.defer(id, DateTime.now().subtract(const Duration(minutes: 1)));
    await worker.drain();

    expect(pipeline.hangs, 1);
  });

  // The drain that timed out finished long ago, and saw the row as
  // transferring, so it armed nothing for it. When the transfer later fails
  // back into the queue, something must schedule the retry.
  test('a transfer that fails after its budget still gets a retry '
      'scheduled', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final pipeline = _LateFailPipeline(
      queueRef: queue,
      mediaRepository: mediaRepository,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();
    expect(worker.wakeupDelayForTesting, isNull);

    pipeline.release.complete();
    for (var i = 0; i < 50 && worker.wakeupDelayForTesting == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(
      worker.wakeupDelayForTesting,
      greaterThan(const Duration(minutes: 55)),
      reason: 'armed for the row the late failure deferred',
    );
  });

  // A runtime rebuild disposes the old worker while its transfer runs. The
  // replacement saw the row claimed and armed nothing; when the old transfer
  // then fails into a backoff inside its budget, the disposed worker cannot
  // arm a timer. The replacement must hear of it.
  test('a transfer that settles after its worker was replaced still gets a '
      'retry scheduled', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final pipeline = _LateFailPipeline(
      queueRef: queue,
      mediaRepository: mediaRepository,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    final superseded = MediaStoreWorker(queue: queue, pipeline: pipeline);
    final replacement = MediaStoreWorker(
      queue: MediaTransferQueueRepository(database: cacheDb),
      pipeline: buildPipeline(hangOn: const {}),
    );
    addTearDown(replacement.dispose);

    final first = superseded.drain();
    for (var i = 0; i < 50; i++) {
      final rows = await queue.allForTesting();
      if (rows.single.state == 'transferring') break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    superseded.dispose();
    await replacement.drain();
    expect(replacement.wakeupDelayForTesting, isNull);

    pipeline.release.complete();
    await first;
    for (var i = 0; i < 50 && replacement.wakeupDelayForTesting == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(
      replacement.wakeupDelayForTesting,
      greaterThan(const Duration(minutes: 55)),
    );
  });

  // A drain is single-flight through the scheduling of its wakeup, not only
  // its loop: a transfer that settles while it is scheduling must not start
  // a second drain beside it (the two would overwrite each other's timer
  // and hold). The settlement is not lost either: a follow-up drain runs
  // once scheduling is done.
  test('a release while the wakeup is being scheduled waits for it', () async {
    final scheduling = _BlocksFirstWakeupQuery(cacheDb);
    final pipeline = buildPipeline(hangOn: const {});
    final worker = MediaStoreWorker(queue: scheduling, pipeline: pipeline);
    addTearDown(worker.dispose);

    final first = worker.drain();
    await scheduling.blocked.future;

    // Another worker's transfer settles meanwhile.
    final other = MediaTransferQueueRepository(database: cacheDb);
    await other.enqueueUpload(mediaId: 'm1');
    final claimed = (await other.claimNextPending(DateTime.now()))!;
    final claimsBefore = scheduling.claims;
    other.releaseSettled(claimed.id);
    await pumpEventQueue();
    expect(scheduling.claims, claimsBefore, reason: 'no second drain');

    scheduling.unblock.complete();
    await first;
    for (var i = 0; i < 50 && pipeline.processed.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(pipeline.processed, ['m1'], reason: 'the follow-up drain ran');
  });

  // The claim goes back when the transfer settles, whatever its outcome: a
  // row that failed back into the queue must be selectable again.
  test('a row that failed back into the queue is taken again', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final pipeline = _FailsOncePipeline(
      queueRef: queue,
      mediaRepository: mediaRepository,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    final worker = MediaStoreWorker(queue: queue, pipeline: pipeline);
    addTearDown(worker.dispose);

    await worker.drain();

    expect(pipeline.attempts, 2);
    expect((await queue.allForTesting()).single.state, 'done');
  });

  // A runtime rebuild leaves the superseded worker draining while its
  // replacement starts. A row one worker has selected (here, held at the
  // gate) must not be selected by the other.
  test('two workers never process the same row', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final pipeline = buildPipeline(hangOn: const {});
    final atGate = Completer<void>();
    final pass = Completer<WorkerGate>();
    final superseded = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      gate: (_) {
        if (!atGate.isCompleted) atGate.complete();
        return pass.future;
      },
    );
    addTearDown(superseded.dispose);
    final replacement = MediaStoreWorker(
      queue: MediaTransferQueueRepository(database: cacheDb),
      pipeline: pipeline,
    );
    addTearDown(replacement.dispose);

    final first = superseded.drain();
    await atGate.future;
    await replacement.drain();
    expect(pipeline.processed, isEmpty, reason: 'the row is taken');

    pass.complete(WorkerGate.proceed);
    await first;
    expect(pipeline.processed, ['m1']);
  });

  // Deletes share the drain, so they wedge it the same way an upload does.
  test('a delete entry that never completes does not freeze the '
      'queue', () async {
    await queue.enqueueDelete(
      mediaId: 'gone',
      contentHash: 'abc',
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    await queue.enqueueUpload(mediaId: 'healthy');
    final pipeline = buildPipeline(hangOn: const {});
    final deleteProcessor = _HangingDeleteProcessor(
      queue: queue,
      store: InMemoryMediaObjectStore(),
      mediaRepository: mediaRepository,
    );
    addTearDown(deleteProcessor.releaseAll);
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      deleteProcessor: deleteProcessor,
      entryBudget: budget,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(pipeline.processed, ['healthy']);
  });
}

/// Blocks its first wakeup query until [unblock], so a test can land events
/// while a drain is scheduling its wakeup. Counts claims, which only a
/// running drain makes.
class _BlocksFirstWakeupQuery extends MediaTransferQueueRepository {
  _BlocksFirstWakeupQuery(LocalCacheDatabase db) : super(database: db);

  final blocked = Completer<void>();
  final unblock = Completer<void>();
  var claims = 0;

  @override
  Future<DateTime?> earliestPendingWakeup(DateTime now) async {
    if (!blocked.isCompleted) {
      blocked.complete();
      await unblock.future;
    }
    return super.earliestPendingWakeup(now);
  }

  @override
  Future<MediaTransferQueueEntry?> claimNextPending(DateTime now) {
    claims++;
    return super.claimNextPending(now);
  }
}
