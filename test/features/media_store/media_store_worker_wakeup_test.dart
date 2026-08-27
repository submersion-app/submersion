import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

class _RecordingPipeline extends MediaUploadPipeline {
  _RecordingPipeline({
    required this.queueRef,
    required super.mediaRepository,
    required super.queue,
    required super.store,
    required super.registry,
    required super.cache,
  });

  final MediaTransferQueueRepository queueRef;
  final processed = <String>[];

  /// When set, process() parks here until completed, holding the drain
  /// open so a test can act while it is in flight.
  Completer<void>? gate;

  @override
  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    processed.add(entry.mediaId);
    final held = gate;
    if (held != null) await held.future;
    await queueRef.markDone(entry.id);
    return UploadOutcome.uploaded;
  }
}

/// Widens the window between the drain's last due-check and the moment the
/// wakeup is armed. That window is where the row in #1210 fell through: too
/// early for the drain's clock reading, already due by the arming one.
///
/// One-shot, and only on an empty result: the lag has to land after the last
/// [nextPending] of the drain loop, and re-lagging every later drain would
/// just pad the test.
class _LaggingQueue extends MediaTransferQueueRepository {
  _LaggingQueue({required super.database, required this.lag});

  final Duration lag;
  bool _lagged = false;

  @override
  Future<MediaTransferQueueEntry?> nextPending(DateTime now) async {
    final entry = await super.nextPending(now);
    if (entry == null && !_lagged) {
      _lagged = true;
      await Future<void>.delayed(lag);
    }
    return entry;
  }
}

