import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';
import '../../helpers/wait_until.dart';

/// The settings pages read the worker's suspension through this provider
/// (issue #1356); it must follow the live worker, not a snapshot.
void main() {
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late MediaTransferQueueRepository queue;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('suspended_provider');
    queue = MediaTransferQueueRepository(database: cacheDb);
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: cacheDb, root: root);
  });

  tearDown(() async {
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  test(
    'follows the worker as its preflight starts failing and recovers',
    () async {
      await queue.enqueueUpload(mediaId: 'm1');
      var verified = false;
      final worker = MediaStoreWorker(
        queue: queue,
        pipeline: MediaUploadPipeline(
          mediaRepository: MediaRepository(),
          queue: queue,
          store: store,
          registry: MediaSourceResolverRegistry({}),
          cache: cache,
        ),
        preflight: () async => verified,
      );
      addTearDown(worker.dispose);
      final runtime = MediaStoreRuntime(
        storeId: 'a',
        store: store,
        cache: cache,
        resolver: MediaStoreResolver(store: store, cache: cache),
        worker: worker,
      );
      final container = ProviderContainer(
        overrides: [
          mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(mediaTransfersSuspendedProvider, (_, _) {});
      addTearDown(sub.close);

      expect(
        await container.read(mediaTransfersSuspendedProvider.future),
        isFalse,
      );

      await worker.drain();
      await waitUntil(
        () async =>
            container.read(mediaTransfersSuspendedProvider).value == true,
      );

      verified = true;
      await worker.drain();
      await waitUntil(
        () async =>
            container.read(mediaTransfersSuspendedProvider).value == false,
      );
    },
  );

  // The runtime fires its first drain before any reader can subscribe, and
  // _setSuspended never repeats a value. A reader that sampled isSuspended
  // and then subscribed lost a flip that landed in between, and nothing
  // re-sent it: the queue stayed suspended with no notice, which is the
  // symptom #1356 reported.
  test('a reader that arrives after the flip still sees it', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: MediaUploadPipeline(
        mediaRepository: MediaRepository(),
        queue: queue,
        store: store,
        registry: MediaSourceResolverRegistry({}),
        cache: cache,
      ),
      preflight: () async => false,
    );
    addTearDown(worker.dispose);
    await worker.drain();
    expect(worker.isSuspended, isTrue);

    final container = ProviderContainer(
      overrides: [
        mediaStoreRuntimeProvider.overrideWith(
          (ref) async => MediaStoreRuntime(
            storeId: 'a',
            store: store,
            cache: cache,
            resolver: MediaStoreResolver(store: store, cache: cache),
            worker: worker,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(mediaTransfersSuspendedProvider, (_, _) {});
    addTearDown(sub.close);

    expect(
      await container.read(mediaTransfersSuspendedProvider.future),
      isTrue,
    );
  });
}
