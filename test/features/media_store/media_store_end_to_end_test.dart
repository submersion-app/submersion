import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';
import '../media_store/support/fake_local_file_resolver.dart';

/// Phase 1 exit criterion (design spec section 17): a photo attached on
/// device A displays on device B through the store. The shared
/// InMemoryMediaObjectStore plays the bucket; device B gets a fresh cache
/// and no access to A's files.
void main() {
  late Directory rootA;
  late Directory rootB;
  late LocalCacheDatabase cacheDbA;
  late LocalCacheDatabase cacheDbB;
  late InMemoryMediaObjectStore bucket;

  setUp(() async {
    await setUpTestDatabase();
    rootA = await Directory.systemTemp.createTemp('e2e_device_a');
    rootB = await Directory.systemTemp.createTemp('e2e_device_b');
    cacheDbA = LocalCacheDatabase(NativeDatabase.memory());
    cacheDbB = LocalCacheDatabase(NativeDatabase.memory());
    bucket = InMemoryMediaObjectStore();
  });

  tearDown(() async {
    await cacheDbA.close();
    await cacheDbB.close();
    await rootA.delete(recursive: true);
    await rootB.delete(recursive: true);
    await tearDownTestDatabase();
  });

  test('device A uploads on attach; device B resolves via the store', () async {
    // Device A.
    final mediaRepositoryA = MediaRepository();
    final cacheA = MediaCacheStore(database: cacheDbA, root: rootA);
    final queueA = MediaTransferQueueRepository(database: cacheDbA);
    final resolverA = FakeLocalFileResolver();
    final workerA = MediaStoreWorker(
      queue: queueA,
      pipeline: MediaUploadPipeline(
        mediaRepository: mediaRepositoryA,
        queue: queueA,
        store: bucket,
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: resolverA,
        }),
        cache: cacheA,
      ),
    );

    final photo = File('${rootA.path}/reef.jpg')
      ..writeAsBytesSync(List<int>.generate(2048, (i) => (i * 7) % 251));
    resolverA.data = FileData(file: photo);

    final created = await mediaRepositoryA.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: photo.path,
        localPath: photo.path,
        originalFilename: 'reef.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    );
    // enqueueAndKick's background drain is nondeterministic in a test;
    // enqueue directly and await one full drain.
    await queueA.enqueueUpload(mediaId: created.id);
    await workerA.drain();

    final uploaded = (await mediaRepositoryA.getMediaById(created.id))!;
    expect(uploaded.remoteUploadedAt, isNotNull);
    expect(uploaded.contentHash, isNotNull);
    expect(bucket.objects, isNotEmpty);

    // "Sync" ships the row values to device B; B cannot reach A's file or
    // gallery, so its pointers are dead there.
    final onB = uploaded.copyWith(
      platformAssetId: null,
      localPath: '/nonexistent/on/device-b.jpg',
    );

    // Device B: store fallback must produce the identical bytes.
    final cacheB = MediaCacheStore(database: cacheDbB, root: rootB);
    final resolverB = MediaStoreResolver(store: bucket, cache: cacheB);
    final data = await resolverB.tryResolveRemote(onB, thumbnail: false);
    expect(data, isA<FileData>());
    expect(
      await (data! as FileData).file.readAsBytes(),
      await photo.readAsBytes(),
    );
  });

  test('marker mismatch suspends the drain', () async {
    final mediaRepository = MediaRepository();
    final cache = MediaCacheStore(database: cacheDbA, root: rootA);
    final queue = MediaTransferQueueRepository(database: cacheDbA);
    final resolver = FakeLocalFileResolver();
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: queue,
        store: bucket,
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: resolver,
        }),
        cache: cache,
      ),
      // The bucket's marker no longer matches this device's attach state.
      preflight: () async => false,
    );

    final photo = File('${rootA.path}/wreck.jpg')..writeAsBytesSync([1, 2]);
    resolver.data = FileData(file: photo);
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: photo.path,
        localPath: photo.path,
        originalFilename: 'wreck.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    );
    await queue.enqueueUpload(mediaId: created.id);
    await worker.drain();

    expect(bucket.objects, isEmpty);
    expect((await queue.allForTesting()).single.state, 'pending');
    expect(
      (await mediaRepository.getMediaById(created.id))!.remoteUploadedAt,
      isNull,
    );
  });

  test('gate deferEntry postpones the entry without consuming attempts and '
      'stopDraining halts the queue', () async {
    final mediaRepository = MediaRepository();
    final cache = MediaCacheStore(database: cacheDbA, root: rootA);
    final queue = MediaTransferQueueRepository(database: cacheDbA);
    final resolver = FakeLocalFileResolver();
    final photo = File('${rootA.path}/gate.jpg')..writeAsBytesSync([7]);
    resolver.data = FileData(file: photo);
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: photo.path,
        localPath: photo.path,
        originalFilename: 'gate.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    );
    await queue.enqueueUpload(mediaId: created.id);

    var gateResult = WorkerGate.deferEntry;
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: queue,
        store: bucket,
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: resolver,
        }),
        cache: cache,
      ),
      gate: (entry) async => gateResult,
    );

    await worker.drain();
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.nextAttemptAt, isNotNull, reason: 'deferred, not failed');
    expect(bucket.objects, isEmpty);

    gateResult = WorkerGate.stopDraining;
    await worker.drain();
    expect(bucket.objects, isEmpty);
  });

  test('device B grid resolves the thumb object, not the original', () async {
    // Device A uploads a real (decodable) photo so a thumb is produced.
    final mediaRepositoryA = MediaRepository();
    final cacheA = MediaCacheStore(database: cacheDbA, root: rootA);
    final queueA = MediaTransferQueueRepository(database: cacheDbA);
    final resolverA = FakeLocalFileResolver();
    final workerA = MediaStoreWorker(
      queue: queueA,
      pipeline: MediaUploadPipeline(
        mediaRepository: mediaRepositoryA,
        queue: queueA,
        store: bucket,
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: resolverA,
        }),
        cache: cacheA,
      ),
    );

    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
      'qz8AAAAASUVORK5CYII=',
    );
    final photo = File('${rootA.path}/reef.png')..writeAsBytesSync(pngBytes);
    resolverA.data = FileData(file: photo);

    final created = await mediaRepositoryA.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: photo.path,
        localPath: photo.path,
        originalFilename: 'reef.png',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    );
    await queueA.enqueueUpload(mediaId: created.id);
    await workerA.drain();

    final uploaded = (await mediaRepositoryA.getMediaById(created.id))!;
    expect(uploaded.remoteThumbUploadedAt, isNotNull);
    expect(uploaded.remoteUploadedAt, isNotNull);
    expect(bucket.objects, hasLength(2), reason: 'thumb + original');

    // Device B resolves a THUMBNAIL: it must come from the thumb object.
    final onB = uploaded.copyWith(
      platformAssetId: null,
      localPath: '/nonexistent/on/device-b.png',
    );
    final cacheB = MediaCacheStore(database: cacheDbB, root: rootB);
    final resolverB = MediaStoreResolver(store: bucket, cache: cacheB);
    final data = await resolverB.tryResolveRemote(onB, thumbnail: true);
    expect(data, isA<FileData>());
    final thumbBytes = await (data! as FileData).file.readAsBytes();
    expect(thumbBytes.take(2).toList(), [0xFF, 0xD8], reason: 'JPEG thumb');
    expect(thumbBytes, isNot(equals(pngBytes)));
    expect(
      await cacheB.get(uploaded.contentHash!, MediaCacheKind.thumb),
      isNotNull,
    );
    expect(
      await cacheB.get(uploaded.contentHash!, MediaCacheKind.original),
      isNull,
      reason: 'grids never pull originals',
    );
  });
}
