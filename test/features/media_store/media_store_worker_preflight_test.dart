import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';
import '../../helpers/wait_until.dart';

const _mismatch = MediaTransferHoldKind.markerMismatch;

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

  @override
  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    processed.add(entry.mediaId);
    await queueRef.markDone(entry.id);
    return UploadOutcome.uploaded;
  }
}

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late MediaTransferQueueRepository queue;
  late _RecordingPipeline pipeline;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('worker_preflight');
    queue = MediaTransferQueueRepository(database: cacheDb);
    pipeline = _RecordingPipeline(
      queueRef: queue,
      mediaRepository: mediaRepository,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
  });

  tearDown(() async {
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  // Issue #942: preflight reads smv1/store.json from the bucket, so a network
  // blip throws. Every drain() call site is unawaited, so the throw escaped
  // into nothing and surfaced as "Uncaught zone error" - 25 of them in the
  // reporter's log. Preflight's contract is to suspend the drain; a failure to
  // determine the answer must suspend it too, not crash the zone.
  test(
    'a preflight that throws suspends the drain instead of escaping',
    () async {
      await queue.enqueueUpload(mediaId: 'm1');
      final worker = MediaStoreWorker(
        queue: queue,
        pipeline: pipeline,
        preflight: () async => throw const MediaStoreException(
          'get smv1/store.json failed: Could not reach S3 endpoint',
          kind: MediaStoreErrorKind.transient,
        ),
      );
      addTearDown(worker.dispose);

      await expectLater(worker.drain(), completes);
      expect(pipeline.processed, isEmpty);
    },
  );

  // Catching the throw is what removes the stack trace that used to reach the
  // zone handler, so this log line is now the only record of a preflight that
  // keeps failing. It must carry the cause through LoggerService's structured
  // error field (rendered as "| error: ..."), not interpolated into the text.
  test('the suspended drain logs the cause as a structured error', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => throw const MediaStoreException(
        'get smv1/store.json failed: Could not reach S3 endpoint',
        kind: MediaStoreErrorKind.transient,
      ),
    );
    addTearDown(worker.dispose);

    final entries = <LogEntry>[];
    final sub = LoggerService.logStream.listen(entries.add);
    addTearDown(sub.cancel);

    await worker.drain();

    expect(
      entries.map((e) => e.message),
      contains(
        allOf(
          contains('drain suspended'),
          contains('| error: MediaStoreException(transient)'),
          contains('smv1/store.json'),
        ),
      ),
    );
  });

  test(
    'a drain suspended by a throwing preflight can run again later',
    () async {
      await queue.enqueueUpload(mediaId: 'm1');
      var online = false;
      final worker = MediaStoreWorker(
        queue: queue,
        pipeline: pipeline,
        preflight: () async {
          if (!online) {
            throw const MediaStoreException(
              'get smv1/store.json failed: Could not reach S3 endpoint',
              kind: MediaStoreErrorKind.transient,
            );
          }
          return null;
        },
      );
      addTearDown(worker.dispose);

      await worker.drain();
      expect(pipeline.processed, isEmpty);

      online = true;
      await worker.drain();
      expect(pipeline.processed, ['m1']);
    },
  );

  // Issue #1356: a failed preflight left every due row untouched and armed
  // no wakeup (earliestPendingWakeup ignores due rows), so the queue sat at
  // "Waiting" until an external trigger re-ran the same failing check.
  test('a suspended drain arms a retry so the queue recovers without an '
      'external kick', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    var verified = false;
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => verified ? null : _mismatch,
      preflightRetryWindow: const Duration(milliseconds: 20),
    );
    addTearDown(worker.dispose);

    await worker.drain();
    expect(pipeline.processed, isEmpty);
    expect(worker.wakeupDelayForTesting, const Duration(milliseconds: 20));

    verified = true;
    await waitUntil(() async => pipeline.processed.contains('m1'));
  });

  // A suspension clears only from inside a passing preflight, so a drain
  // that armed nothing could never clear one. The loop checks the preflight
  // before asking what is due, so the last iteration of an emptying drain is
  // exactly where a suspension with an empty queue comes from.
  test('a suspended drain retries even with nothing queued', () async {
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => _mismatch,
    );
    addTearDown(worker.dispose);

    await worker.drain();
    expect(
      worker.wakeupDelayForTesting,
      MediaStoreWorker.defaultPreflightRetryWindow,
    );
  });

  // The timer this branch replaced. A row deferred for thirty seconds must
  // not wait out the retry window because an unrelated check failed.
  test('a suspended drain never delays a row past its own backoff', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.defer(id, DateTime.now().add(const Duration(seconds: 30)));
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => _mismatch,
    );
    addTearDown(worker.dispose);

    await worker.drain();
    expect(
      worker.wakeupDelayForTesting,
      lessThan(MediaStoreWorker.defaultPreflightRetryWindow),
    );
  });

  test('the suspension is observable and clears once the preflight '
      'passes', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    var verified = false;
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => verified ? null : _mismatch,
    );
    addTearDown(worker.dispose);
    final seen = <bool>[];
    final sub = worker.suspensionChanges.listen(seen.add);
    addTearDown(sub.cancel);

    expect(worker.isSuspended, isFalse);
    await worker.drain();
    expect(worker.isSuspended, isTrue);

    verified = true;
    await worker.drain();
    expect(worker.isSuspended, isFalse);
    expect(pipeline.processed, ['m1']);
    await Future<void>.delayed(Duration.zero);
    expect(
      seen,
      [false, true, false],
      reason:
          'the stream opens with the value at subscribe time, so a '
          'reader can never miss a flip it arrived just after',
    );
  });

  // Being offline lands here on every provider: the marker read goes to the
  // network and drain() runs the preflight BEFORE the gate that owns
  // offline. Reporting that as a suspension told the user their store could
  // not be verified, over a store that was fine.
  test('a preflight that throws while offline holds quietly', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => throw const MediaStoreException(
        'Could not reach S3 endpoint',
        kind: MediaStoreErrorKind.transient,
      ),
      isOffline: () async => true,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(pipeline.processed, isEmpty);
    expect(worker.isSuspended, isFalse);
    expect(
      queue.currentHold?.kind,
      MediaTransferHoldKind.offline,
      reason: 'quiet is not silent: the queue still says why',
    );
  });

  // Online, a throw means the store itself could not be checked. That is
  // the user's to know (spec 7.1), with the error as the reason.
  test('a preflight that throws while online suspends with its '
      'reason', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => throw const MediaStoreException(
        'get smv1/store.json failed: 503',
        kind: MediaStoreErrorKind.transient,
      ),
      isOffline: () async => false,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(worker.isSuspended, isTrue);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.storeUnreachable);
    expect(queue.currentHold?.message, contains('smv1/store.json'));
  });

  // Could not tell is not the same as offline: the reason then shows, the
  // safer mistake of the two.
  test('an offline check that throws reads as online', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => throw StateError('marker unreadable'),
      isOffline: () async => throw StateError('no connectivity plugin'),
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(worker.isSuspended, isTrue);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.storeUnreachable);
  });

  test('a refusal suspends and names its kind', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => MediaTransferHoldKind.detached,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(worker.isSuspended, isTrue);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.detached);
  });

  test('a preflight that passes clears the hold', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    MediaTransferHoldKind? verdict = _mismatch;
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => verdict,
    );
    addTearDown(worker.dispose);

    await worker.drain();
    expect(queue.currentHold?.kind, _mismatch);

    verdict = null;
    await worker.drain();

    expect(worker.isSuspended, isFalse);
    expect(queue.currentHold, isNull);
  });

  test('a gate that stops for offline records an offline hold', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      gate: (_) async => WorkerGate.stopDraining,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(pipeline.processed, isEmpty);
    expect(worker.isSuspended, isFalse);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.offline);
  });

  // The production gate reads connectivity and policies, and any of them can
  // throw. The drain must not end silently with a due row and no retry: it
  // holds, says why, and arms the retry window like any failed admission.
  test('a gate that throws holds and arms a retry', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      gate: (_) async => throw StateError('policy read failed'),
      isOffline: () async => false,
      preflightRetryWindow: const Duration(minutes: 7),
    );
    addTearDown(worker.dispose);

    await expectLater(worker.drain(), completes);

    expect(pipeline.processed, isEmpty);
    expect(worker.wakeupDelayForTesting, const Duration(minutes: 7));
    expect(queue.currentHold?.message, contains('policy read failed'));
    expect(
      await queue.nextPending(DateTime.now()),
      isNotNull,
      reason: 'the claim went back, so the retry can take the row',
    );
  });

  test('a gate that throws while offline holds quietly', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      gate: (_) async => throw StateError('no connectivity plugin'),
      isOffline: () async => true,
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(worker.isSuspended, isFalse);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.offline);
  });

  // The drain claims a row before the gate sees it. A claim the gate turns
  // away must go back, or no later drain could select the row.
  test('a row the gate stops for is taken by a later drain', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    var gate = WorkerGate.stopDraining;
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      gate: (_) async => gate,
    );
    addTearDown(worker.dispose);

    await worker.drain();
    gate = WorkerGate.proceed;
    await worker.drain();

    expect(pipeline.processed, ['m1']);
  });

  // A disconnect disposes the runtime and builds none in its place, so a
  // hold left standing would name a store this device no longer uses.
  test('dispose clears the hold it recorded', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => _mismatch,
    );

    await worker.drain();
    worker.dispose();

    expect(queue.currentHold, isNull);
  });

  // The hold is shared by every worker over one database. A worker disposed
  // after its replacement recorded a reason must leave that reason alone.
  test('dispose leaves a hold its replacement recorded', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final superseded = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async => _mismatch,
    );
    final replacement = MediaStoreWorker(
      queue: MediaTransferQueueRepository(database: cacheDb),
      pipeline: pipeline,
      preflight: () async => MediaTransferHoldKind.detached,
    );
    addTearDown(replacement.dispose);

    await superseded.drain();
    await replacement.drain();
    superseded.dispose();

    expect(queue.currentHold?.kind, MediaTransferHoldKind.detached);
  });

  // Dispose does not stop a drain already running, and the hold is shared
  // with the worker that replaced this one.
  test('a superseded drain does not record a hold after dispose', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final answer = Completer<MediaTransferHoldKind?>();
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () => answer.future,
    );

    final drain = worker.drain();
    await pumpEventQueue();
    worker.dispose();
    answer.complete(_mismatch);
    await drain;

    expect(queue.currentHold, isNull);
  });

  // Scheduling and the UI signal are separate concerns. A preflight that
  // could not answer must not accuse the store, but it still leaves due rows
  // with nothing to pick them up: earliestPendingWakeup ignores due rows, so
  // without this the offline case reproduced the stall this PR exists to fix.
  test('a drain blocked by a thrown preflight still arms a retry', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    var offline = true;
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async {
        if (offline) {
          throw const MediaStoreException(
            'Could not reach S3 endpoint',
            kind: MediaStoreErrorKind.transient,
          );
        }
        return null;
      },
      isOffline: () async => offline,
      preflightRetryWindow: const Duration(milliseconds: 20),
    );
    addTearDown(worker.dispose);

    await worker.drain();

    expect(worker.isSuspended, isFalse, reason: 'the store is not at fault');
    expect(worker.wakeupDelayForTesting, const Duration(milliseconds: 20));

    offline = false;
    await waitUntil(() async => pipeline.processed.contains('m1'));
  });
}
