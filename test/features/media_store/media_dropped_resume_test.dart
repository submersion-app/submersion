import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';
import 'support/fake_local_file_resolver.dart';

/// A re-upload or a Transfers delete drops the queue row that carried a
/// resumable session; the provider-side session must be abandoned rather
/// than left for the 7-day reap (storage GC design, leak 4).
void main() {
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaTransferQueueRepository queue;
  late MediaUploadPipeline pipeline;
  late MediaStoreWorker worker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('dropped_resume');
    store = InMemoryMediaObjectStore();
    queue = MediaTransferQueueRepository(database: cacheDb);
    pipeline = MediaUploadPipeline(
      mediaRepository: mediaRepository,
      queue: queue,
      store: store,
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: FakeLocalFileResolver(),
      }),
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
    worker = MediaStoreWorker(queue: queue, pipeline: pipeline);
  });

  tearDown(() async {
    worker.dispose();
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  Future<void> media(String id, {String? hash}) async {
    await mediaRepository.createMedia(
      MediaItem(
        id: id,
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        originalFilename: 'shot.PNG',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    if (hash != null) {
      await mediaRepository.stampContentIdentity(
        id,
        contentHash: hash,
        sizeBytes: 1,
      );
    }
  }

  Future<int> uploadWithResume(String mediaId, String json) async {
    final id = await queue.enqueueUpload(mediaId: mediaId);
    await queue.updateResumeState(id, json);
    return id;
  }

  test('resumeStatesFor reports the resume state a re-upload drops', () async {
    await uploadWithResume('m1', '{"s":1}');
    await queue.enqueueUpload(mediaId: 'm2');

    final dropped = await queue.resumeStatesFor('m1');

    expect(dropped.single.mediaId, 'm1');
    expect(dropped.single.resumeStateJson, '{"s":1}');
    expect(await queue.resumeStatesFor('m2'), isEmpty);
  });

  test('resumeStatesFor leaves a transferring upload alone', () async {
    // Its session is live: the pipeline is pushing parts into it now.
    final id = await uploadWithResume('m1', '{"s":1}');
    await queue.markTransferring(id);

    expect(await queue.resumeStatesFor('m1'), isEmpty);
  });

  test('resumeStateOf reports the resume state a delete drops', () async {
    final id = await uploadWithResume('m1', '{"s":1}');
    final plain = await queue.enqueueUpload(mediaId: 'm2');

    expect((await queue.resumeStateOf(id))!.resumeStateJson, '{"s":1}');
    expect(await queue.resumeStateOf(plain), isNull);
  });

  test(
    'a Transfers delete of a live upload leaves its session alone',
    () async {
      await media('m1', hash: 'aabb');
      final id = await uploadWithResume('m1', '{"s":1}');
      await queue.markTransferring(id);

      expect(await queue.resumeStateOf(id), isNull);
      await worker.deleteEntries([id]);

      expect(store.abandonResumeCalls, isEmpty);
    },
  );

  test('worker abandons the session a re-upload dropped', () async {
    await media('m1', hash: 'aabb');
    await uploadWithResume('m1', '{"s":1}');

    await worker.reuploadAndKick('m1', MediaUploadQuality.small);
    await worker.activeDrain;

    expect(store.abandonResumeCalls, [
      (StoreKeys.objectKey('aabb', extension: 'png'), '{"s":1}'),
    ]);
  });

  test('worker abandons the session a Transfers delete dropped', () async {
    await media('m1', hash: 'aabb');
    final id = await uploadWithResume('m1', '{"s":1}');

    await worker.deleteEntries([id]);

    expect(await queue.allForTesting(), isEmpty);
    expect(store.abandonResumeCalls.single.$2, '{"s":1}');
  });

  test('worker skips a dropped entry without a hash', () async {
    await media('m1');
    final id = await uploadWithResume('m1', '{"s":1}');

    await worker.deleteEntries([id]);

    expect(await queue.allForTesting(), isEmpty);
    expect(store.abandonResumeCalls, isEmpty);
  });
}
