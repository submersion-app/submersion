import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
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
import '../../support/fake_app_settings_repository.dart';

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDbA;
  late LocalCacheDatabase cacheDbB;
  late Directory rootA;
  late Directory rootB;
  late InMemoryMediaObjectStore bucket;
  late MediaCacheStore cacheA;
  late MediaCacheStore cacheB;
  late MediaTransferQueueRepository queueA;
  late FakeLocalFileResolver resolver;
  late MediaSourceResolverRegistry registry;

  setUp(() async {
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDbA = LocalCacheDatabase(NativeDatabase.memory());
    cacheDbB = LocalCacheDatabase(NativeDatabase.memory());
    rootA = await Directory.systemTemp.createTemp('e2e_q_a');
    rootB = await Directory.systemTemp.createTemp('e2e_q_b');
    bucket = InMemoryMediaObjectStore();
    cacheA = MediaCacheStore(database: cacheDbA, root: rootA);
    cacheB = MediaCacheStore(database: cacheDbB, root: rootB);
    queueA = MediaTransferQueueRepository(database: cacheDbA);
    resolver = FakeLocalFileResolver();
    registry = MediaSourceResolverRegistry({
      MediaSourceType.localFile: resolver,
    });
  });

  tearDown(() async {
    await cacheDbA.close();
    await cacheDbB.close();
    await rootA.delete(recursive: true);
    await rootB.delete(recursive: true);
    await tearDownTestDatabase();
  });

  test(
    'device A compressed upload resolves from the store on device B',
    () async {
      final source = await cacheA.stagingFile();
      await source.writeAsBytes(
        img.encodePng(img.Image(width: 4000, height: 3000)),
        flush: true,
      );
      resolver.data = FileData(file: source);

      final quality = MediaUploadQualityPolicy(
        settings: FakeAppSettingsRepository(),
      );
      await quality.setPhotoUploadQuality(MediaUploadQuality.balanced);

      final pipelineA = MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: queueA,
        store: bucket,
        registry: registry,
        cache: cacheA,
        quality: quality,
        now: () => DateTime(2026, 7, 20, 12),
      );

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
      final id = await queueA.enqueueUpload(mediaId: 'm1');
      final entry = (await queueA.allForTesting()).firstWhere(
        (e) => e.id == id,
      );
      await pipelineA.process(entry);

      // The store holds a rendition and NOT an original.
      expect(
        bucket.objects.keys.any((k) => k.startsWith('smv1/renditions/')),
        isTrue,
      );
      expect(
        bucket.objects.keys.any((k) => k.startsWith('smv1/objects/')),
        isFalse,
      );

      final row = await mediaRepository.getMediaById('m1');
      expect(row!.remoteUploadedAt, isNull);
      expect(row.remoteCompressedUploadedAt, isNotNull);
      expect(row.compressedLevel, 'balanced');

      // Device B (fresh cache) resolves the item from the shared store.
      final resolverB = MediaStoreResolver(store: bucket, cache: cacheB);
      final data = await resolverB.tryResolveRemote(row, thumbnail: false);
      expect(data, isA<FileData>());
      final decoded = img.decodeJpg(
        await (data as FileData).file.readAsBytes(),
      )!;
      expect(decoded.width, lessThanOrEqualTo(2048));
    },
  );
}
