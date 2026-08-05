import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore store;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('verify_runner');
    store = InMemoryMediaObjectStore();
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  ProviderContainer container({bool attached = true}) {
    final cache = MediaCacheStore(database: cacheDb, root: root);
    final c = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(MediaRepository()),
        mediaTransferQueueRepositoryProvider.overrideWithValue(
          MediaTransferQueueRepository(database: cacheDb),
        ),
        mediaStoreRuntimeProvider.overrideWith(
          (ref) async => attached
              ? MediaStoreRuntime(
                  storeId: 'store-1',
                  store: store,
                  cache: cache,
                  resolver: MediaStoreResolver(store: store, cache: cache),
                )
              : null,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'runner sweeps the attached store and stamps the fleet timestamp',
    () async {
      final storesRepository = MediaStoresRepository();
      await storesRepository.upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'test',
      );
      store.staleSessionCount = 1;

      final report = await container().read(mediaVerifyRunnerProvider)();

      expect(report.objectsChecked, 0);
      expect(report.sessionsAborted, 1);
      expect((await storesRepository.getActive())!.lastSweepAt, isNotNull);
    },
  );

  test('runner without an active descriptor still returns a report', () async {
    final report = await container().read(mediaVerifyRunnerProvider)();
    expect(report.orphansRemoved, 0);
  });

  test('runner throws StateError when no store is attached', () async {
    await expectLater(
      container(attached: false).read(mediaVerifyRunnerProvider)(),
      throwsStateError,
    );
  });
}
