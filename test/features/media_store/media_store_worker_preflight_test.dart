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
          return true;
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
}
