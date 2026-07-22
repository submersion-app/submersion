import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'support/fake_local_file_resolver.dart';
import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore fakeStore;
  late MediaCacheStore cache;
  late MediaTransferQueueRepository queue;
  late FakeLocalFileResolver resolver;
  late MediaUploadPipeline pipeline;
  late MediaStoreWorker worker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('worker_reclaim');
    fakeStore = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: cacheDb, root: root);
    queue = MediaTransferQueueRepository(database: cacheDb);
    resolver = FakeLocalFileResolver();
    final registry = MediaSourceResolverRegistry({
      MediaSourceType.localFile: resolver,
    });
    pipeline = MediaUploadPipeline(
      mediaRepository: mediaRepository,
      queue: queue,
      store: fakeStore,
      registry: registry,
      cache: cache,
      now: () => DateTime(2026, 7, 20, 12),
    );
    worker = MediaStoreWorker(queue: queue, pipeline: pipeline);
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  test('a reclaimed orphan row drains to done end-to-end', () async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(
      img.encodePng(img.Image(width: 4000, height: 3000)),
      flush: true,
    );
    resolver.data = FileData(file: f);
    await mediaRepository.createMedia(
      MediaItem(
        id: 'm1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        originalFilename: 'shot.png',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    // Simulate a previous drain interrupted mid-upload: the row is stranded
    // in 'transferring' and is invisible to nextPending forever.
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.markTransferring(id);
    expect(await queue.nextPending(DateTime.now()), isNull);

    // Recovery path: the once-per-process reclaim returns the orphan to
    // 'pending', then the worker drains it to completion.
    await queue.requeueStale();
    await worker.drain();

    final got = await mediaRepository.getMediaById('m1');
    expect(got!.remoteUploadedAt, isNotNull);
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'done');
  });
}
