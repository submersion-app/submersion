import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

class _FakeLocalFileResolver implements MediaSourceResolver {
  _FakeLocalFileResolver(this.data);

  MediaSourceData data;

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
  }) async => data;

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

  Future<File> fixture(List<int> bytes, String name) async {
    final f = File('${root.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<String> enqueueLocalFileItem({
    required List<int> bytes,
    required String name,
    domain.MediaType mediaType = domain.MediaType.photo,
  }) async {
    final file = await fixture(bytes, name);
    resolver.data = FileData(file: file);
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

  test('video rows are ineligible until Phase 3', () async {
    await enqueueLocalFileItem(
      bytes: [3, 3],
      name: 'clip.mp4',
      mediaType: domain.MediaType.video,
    );
    final entry = (await queue.nextPending(DateTime.now()))!;
    expect(await pipeline.process(entry), UploadOutcome.skippedIneligible);
    expect(fakeStore.objects, isEmpty);
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
}
