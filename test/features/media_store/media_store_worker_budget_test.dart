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
      preflight: () => Completer<bool>().future,
      preflightBudget: budget,
    );
    addTearDown(worker.dispose);

    await expectLater(worker.drain(), completes);
    expect(pipeline.processed, isEmpty);
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
