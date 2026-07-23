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

class _RecordingDeleteProcessor extends MediaDeleteProcessor {
  _RecordingDeleteProcessor({
    required this.queueRef,
    required super.queue,
    required super.store,
    required super.mediaRepository,
  });

  final MediaTransferQueueRepository queueRef;
  final processed = <int>[];

  @override
  Future<void> process(MediaTransferQueueEntry entry) async {
    processed.add(entry.id);
    await queueRef.markDone(entry.id);
  }
}

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaTransferQueueRepository queue;
  late _RecordingPipeline pipeline;
  late _RecordingDeleteProcessor deleteProcessor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('worker_delete');
    store = InMemoryMediaObjectStore();
    queue = MediaTransferQueueRepository(database: cacheDb);
    pipeline = _RecordingPipeline(
      queueRef: queue,
      mediaRepository: mediaRepository,
      queue: queue,
      store: store,
      registry: MediaSourceResolverRegistry({}),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    deleteProcessor = _RecordingDeleteProcessor(
      queueRef: queue,
      queue: queue,
      store: store,
      mediaRepository: mediaRepository,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  test('drain routes delete entries to the delete processor', () async {
    final deleteId = await queue.enqueueDelete(
      mediaId: 'dead',
      contentHash: 'aa',
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    await queue.enqueueUpload(mediaId: 'alive');

    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      deleteProcessor: deleteProcessor,
    );
    await worker.drain();

    expect(deleteProcessor.processed, [deleteId]);
    expect(pipeline.processed, ['alive']);
  });

  test('delete entries are deferred when no delete processor is wired',
      () async {
    await queue.enqueueDelete(
      mediaId: 'dead',
      contentHash: 'aa',
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    final worker = MediaStoreWorker(queue: queue, pipeline: pipeline);
    await worker.drain(); // must terminate, not spin

    final row = (await queue.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.nextAttemptAt, isNotNull); // parked in the defer window
    expect(pipeline.processed, isEmpty);
  });
}
