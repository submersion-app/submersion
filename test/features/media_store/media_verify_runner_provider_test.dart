import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_coordinator.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/orphan_delete_policy.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_sweep_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_gc_providers.dart';

import '../../helpers/fake_path_provider.dart';
import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late SharedPreferences prefs;

  void writeMarker(String storeId) {
    store.objects['smv1/store.json'] = utf8.encode(
      jsonEncode({'storeId': storeId, 'formatVersion': 1, 'createdAt': ''}),
    );
  }

  setUp(() async {
    // Attached to store-1, whose marker the store carries: the preflight
    // every sweep runs passes.
    SharedPreferences.setMockInitialValues({
      MediaStoreAttachState.storeIdKey: 'store-1',
    });
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('verify_runner');
    useFakePathProvider(_TempPathProvider(root.path));
    store = InMemoryMediaObjectStore();
    writeMarker('store-1');
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  ProviderContainer container({
    bool attached = true,
    OrphanDeletePolicy Function()? policy,
    List<Override> extraOverrides = const [],
  }) {
    final cache = MediaCacheStore(database: cacheDb, root: root);
    final c = ProviderContainer(
      overrides: [
        // The delete policy reads the sync snapshot and restore time here.
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (policy != null)
          orphanDeletePolicyFactoryProvider.overrideWithValue(policy),
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
        ...extraOverrides,
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

  test('a deferred run does not stamp the fleet timestamp', () async {
    // Stamping a run that deleted nothing would hold every device's
    // cleanup off for a week.
    final storesRepository = MediaStoresRepository();
    await storesRepository.upsertActive(
      storeId: 'store-1',
      providerType: 's3',
      displayHint: 'test',
    );

    final report = await container(
      policy: () => OrphanDeletePolicy(now: DateTime.now(), syncEnabled: true),
    ).read(mediaVerifyRunnerProvider)();

    expect(report.deferred, isTrue);
    expect(report.hold, isNull, reason: 'not caught up: the sync wording');
    expect((await storesRepository.getActive())!.lastSweepAt, isNull);
  });

  /// A photo this database knows, and an old object nothing references, in
  /// a store this database registered.
  Future<void> knownPhotoAndDeadObject({bool registered = true}) async {
    if (registered) {
      await MediaStoresRepository().upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'attached',
      );
    }
    final repo = MediaRepository();
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        originalFilename: 'kept.jpg',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.stampContentIdentity(
      created.id,
      contentHash: 'aabb',
      sizeBytes: 3,
    );
    await repo.stampRemoteUploaded(created.id, uploadedAt: DateTime(2026, 2));
    final old = DateTime.now().subtract(const Duration(days: 30));
    store.objects[StoreKeys.objectKey('aabb', extension: 'jpg')] = [1, 2, 3];
    store.modified[StoreKeys.objectKey('aabb', extension: 'jpg')] = old;
    store.objects[StoreKeys.objectKey('dead', extension: 'jpg')] = [4, 5];
    store.modified[StoreKeys.objectKey('dead', extension: 'jpg')] = old;
  }

  test(
    'an upload in flight holds the deletes back, as in the cleanup',
    () async {
      await knownPhotoAndDeadObject();
      final queue = MediaTransferQueueRepository(database: cacheDb);
      final id = await queue.enqueueUpload(mediaId: 'other');
      await queue.markTransferring(id);

      final report = await container(
        policy: () => OrphanDeletePolicy.unrestricted(DateTime.now()),
      ).read(mediaVerifyRunnerProvider)();

      expect(report.deferred, isTrue);
      expect(report.hold, CloudDeleteHold.uploads);
      expect(
        store.objects.keys,
        contains(StoreKeys.objectKey('dead', extension: 'jpg')),
      );
    },
  );

  test('a Verify Library run shows on the Storage usage page', () async {
    await knownPhotoAndDeadObject();
    final c = container(
      policy: () => OrphanDeletePolicy.unrestricted(DateTime.now()),
    );

    await c.read(mediaVerifyRunnerProvider)();

    expect(c.read(storageGcStoreProvider).lastCloudResult!.bytes, 2);
    expect(
      c.read(storageGcStoreProvider).cloudUsage!.mediaStoreId,
      'store-1',
      reason: 'the swept runtime\'s store',
    );
  });

  test('an attachment change during the sweep stops its deletes', () async {
    // Disconnected or repointed mid-sweep: the rest of the listing is no
    // longer this device's store to judge.
    await knownPhotoAndDeadObject();
    store.objects[StoreKeys.objectKey('dead2', extension: 'jpg')] = [6, 7];
    store.modified[StoreKeys.objectKey('dead2', extension: 'jpg')] =
        DateTime.now().subtract(const Duration(days: 30));
    store.onDelete = (_) => prefs.setInt(
      MediaStoreAttachState.generationKey,
      (prefs.getInt(MediaStoreAttachState.generationKey) ?? 0) + 1,
    );

    final report = await container(
      policy: () => OrphanDeletePolicy.unrestricted(DateTime.now()),
    ).read(mediaVerifyRunnerProvider)();

    expect(report.orphansRemoved, 1);
    expect(report.deferred, isTrue);
  });

  test('a store this database never registered is not swept', () async {
    // The scheduled cleanup's rule: a restore from before the store was
    // attached does not know which of its objects are orphans.
    await knownPhotoAndDeadObject(registered: false);

    final report = await container(
      policy: () => OrphanDeletePolicy.unrestricted(DateTime.now()),
    ).read(mediaVerifyRunnerProvider)();

    expect(report.deferred, isTrue);
    expect(report.hold, CloudDeleteHold.unregistered);
    expect(
      store.objects.keys,
      contains(StoreKeys.objectKey('dead', extension: 'jpg')),
    );
  });

  test("Verify Library stamps the attached store's row", () async {
    // Not the newest row: a device still attached to an older store would
    // otherwise mark the other store swept.
    final stores = MediaStoresRepository();
    await stores.upsertActive(
      storeId: 'store-1',
      providerType: 's3',
      displayHint: 'attached',
    );
    await stores.upsertActive(
      storeId: 'store-2',
      providerType: 's3',
      displayHint: 'newer',
    );

    await container().read(mediaVerifyRunnerProvider)();

    expect((await stores.getById('store-1'))!.lastSweepAt, isNotNull);
    expect((await stores.getById('store-2'))!.lastSweepAt, isNull);
  });

  test(
    'a failure recording the page figures does not fail the sweep',
    () async {
      final stores = MediaStoresRepository();
      await stores.upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'attached',
      );
      final c = container(
        extraOverrides: [
          storageGcCoordinatorProvider.overrideWith(
            (ref) => _FailingRecordCoordinator(StorageGcStore(prefs)),
          ),
        ],
      );

      final report = await c.read(mediaVerifyRunnerProvider)();

      expect(report.deferred, isFalse);
      expect((await stores.getById('store-1'))!.lastSweepAt, isNotNull);
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

  test('a store that fails its marker check is not swept', () async {
    // Repointed or wiped: its objects are not this library's to judge.
    writeMarker('another-library');

    await expectLater(
      container().read(mediaVerifyRunnerProvider)(),
      throwsStateError,
    );
  });
}

/// A coordinator whose page record fails, as a failed prefs write would.
class _FailingRecordCoordinator extends StorageGcCoordinator {
  _FailingRecordCoordinator(StorageGcStore store)
    : super(
        deviceSweeps: const [],
        localCacheSweep: (_, {required force}) async {},
        network: () async => NetworkKind.offline,
        isSyncBusy: () => false,
        hasTransferringUploads: () async => false,
        mediaSweep: ({required dryRun}) async => null,
        deletesAllowed: () async => false,
        isStoreRegistered: () async => true,
        attachedStoreId: () async => null,
        fleetSweepDue: (_) async => false,
        stampFleetSweep: (_) async {},
        measureSync: () async => null,
        measureLibraries: () async => null,
        store: store,
      );

  @override
  Future<void> recordMediaSweep(
    VerifyLibraryReport report, {
    required String storeId,
  }) async => throw StateError('prefs write failed');
}

/// Points the temporary directory at the test's own folder: the store
/// marker read goes through it.
class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}
