import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';

import 'package:submersion/core/services/media_store/media_object_store.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

/// A store whose original-object uploads always fail, to drive the
/// pipeline's failure branch (thumb uploads are best-effort and swallowed).
class _PutThrowsStore extends InMemoryMediaObjectStore {
  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) async {
    throw const MediaStoreException('boom', kind: MediaStoreErrorKind.fatal);
  }
}

class _FakeLocalFileResolver implements MediaSourceResolver {
  _FakeLocalFileResolver(this.data);

  MediaSourceData data;

  /// When set, resolveThumbnail serves this instead of [data] (models the
  /// gallery resolver's pre-compressed poster bytes for videos).
  MediaSourceData? thumbnailData;

  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(domain.MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(domain.MediaItem item) async => data;

  @override
  Future<MediaSourceData> resolveThumbnail(
    domain.MediaItem item, {
    required Size target,
  }) async => thumbnailData ?? data;

  @override
  Future<MediaSourceMetadata?> extractMetadata(domain.MediaItem item) async =>
      null;

  @override
  Future<VerifyResult> verify(domain.MediaItem item) async =>
      VerifyResult.available;
}

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore fakeStore;
  late MediaCacheStore cache;
  late MediaTransferQueueRepository queue;
  late _FakeLocalFileResolver resolver;
  late MediaUploadPipeline pipeline;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('pipeline_test');
    fakeStore = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: cacheDb, root: root);
    queue = MediaTransferQueueRepository(database: cacheDb);
    resolver = _FakeLocalFileResolver(
      const UnavailableData(kind: UnavailableKind.notFound),
    );
    final registry = MediaSourceResolverRegistry({
      MediaSourceType.localFile: resolver,
    });
    pipeline = MediaUploadPipeline(
      mediaRepository: mediaRepository,
      queue: queue,
      store: fakeStore,
      registry: registry,
      cache: cache,
      thumbnails: ThumbnailGenerator(registry: registry, cache: cache),
      now: () => DateTime(2026, 7, 10, 12),
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  List<int> pngBytes() => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
    'qz8AAAAASUVORK5CYII=',
  );

  Future<File> fixture(List<int> bytes, String name) async {
    final f = File('${root.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<String> enqueueLocalFileItem({
    required List<int> bytes,
    required String name,
    domain.MediaType mediaType = domain.MediaType.photo,
    MediaSourceData? thumbnailData,
  }) async {
    final file = await fixture(bytes, name);
    resolver.data = FileData(file: file);
    resolver.thumbnailData = thumbnailData;
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: mediaType,
        sourceType: MediaSourceType.localFile,
        filePath: file.path,
        localPath: file.path,
        originalFilename: name,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await queue.enqueueUpload(mediaId: created.id);
    return created.id;
  }

  test('happy path uploads bytes at the content key and stamps the '
      'row', () async {
    final id = await enqueueLocalFileItem(bytes: [1, 2, 3], name: 'a.jpg');
    final entry = (await queue.nextPending(DateTime.now()))!;
    final outcome = await pipeline.process(entry);
    expect(outcome, UploadOutcome.uploaded);

    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.contentHash, isNotNull);
    expect(item.contentSizeBytes, 3);
    expect(item.remoteUploadedAt, DateTime(2026, 7, 10, 12));
    final key =
        'smv1/objects/${item.contentHash!.substring(0, 2)}/'
        '${item.contentHash}.jpg';
    expect(fakeStore.objects[key], [1, 2, 3]);
    expect((await queue.allForTesting()).single.state, 'done');
  });

  test('a row synced with the right hash but no size still gets its size '
      'stamped', () async {
    final bytes = [9, 8, 7, 6, 5];
    final seed = await fixture(bytes, 'synced.jpg');
    final digest = await sha256OfFile(seed);
    resolver.data = FileData(file: seed);

    // Models a row synced from another device: hash already correct,
    // contentSizeBytes never stamped locally.
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: seed.path,
        localPath: seed.path,
        originalFilename: 'synced.jpg',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        contentHash: digest.hash,
      ),
    );
    expect(
      (await mediaRepository.getMediaById(created.id))!.contentSizeBytes,
      isNull,
    );

    await queue.enqueueUpload(mediaId: created.id);
    final entry = (await queue.nextPending(DateTime.now()))!;
    await pipeline.process(entry);

    final item = (await mediaRepository.getMediaById(created.id))!;
    expect(item.contentSizeBytes, bytes.length);
    expect(item.contentHash, digest.hash);
  });

  test('dedup: existing object skips the put but still confirms', () async {
    final bytes = [4, 5, 6, 7];
    final seed = await fixture(bytes, 'seed.jpg');
    final digest = await sha256OfFile(seed);
    fakeStore.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] =
        bytes;

    final id = await enqueueLocalFileItem(bytes: bytes, name: 'b.jpg');
    final entry = (await queue.nextPending(DateTime.now()))!;
    final outcome = await pipeline.process(entry);

    expect(outcome, UploadOutcome.deduplicated);
    expect(fakeStore.objects, hasLength(1));
    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.contentHash, digest.hash);
    expect(item.remoteUploadedAt, isNotNull);
  });

  test('crash replay: re-processing an already-confirmed row is a no-op '
      'dedup', () async {
    final id = await enqueueLocalFileItem(bytes: [9, 9, 9], name: 'c.jpg');
    final first = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(first), UploadOutcome.uploaded);

    final again = await queue.enqueueUpload(mediaId: id);
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(entry.id, again);
    expect(await pipeline.process(entry), UploadOutcome.deduplicated);
    expect(fakeStore.objects, hasLength(1));
  });

  test('unavailable source marks failed with retry scheduling', () async {
    final id = await enqueueLocalFileItem(bytes: [1], name: 'd.jpg');
    resolver.data = const UnavailableData(kind: UnavailableKind.notFound);

    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.failed);

    final row = (await queue.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 1);
    expect(row.nextAttemptAt, isNotNull);
    expect(row.errorMessage, contains('unavailable'));
    expect(fakeStore.objects, isEmpty);
    expect((await mediaRepository.getMediaById(id))!.remoteUploadedAt, isNull);
  });

  test('thumb object uploads alongside the original and stamps '
      'remoteThumbUploadedAt', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
      'qz8AAAAASUVORK5CYII=',
    );
    final id = await enqueueLocalFileItem(bytes: png, name: 'a.png');
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);

    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteThumbUploadedAt, isNotNull);
    final thumbKey =
        'smv1/thumbs/${item.contentHash!.substring(0, 2)}/'
        '${item.contentHash}.jpg';
    expect(fakeStore.objects.containsKey(thumbKey), isTrue);
    expect(fakeStore.objects, hasLength(2));
  });

  test('thumb failure never blocks the original upload', () async {
    // Undecodable bytes: the resize path fails while the original path
    // still materializes and uploads.
    final id = await enqueueLocalFileItem(bytes: [1, 2, 3], name: 'a.jpg');
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);

    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteUploadedAt, isNotNull);
    expect(item.remoteThumbUploadedAt, isNull);
    expect(fakeStore.objects, hasLength(1));
  });

  test('video rows upload with contentType video/mp4', () async {
    final id = await enqueueLocalFileItem(
      bytes: List<int>.generate(1024, (i) => i % 251),
      name: 'clip.mp4',
      mediaType: domain.MediaType.video,
    );
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);
    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteUploadedAt, isNotNull);
    final key =
        'smv1/objects/${item.contentHash!.substring(0, 2)}/'
        '${item.contentHash}.mp4';
    expect(fakeStore.objects.containsKey(key), isTrue);
  });

  test('resume state and progress flow through the queue row', () async {
    final id = await enqueueLocalFileItem(bytes: [1, 2, 3, 4], name: 'r.jpg');
    final entry = (await queue.nextPending(DateTime.now()))!;
    fakeStore.emitResumeState = '{"fake":1}';
    expect(await pipeline.process(entry), UploadOutcome.uploaded);

    expect(
      fakeStore.lastResumeStateJsonIn,
      isNull,
      reason: 'first attempt starts with no resume state',
    );
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'done');
    expect(row.resumeStateJson, isNull, reason: 'markDone clears it');

    // A row carrying a pre-seeded resume state hands it to the store.
    fakeStore.emitResumeState = null;
    final id2 = await enqueueLocalFileItem(bytes: [9, 9], name: 'r2.jpg');
    final entry2 = (await queue.nextPending(DateTime.now()))!;
    await queue.updateResumeState(entry2.id, '{"seeded":true}');
    final refreshed = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(refreshed), UploadOutcome.uploaded);
    expect(fakeStore.lastResumeStateJsonIn, '{"seeded":true}');
    expect(
      (await mediaRepository.getMediaById(id2))!.remoteUploadedAt,
      isNotNull,
    );
    expect(id, isNot(id2));
  });

  test('gallery-style video thumbs upload (BytesData poster)', () async {
    final id = await enqueueLocalFileItem(
      bytes: List<int>.generate(2048, (i) => i % 251),
      name: 'dive.mp4',
      mediaType: domain.MediaType.video,
      thumbnailData: BytesData(bytes: Uint8List.fromList(pngBytes())),
    );
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.uploaded);
    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.remoteThumbUploadedAt, isNotNull);
    expect(
      fakeStore.objects.containsKey(
        'smv1/thumbs/${item.contentHash!.substring(0, 2)}/'
        '${item.contentHash}.jpg',
      ),
      isTrue,
    );
  });

  test('signature rows are ineligible and complete without store '
      'writes', () async {
    await enqueueLocalFileItem(
      bytes: [8, 8],
      name: 'sig.png',
      mediaType: domain.MediaType.instructorSignature,
    );
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.skippedIneligible);
    expect(fakeStore.objects, isEmpty);
    expect((await queue.allForTesting()).single.state, 'done');
  });

  test('a BytesData source is materialized and uploaded', () async {
    final id = await enqueueLocalFileItem(bytes: [1], name: 'bytes.jpg');
    // Override the resolved data with in-memory bytes (Android content-URI
    // style), which the pipeline stages to a temp file before hashing.
    resolver.data = BytesData(bytes: Uint8List.fromList([9, 8, 7, 6]));
    final entry = (await queue.nextPending(DateTime.now()))!;

    expect(await pipeline.process(entry), UploadOutcome.uploaded);
    final item = (await mediaRepository.getMediaById(id))!;
    expect(item.contentSizeBytes, 4);
    expect(item.remoteUploadedAt, isNotNull);
  });

  test('worker.enqueueAndKick enqueues the media and drains it', () async {
    final file = await fixture([1, 2, 3, 4], 'kick.jpg');
    resolver.data = FileData(file: file);
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: file.path,
        localPath: file.path,
        originalFilename: 'kick.jpg',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    final worker = MediaStoreWorker(queue: queue, pipeline: pipeline);

    await worker.enqueueAndKick(created.id);
    // enqueueAndKick fires the drain in the background. Await it to full
    // completion (including each entry's post-upload staging cleanup) so no
    // async work outlives the test and races teardown's temp-dir deletion --
    // that race surfaced as an intermittent "failed after test completion"
    // PathNotFoundException.
    await worker.activeDrain;
    expect(
      (await mediaRepository.getMediaById(created.id))!.remoteUploadedAt,
      isNotNull,
    );
  });

  test('an upload error marks the row failed with the error message', () async {
    final failingStore = _PutThrowsStore();
    final registry = MediaSourceResolverRegistry({
      MediaSourceType.localFile: resolver,
    });
    final failingPipeline = MediaUploadPipeline(
      mediaRepository: mediaRepository,
      queue: queue,
      store: failingStore,
      registry: registry,
      cache: cache,
      thumbnails: ThumbnailGenerator(registry: registry, cache: cache),
      now: () => DateTime(2026, 7, 10, 12),
    );

    await enqueueLocalFileItem(bytes: [1, 2, 3], name: 'fail.jpg');
    final entry = (await queue.nextPending(DateTime.now()))!;

    expect(await failingPipeline.process(entry), UploadOutcome.failed);
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'pending', reason: 'first failure retries, not terminal');
    expect(row.attempts, 1);
    expect(row.errorMessage, isNotNull);
    expect(failingStore.objects, isEmpty);
  });

  group('serviceConnector rows', () {
    late _FakeLocalFileResolver connectorResolver;
    late MediaUploadPipeline connectorPipeline;

    setUp(() {
      // Same fake shape, registered under serviceConnector: the pipeline
      // only cares that the registry materializes bytes for the type.
      connectorResolver = _FakeConnectorResolver(
        const UnavailableData(kind: UnavailableKind.notFound),
      );
      final registry = MediaSourceResolverRegistry({
        MediaSourceType.serviceConnector: connectorResolver,
      });
      connectorPipeline = MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: queue,
        store: fakeStore,
        registry: registry,
        cache: cache,
        thumbnails: ThumbnailGenerator(registry: registry, cache: cache),
        now: () => DateTime(2026, 7, 10, 12),
      );
    });

    // Connector renditions are JPEG regardless of the original's name.
    List<int> jpegRendition() => img.encodeJpg(img.Image(width: 2, height: 2));

    Future<String> enqueueConnectorItem({
      required domain.MediaType mediaType,
      required String name,
    }) async {
      connectorResolver.data = BytesData(
        bytes: Uint8List.fromList(jpegRendition()),
      );
      connectorResolver.thumbnailData = BytesData(
        bytes: Uint8List.fromList(jpegRendition()),
      );
      final created = await mediaRepository.createMedia(
        domain.MediaItem(
          id: '',
          mediaType: mediaType,
          sourceType: MediaSourceType.serviceConnector,
          connectorAccountId: 'acct1',
          remoteAssetId: 'lr-$name',
          originalFilename: name,
          takenAt: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      await queue.enqueueUpload(mediaId: created.id);
      return created.id;
    }

    test(
      'connector photo uploads rendition bytes and stamps the row',
      () async {
        final id = await enqueueConnectorItem(
          mediaType: domain.MediaType.photo,
          name: 'reef.jpg',
        );
        final entry = (await queue.nextPending(DateTime.now()))!;
        expect(await connectorPipeline.process(entry), UploadOutcome.uploaded);

        final item = (await mediaRepository.getMediaById(id))!;
        expect(item.contentHash, isNotNull);
        expect(item.remoteUploadedAt, isNotNull);
        expect(item.remoteThumbUploadedAt, isNotNull);
        final key =
            'smv1/objects/${item.contentHash!.substring(0, 2)}/'
            '${item.contentHash}.jpg';
        expect(fakeStore.objects[key], jpegRendition());
      },
    );

    test(
      'connector video is thumb-only: thumb stamped, no original object',
      () async {
        final id = await enqueueConnectorItem(
          mediaType: domain.MediaType.video,
          name: 'clip.mp4',
        );
        final entry = (await queue.nextPending(DateTime.now()))!;
        expect(await connectorPipeline.process(entry), UploadOutcome.uploaded);

        final item = (await mediaRepository.getMediaById(id))!;
        expect(item.contentHash, isNotNull);
        expect(item.remoteThumbUploadedAt, isNotNull);
        expect(
          item.remoteUploadedAt,
          isNull,
          reason: 'no original in the store means no upload confirmation',
        );
        expect(
          fakeStore.objects.keys,
          everyElement(startsWith('smv1/thumbs/')),
          reason: 'only the thumb object may exist for a connector video',
        );
        expect((await queue.allForTesting()).single.state, 'done');
      },
    );

    test('already thumb-stamped connector video short-circuits as '
        'deduplicated', () async {
      final id = await enqueueConnectorItem(
        mediaType: domain.MediaType.video,
        name: 'clip2.mp4',
      );
      final first = (await queue.nextPending(DateTime.now()))!;
      await connectorPipeline.process(first);

      await queue.enqueueUpload(mediaId: id);
      final second = (await queue.nextPending(DateTime.now()))!;
      expect(
        await connectorPipeline.process(second),
        UploadOutcome.deduplicated,
      );
    });
  });
}

/// The connector twin of [_FakeLocalFileResolver]; only the source type
/// differs.
class _FakeConnectorResolver extends _FakeLocalFileResolver {
  _FakeConnectorResolver(super.data);

  @override
  MediaSourceType get sourceType => MediaSourceType.serviceConnector;
}
