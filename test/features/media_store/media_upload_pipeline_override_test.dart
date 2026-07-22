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
    root = await Directory.systemTemp.createTemp('pipeline_override');
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

  Future<MediaUploadPipeline> buildPipeline({
    MediaStorePolicies? policies,
  }) async => MediaUploadPipeline(
    mediaRepository: mediaRepository,
    queue: queue,
    store: fakeStore,
    registry: registry,
    cache: cache,
    policies: policies,
    now: () => DateTime(2026, 7, 20, 12),
  );

  Future<UploadOutcome> processUpload(String mediaId) async {
    final id = await queue.enqueueUpload(mediaId: mediaId);
    final entry = (await queue.allForTesting()).firstWhere((e) => e.id == id);
    return (await buildPipeline()).process(entry);
  }

  Future<UploadOutcome> processOverride(
    String mediaId,
    MediaUploadQuality level,
  ) async {
    final id = await queue.enqueueReupload(
      mediaId: mediaId,
      overrideLevel: level.name,
    );
    final entry = (await queue.allForTesting()).firstWhere((e) => e.id == id);
    return (await buildPipeline()).process(entry);
  }

  bool hasObjects() =>
      fakeStore.objects.keys.any((k) => k.startsWith('smv1/objects/'));
  bool hasRenditions() =>
      fakeStore.objects.keys.any((k) => k.startsWith('smv1/renditions/'));

  test(
    'override original -> compressed replaces and GCs the original',
    () async {
      resolver.data = FileData(file: await bigPng());
      await mediaRepository.createMedia(photo('m1'));
      await processUpload('m1'); // Original level -> objects/<hash>
      expect(hasObjects(), isTrue);

      final outcome = await processOverride('m1', MediaUploadQuality.small);

      expect(outcome, UploadOutcome.uploaded);
      expect(hasRenditions(), isTrue);
      expect(hasObjects(), isFalse, reason: 'abandoned original GC-deleted');
      final got = await mediaRepository.getMediaById('m1');
      expect(got!.remoteUploadedAt, isNull);
      expect(got.remoteCompressedUploadedAt, isNotNull);
      expect(got.compressedLevel, 'small');
    },
  );

  test(
    'override changes the compressed level in place, one rendition',
    () async {
      resolver.data = FileData(file: await bigPng());
      final policies = MediaStorePolicies(
        prefs: await SharedPreferences.getInstance(),
      );
      await policies.setPhotoUploadQuality(MediaUploadQuality.balanced);

      await mediaRepository.createMedia(photo('m2'));
      final id = await queue.enqueueUpload(mediaId: 'm2');
      final entry = (await queue.allForTesting()).firstWhere((e) => e.id == id);
      await (await buildPipeline(policies: policies)).process(entry);
      expect(
        (await mediaRepository.getMediaById('m2'))!.compressedLevel,
        'balanced',
      );

      await processOverride('m2', MediaUploadQuality.small);

      final got = await mediaRepository.getMediaById('m2');
      expect(got!.compressedLevel, 'small');
      expect(got.remoteUploadedAt, isNull);
      expect(hasObjects(), isFalse);
      expect(
        fakeStore.objects.keys
            .where((k) => k.startsWith('smv1/renditions/'))
            .length,
        1,
      );
    },
  );

  test(
    'a corrupt override level falls back to the device policy, not failure',
    () async {
      resolver.data = FileData(file: await bigPng());
      final policies = MediaStorePolicies(
        prefs: await SharedPreferences.getInstance(),
      );
      await policies.setPhotoUploadQuality(MediaUploadQuality.small);
      await mediaRepository.createMedia(photo('m3'));

      // A stored override string that maps to no enum value (corruption or a
      // level written by a newer app version) must not throw ArgumentError.
      final id = await queue.enqueueReupload(
        mediaId: 'm3',
        overrideLevel: 'not_a_real_level',
      );
      final entry = (await queue.allForTesting()).firstWhere((e) => e.id == id);
      final outcome = await (await buildPipeline(
        policies: policies,
      )).process(entry);

      expect(outcome, UploadOutcome.uploaded);
      expect(hasRenditions(), isTrue);
      final got = await mediaRepository.getMediaById('m3');
      expect(
        got!.compressedLevel,
        'small',
        reason: 'fell back to the device policy level',
      );
    },
  );

  test(
    'a best-effort GC delete failure does not fail the override upload',
    () async {
      resolver.data = FileData(file: await bigPng());
      await mediaRepository.createMedia(photo('m4'));
      await processUpload('m4'); // Original level -> objects/<hash>
      expect(hasObjects(), isTrue);

      // The abandoned-original cleanup delete throws, but the rendition
      // upload already succeeded: the outcome must stay uploaded.
      fakeStore.failDeleteWith = Exception('transient delete failure');
      final outcome = await processOverride('m4', MediaUploadQuality.small);

      expect(outcome, UploadOutcome.uploaded);
      expect(hasRenditions(), isTrue);
      final got = await mediaRepository.getMediaById('m4');
      expect(got!.remoteCompressedUploadedAt, isNotNull);
      expect(got.remoteUploadedAt, isNull);
    },
  );
}