/// Polls [condition] until true or [within] elapses. Condition-based rather
/// than a fixed sleep: the wakeup fires on a real timer, and a fixed delay
/// either flakes under load or pads every run.
Future<bool> _waitFor(
  bool Function() condition, {
  Duration within = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(within);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return condition();
}

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late MediaTransferQueueRepository queue;
  late _RecordingPipeline pipeline;
  late MediaStoreWorker worker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('worker_wakeup');
    queue = MediaTransferQueueRepository(database: cacheDb);
    pipeline = _RecordingPipeline(
      queueRef: queue,
      mediaRepository: mediaRepository,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    worker = MediaStoreWorker(queue: queue, pipeline: pipeline);
  });

  tearDown(() async {
    // Dispose first: a wakeup that fires after the databases close would
    // drain against a closed connection.
    worker.dispose();
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  test('a drain with nothing deferred arms no wakeup', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    await worker.drain();
    expect(pipeline.processed, ['m1']);
    expect(worker.wakeupDelayForTesting, isNull);
  });

  test('drain arms a wakeup for the soonest deferred row', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.defer(id, DateTime.now().add(const Duration(hours: 25)));

    await worker.drain();

    expect(pipeline.processed, isEmpty, reason: 'row is not due yet');
    final armed = worker.wakeupDelayForTesting;
    expect(armed, isNotNull);
    // Within a minute of 25h: the exact value depends on wall clock drift
    // between defer() and the drain.
    expect(armed!.inMinutes, closeTo(25 * 60, 1));
  });

  // The regression this fixes: before the wakeup existed, a row deferred by
  // markFailed's multi-hour retryAfter sat untouched for the whole session.
  // Only an unrelated event (app restart, connectivity flap) ever picked it
  // up, so the settings page count stayed stale indefinitely.
  test('the armed wakeup re-drains once the backoff expires', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.defer(id, DateTime.now().add(const Duration(milliseconds: 80)));

    await worker.drain();
    expect(pipeline.processed, isEmpty, reason: 'not due at drain time');

    expect(
      await _waitFor(() => pipeline.processed.isNotEmpty),
      isTrue,
      reason: 'wakeup timer should have re-drained the row',
    );
    expect(pipeline.processed, ['m1']);
  });

  // #1210: the drain checks "what is due?" at T0 and the arming query checks
  // "what is not yet due?" at T1. A row that comes due in between satisfies
  // neither, so before the fix nothing was armed for it and it sat until an
  // unrelated trigger (app restart, connectivity flap) happened along.
  test(
    'a row that comes due while the drain finishes still gets a wakeup',
    () async {
      final lagging = _LaggingQueue(
        database: cacheDb,
        lag: const Duration(milliseconds: 400),
      );
      final laggingPipeline = _RecordingPipeline(
        queueRef: lagging,
        mediaRepository: mediaRepository,
        queue: lagging,
        store: InMemoryMediaObjectStore(),
        registry: MediaSourceResolverRegistry({}),
        cache: MediaCacheStore(database: cacheDb, root: root),
      );
      final laggingWorker = MediaStoreWorker(
        queue: lagging,
        pipeline: laggingPipeline,
      );
      addTearDown(laggingWorker.dispose);

      final id = await lagging.enqueueUpload(mediaId: 'm1');
      await lagging.defer(
        id,
        DateTime.now().add(const Duration(milliseconds: 80)),
      );

      await laggingWorker.drain();
      expect(
        laggingPipeline.processed,
        isEmpty,
        reason: 'not due at drain time',
      );

      expect(
        await _waitFor(() => laggingPipeline.processed.isNotEmpty),
        isTrue,
        reason: 'the row came due during the drain and must still be picked up',
      );
    },
  );

  // The constraint the immediate wakeup must not break: a drain that declined
  // to run leaves its due row behind on purpose, and arming a timer for it
  // would spin that timer against a drain that keeps declining.
  test('a preflight-suspended drain arms no wakeup for a due row', () async {
    final suspended = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => false,
    );
    addTearDown(suspended.dispose);
    await queue.enqueueUpload(mediaId: 'm1');

    await suspended.drain();

    expect(suspended.wakeupDelayForTesting, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(pipeline.processed, isEmpty, reason: 'no timer should have fired');
  });

  test('a gate-stopped drain arms no wakeup for a due row', () async {
    final stopped = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      gate: (_) async => WorkerGate.stopDraining,
    );
    addTearDown(stopped.dispose);
    await queue.enqueueUpload(mediaId: 'm1');

    await stopped.drain();

    expect(stopped.wakeupDelayForTesting, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(pipeline.processed, isEmpty, reason: 'no timer should have fired');
  });

  test(
    'a later drain replaces the armed wakeup rather than stacking',
    () async {
      final id = await queue.enqueueUpload(mediaId: 'm1');
      await queue.defer(id, DateTime.now().add(const Duration(hours: 25)));
      await worker.drain();
      final first = worker.wakeupDelayForTesting;

      await queue.defer(id, DateTime.now().add(const Duration(minutes: 10)));
      await worker.drain();

      expect(first!.inMinutes, closeTo(25 * 60, 1));
      expect(worker.wakeupDelayForTesting!.inMinutes, closeTo(10, 1));
    },
  );

  test('dispose cancels the armed wakeup', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.defer(id, DateTime.now().add(const Duration(milliseconds: 80)));
    await worker.drain();

    worker.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(pipeline.processed, isEmpty);
    expect(worker.wakeupDelayForTesting, isNull);
  });

  // A runtime rebuild disposes this worker without cancelling a drain it
  // already started - that invariant predates the wakeup. So dispose can
  // land mid-drain, and the drain's finally would then arm a fresh timer
  // AFTER disposal, leaving a superseded worker re-draining forever behind
  // the runtime that replaced it.
  test('dispose during an in-flight drain does not re-arm a wakeup', () async {
    await queue.enqueueUpload(mediaId: 'due');
    final parked = await queue.enqueueUpload(mediaId: 'parked');
    await queue.defer(parked, DateTime.now().add(const Duration(minutes: 10)));
    pipeline.gate = Completer<void>();

    final draining = worker.drain();
    expect(
      await _waitFor(() => pipeline.processed.isNotEmpty),
      isTrue,
      reason: 'the drain should be parked inside process()',
    );

    worker.dispose();
    pipeline.gate!.complete();
    await draining;

    expect(
      worker.wakeupDelayForTesting,
      isNull,
      reason: 'a disposed worker must not arm a wakeup on drain completion',
    );
  });

  test('a disposed worker refuses to start a new drain', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    worker.dispose();

    await worker.drain();

    expect(pipeline.processed, isEmpty);
    expect(worker.wakeupDelayForTesting, isNull);
  });
}
