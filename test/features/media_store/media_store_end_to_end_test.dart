import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/media_store/dropbox_media_object_store.dart';
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

import '../../helpers/fake_dropbox_server.dart';
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
    SharedPreferences.setMockInitialValues({});
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

  test('preflight is re-checked between entries, so a mid-drain detach '
      'suspends the rest of the queue', () async {
    final mediaRepository = MediaRepository();
    final cache = MediaCacheStore(database: cacheDbA, root: rootA);
    final queue = MediaTransferQueueRepository(database: cacheDbA);
    final resolver = FakeLocalFileResolver();
    var preflightCalls = 0;
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
      // Valid for the first entry, then the store detaches (marker wiped
      // or the user disconnected) while the drain is still running.
      preflight: () async => ++preflightCalls <= 1,
    );

    final photo = File('${rootA.path}/two.jpg')..writeAsBytesSync([3, 4, 5]);
    resolver.data = FileData(file: photo);
    for (final name in ['two-a.jpg', 'two-b.jpg']) {
      final created = await mediaRepository.createMedia(
        domain.MediaItem(
          id: '',
          mediaType: domain.MediaType.photo,
          sourceType: MediaSourceType.localFile,
          filePath: photo.path,
          localPath: photo.path,
          originalFilename: name,
          takenAt: DateTime(2026, 7, 1),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      );
      await queue.enqueueUpload(mediaId: created.id);
    }

    await worker.drain();

    final rows = await queue.allForTesting();
    expect(rows.where((r) => r.state == 'done'), hasLength(1));
    expect(
      rows.where((r) => r.state == 'pending'),
      hasLength(1),
      reason: 'the second entry must stay queued, not process detached',
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

  test('a video uploaded on device A plays from the store on device '
      'B', () async {
    // Device A: gallery-sourced video with a BytesData poster thumb. The
    // gallery source matters: only platformGallery thumbnail bytes pass
    // through the generator untouched (file-sourced BytesData gets
    // re-encoded, and raw video bytes cannot be, so localFile videos get
    // no thumb until Phase 5).
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
          MediaSourceType.platformGallery: resolverA,
        }),
        cache: cacheA,
      ),
    );

    final videoBytes = List<int>.generate(64 * 1024, (i) => (i * 11) % 251);
    final video = File('${rootA.path}/dive.mp4')..writeAsBytesSync(videoBytes);
    resolverA.data = FileData(file: video);
    // Gallery posters are pre-compressed bytes the generator passes through
    // untouched (photo_manager emits JPEG in production; the format of the
    // fixture is irrelevant to the pipeline).
    final posterBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
      'qz8AAAAASUVORK5CYII=',
    );
    resolverA.thumbnailData = BytesData(bytes: posterBytes);

    final created = await mediaRepositoryA.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.video,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'gallery-video-1',
        filePath: video.path,
        localPath: video.path,
        originalFilename: 'dive.mp4',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    );
    await queueA.enqueueUpload(mediaId: created.id);
    await workerA.drain();

    final uploaded = (await mediaRepositoryA.getMediaById(created.id))!;
    expect(uploaded.remoteUploadedAt, isNotNull);
    expect(uploaded.remoteThumbUploadedAt, isNotNull);
    expect(bucket.objects, hasLength(2), reason: 'thumb + original');

    // Device B: the full video resolves byte-identical; the grid thumb is
    // a JPEG poster.
    final onB = uploaded.copyWith(
      platformAssetId: null,
      localPath: '/nonexistent/on/device-b.mp4',
    );
    final cacheB = MediaCacheStore(database: cacheDbB, root: rootB);
    final resolverB = MediaStoreResolver(store: bucket, cache: cacheB);

    final full = await resolverB.tryResolveRemote(onB, thumbnail: false);
    expect(full, isA<FileData>());
    expect(await (full! as FileData).file.readAsBytes(), videoBytes);

    final thumb = await resolverB.tryResolveRemote(onB, thumbnail: true);
    expect(thumb, isA<FileData>());
    final thumbBytes = await (thumb! as FileData).file.readAsBytes();
    expect(thumbBytes, posterBytes, reason: 'poster round-trips exactly');
    expect(thumbBytes, isNot(equals(videoBytes)));
  });

  test('the cross-device video flow works over the Dropbox adapter', () async {
    // Phase 4 exit criterion: the same video journey as the in-memory
    // test, but through the real Dropbox protocol adapter (upload
    // sessions on the way up, ranged downloads on the way back). Both
    // devices talk to one fake Dropbox account.
    final server = FakeDropboxServer();
    DropboxMediaObjectStore storeFor() => DropboxMediaObjectStore(
      client: DropboxApiClient(
        getAccessToken: () async => server.bearerToken,
        onAccessTokenRejected: () {},
        httpClient: server.client,
      ),
      // Well below the video size so the upload takes the session path.
      chunkSizeBytes: 16 * 1024,
    );

    final mediaRepositoryA = MediaRepository();
    final cacheA = MediaCacheStore(database: cacheDbA, root: rootA);
    final queueA = MediaTransferQueueRepository(database: cacheDbA);
    final resolverA = FakeLocalFileResolver();
    final workerA = MediaStoreWorker(
      queue: queueA,
      pipeline: MediaUploadPipeline(
        mediaRepository: mediaRepositoryA,
        queue: queueA,
        store: storeFor(),
        registry: MediaSourceResolverRegistry({
          MediaSourceType.platformGallery: resolverA,
        }),
        cache: cacheA,
      ),
    );

    final videoBytes = List<int>.generate(64 * 1024, (i) => (i * 13) % 251);
    final video = File('${rootA.path}/drift.mp4')..writeAsBytesSync(videoBytes);
    resolverA.data = FileData(file: video);
    final posterBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
      'qz8AAAAASUVORK5CYII=',
    );
    resolverA.thumbnailData = BytesData(bytes: posterBytes);

    final created = await mediaRepositoryA.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.video,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'gallery-video-2',
        filePath: video.path,
        localPath: video.path,
        originalFilename: 'drift.mp4',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    );
    await queueA.enqueueUpload(mediaId: created.id);
    await workerA.drain();

    final uploaded = (await mediaRepositoryA.getMediaById(created.id))!;
    expect(uploaded.remoteUploadedAt, isNotNull);
    expect(uploaded.remoteThumbUploadedAt, isNotNull);
    expect(server.files, hasLength(2), reason: 'thumb + original');

    // Device B holds only the synced row and its own Dropbox link.
    final onB = uploaded.copyWith(
      platformAssetId: null,
      localPath: '/nonexistent/on/device-b.mp4',
    );
    final cacheB = MediaCacheStore(database: cacheDbB, root: rootB);
    final resolverB = MediaStoreResolver(store: storeFor(), cache: cacheB);

    final full = await resolverB.tryResolveRemote(onB, thumbnail: false);
    expect(full, isA<FileData>());
    expect(await (full! as FileData).file.readAsBytes(), videoBytes);

    final thumb = await resolverB.tryResolveRemote(onB, thumbnail: true);
    expect(thumb, isA<FileData>());
    expect(await (thumb! as FileData).file.readAsBytes(), posterBytes);
  });
}
