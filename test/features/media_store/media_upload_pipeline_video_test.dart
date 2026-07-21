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
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'support/fake_local_file_resolver.dart';
import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

class _FakeVideoTranscoder implements VideoTranscoder {
  int calls = 0;
  @override
  Future<CompressionResult?> transcode(
    MediaItem item,
    File source,
    MediaUploadQuality level, {
    required File output,
    void Function(double fraction)? onProgress,
  }) async {
    calls++;
    final tmp = File('${output.path}.tmp');
    await tmp.writeAsBytes([9, 9, 9, 9], flush: true);
    await tmp.rename(output.path);
    return CompressionResult(file: output, ext: 'mp4', sizeBytes: 4);
  }
}

void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore fakeStore;
  late MediaCacheStore cache;
  late MediaTransferQueueRepository queue;
  late FakeLocalFileResolver resolver;
  late MediaSourceResolverRegistry registry;
  late _FakeVideoTranscoder transcoder;
  late MediaStorePolicies policies;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('pipeline_video');
    fakeStore = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: cacheDb, root: root);
    queue = MediaTransferQueueRepository(database: cacheDb);
    resolver = FakeLocalFileResolver();
    registry = MediaSourceResolverRegistry({
      MediaSourceType.localFile: resolver,
    });
    transcoder = _FakeVideoTranscoder();
    policies = MediaStorePolicies(prefs: await SharedPreferences.getInstance());
    await policies.setVideoUploadQuality(MediaUploadQuality.balanced);
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  MediaUploadPipeline pipeline() => MediaUploadPipeline(
    mediaRepository: mediaRepository,
    queue: queue,
    store: fakeStore,
    registry: registry,
    cache: cache,
    policies: policies,
    videoTranscoder: transcoder,
    now: () => DateTime(2026, 7, 21, 12),
  );

  MediaItem video(String id) => MediaItem(
    id: id,
    mediaType: MediaType.video,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'clip.mp4',
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<File> sourceClip() async {
    final f = File('${root.path}/clip.src');
    await f.writeAsBytes(List<int>.filled(4096, 5), flush: true);
    return f;
  }

  Future<MediaTransferQueueEntry> enqueue(String id) async {
    final rowId = await queue.enqueueUpload(mediaId: id);
    return (await queue.allForTesting()).firstWhere((e) => e.id == rowId);
  }

  test(
    'compressed video uploads a transcoded rendition and cleans artifacts',
    () async {
      resolver.data = FileData(file: await sourceClip());
      await mediaRepository.createMedia(video('v1'));

      final outcome = await pipeline().process(await enqueue('v1'));

      expect(outcome, UploadOutcome.uploaded);
      expect(transcoder.calls, 1);
      expect(
        fakeStore.objects.keys.any(
          (k) => k.startsWith('smv1/renditions/') && k.endsWith('.mp4'),
        ),
        isTrue,
      );
      final got = await mediaRepository.getMediaById('v1');
      expect(got!.remoteCompressedUploadedAt, isNotNull);
      expect(got.remoteUploadedAt, isNull);
      final transcodeDir = Directory('${root.path}/transcode');
      final leftovers = await transcodeDir.exists()
          ? await transcodeDir.list().toList()
          : const <FileSystemEntity>[];
      expect(leftovers, isEmpty, reason: 'transcode dir empty after markDone');
    },
  );

  test('an existing deterministic rendition skips the transcoder', () async {
    resolver.data = FileData(file: await sourceClip());
    await mediaRepository.createMedia(video('v2'));

    await pipeline().process(await enqueue('v2'));
    expect(transcoder.calls, 1);

    final got = await mediaRepository.getMediaById('v2');
    final hash = got!.contentHash!;
    final pre = await cache.transcodeFile(hash, 'balanced');
    await pre.writeAsBytes([9, 9, 9, 9], flush: true);
    await mediaRepository.clearRemoteCompressed('v2');
    fakeStore.objects.clear();

    await pipeline().process(await enqueue('v2'));

    expect(transcoder.calls, 1, reason: 'reused the persisted rendition');
    expect(
      fakeStore.objects.keys.any((k) => k.startsWith('smv1/renditions/')),
      isTrue,
    );
  });

  test('an original video upload sweeps a stranded transcode', () async {
    // A deterministic transcode left by a prior attempt must not linger when
    // the next successful run uploads the original instead (e.g. the user
    // switched the level to Original, or the engine became unavailable).
    await policies.setVideoUploadQuality(MediaUploadQuality.original);

    resolver.data = FileData(file: await sourceClip());
    await mediaRepository.createMedia(video('v1'));
    await pipeline().process(await enqueue('v1'));
    final hash = (await mediaRepository.getMediaById('v1'))!.contentHash!;
    expect(transcoder.calls, 0, reason: 'Original level never transcodes');

    // Simulate a stranded transcode artifact for this hash.
    final stray = await cache.transcodeFile(hash, 'balanced');
    await stray.writeAsBytes([1, 2, 3, 4], flush: true);
    expect(await stray.exists(), isTrue);

    // A second item with the same bytes uploads its original; the markDone
    // cleanup on the original path must sweep the stranded transcode.
    resolver.data = FileData(file: await sourceClip());
    await mediaRepository.createMedia(video('v2'));
    await pipeline().process(await enqueue('v2'));

    expect(
      await stray.exists(),
      isFalse,
      reason: 'stranded transcode swept on the original-upload markDone',
    );
  });

  test('upload failure preserves the video rendition for retry', () async {
    resolver.data = FileData(file: await sourceClip());
    await mediaRepository.createMedia(video('v3'));
    // Thumb generation for a localFile video yields null (undecodable), so
    // the first store call IS the rendition head/put path that fails here.
    fakeStore.failNextWith = Exception('network down');

    final outcome = await pipeline().process(await enqueue('v3'));

    expect(outcome, UploadOutcome.failed);
    final got = await mediaRepository.getMediaById('v3');
    final hash = got!.contentHash!;
    final persisted = await cache.transcodeFile(hash, 'balanced');
    expect(await persisted.exists(), isTrue, reason: 'kept for retry');

    await queue.retry((await queue.allForTesting()).single.id);
    final entry = (await queue.allForTesting()).single;
    await pipeline().process(entry);
    expect(transcoder.calls, 1);
    expect(
      (await mediaRepository.getMediaById('v3'))!.remoteCompressedUploadedAt,
      isNotNull,
    );
  });

  test(
    'photo rendition is cleaned up when the upload fails (leak fix)',
    () async {
      await policies.setPhotoUploadQuality(MediaUploadQuality.balanced);
      // Source lives OUTSIDE staging/ so the only staging entries are the
      // materialized copy (deleted in finally) and the rendition (deleted by
      // the failure-path cleanup) — an empty staging dir proves no leak.
      final png = File('${root.path}/source.png');
      await png.writeAsBytes(
        img.encodePng(img.Image(width: 4000, height: 3000)),
        flush: true,
      );
      resolver.data = FileData(file: png);
      // Make the thumbnail step produce nothing, so failNextWith is consumed by
      // the rendition upload (not the swallowed thumb head()).
      resolver.thumbnailData = const UnavailableData(
        kind: UnavailableKind.notFound,
      );
      await mediaRepository.createMedia(
        video(
          'p1',
        ).copyWith(mediaType: MediaType.photo, originalFilename: 'a.png'),
      );
      fakeStore.failNextWith = Exception('network down');

      await pipeline().process(await enqueue('p1'));

      final staging = Directory('${root.path}/staging');
      final leftovers = await staging.exists()
          ? await staging.list().toList()
          : const <FileSystemEntity>[];
      expect(leftovers, isEmpty, reason: 'no leaked rendition staging files');
    },
  );
}
