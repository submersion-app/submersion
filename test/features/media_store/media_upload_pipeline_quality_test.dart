import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
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
  late MediaSourceResolverRegistry registry;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('pipeline_quality');
    fakeStore = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: cacheDb, root: root);
    queue = MediaTransferQueueRepository(database: cacheDb);
    resolver = FakeLocalFileResolver();
    registry = MediaSourceResolverRegistry({
      MediaSourceType.localFile: resolver,
    });
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  MediaItem photo(String id) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'shot.png',
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<File> bigPng() async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(
      img.encodePng(img.Image(width: 4000, height: 3000)),
      flush: true,
    );
    return f;
  }

  Future<MediaTransferQueueEntry> enqueue(String mediaId) async {
    final id = await queue.enqueueUpload(mediaId: mediaId);
    return (await queue.allForTesting()).firstWhere((e) => e.id == id);
  }

  test('a compressed photo uploads a rendition, not an original', () async {
    resolver.data = FileData(file: await bigPng());
    final policies = MediaStorePolicies(
      prefs: await SharedPreferences.getInstance(),
    );
    await policies.setPhotoUploadQuality(MediaUploadQuality.balanced);

    final pipeline = MediaUploadPipeline(
      mediaRepository: mediaRepository,
      queue: queue,
      store: fakeStore,
      registry: registry,
      cache: cache,
      policies: policies,
      now: () => DateTime(2026, 7, 20, 12),
    );

    await mediaRepository.createMedia(photo('m1'));
    final outcome = await pipeline.process(await enqueue('m1'));

    expect(outcome, UploadOutcome.uploaded);
    expect(
      fakeStore.objects.keys.any((k) => k.startsWith('smv1/renditions/')),
      isTrue,
    );
    expect(
      fakeStore.objects.keys.any((k) => k.startsWith('smv1/objects/')),
      isFalse,
    );
    final got = await mediaRepository.getMediaById('m1');
    expect(got!.remoteCompressedUploadedAt, isNotNull);
    expect(got.remoteUploadedAt, isNull);
    expect(got.compressedLevel, 'balanced');
  });

  test(
    'a deduped rendition records the stored size, not local bytes',
    () async {
      final policies = MediaStorePolicies(
        prefs: await SharedPreferences.getInstance(),
      );
      await policies.setPhotoUploadQuality(MediaUploadQuality.balanced);
      MediaUploadPipeline build() => MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: queue,
        store: fakeStore,
        registry: registry,
        cache: cache,
        policies: policies,
        now: () => DateTime(2026, 7, 20, 12),
      );

      // First writer uploads the rendition for these bytes.
      resolver.data = FileData(file: await bigPng());
      await mediaRepository.createMedia(photo('m1'));
      await build().process(await enqueue('m1'));
      final renditionKey = fakeStore.objects.keys.firstWhere(
        (k) => k.startsWith('smv1/renditions/'),
      );

      // Simulate the stored object differing from this device's local rendition
      // (renditions are not hash-verified and can vary by level/encoder).
      fakeStore.objects[renditionKey] = List<int>.filled(123456, 7);

      // A second item with identical source bytes hits the same rendition key
      // and dedups (skips putFile) -- it must record the authoritative stored
      // size, not the size of the rendition it produced locally.
      resolver.data = FileData(file: await bigPng());
      await mediaRepository.createMedia(photo('m2'));
      final outcome = await build().process(await enqueue('m2'));

      expect(outcome, UploadOutcome.uploaded);
      final got = await mediaRepository.getMediaById('m2');
      expect(got!.compressedSizeBytes, 123456);
    },
  );

  test('the Original level uploads the original object', () async {
    resolver.data = FileData(file: await bigPng());
    // Default policy (empty prefs) is original.
    final pipeline = MediaUploadPipeline(
      mediaRepository: mediaRepository,
      queue: queue,
      store: fakeStore,
      registry: registry,
      cache: cache,
      now: () => DateTime(2026, 7, 20, 12),
    );

    await mediaRepository.createMedia(photo('m2'));
    await pipeline.process(await enqueue('m2'));

    expect(
      fakeStore.objects.keys.any((k) => k.startsWith('smv1/objects/')),
      isTrue,
    );
    final got = await mediaRepository.getMediaById('m2');
    expect(got!.remoteUploadedAt, isNotNull);
    expect(got.remoteCompressedUploadedAt, isNull);
  });
}
