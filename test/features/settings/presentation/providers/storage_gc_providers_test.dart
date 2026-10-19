import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_coordinator.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';
import 'package:submersion/core/services/storage/local_cache_sweep.dart';
import 'package:submersion/core/services/storage/scratch_sweep.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_sweep_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_gc_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/fake_path_provider.dart';
import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../../helpers/test_database.dart';

/// The coordinator's wiring to the live services: the media store runtime,
/// the fleet cadence on the media_stores row, the sync folder and the shared
/// library transports. The schedule itself is covered by the coordinator's
/// own tests; this pins that the providers hand it the right things.
void main() {
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late SharedPreferences prefs;
  late FakeCloudStorageProvider syncCloud;
  late FakeCloudStorageProvider libraryCloud;
  final old = DateTime.now().subtract(const Duration(days: 30));

  void writeMarker(String storeId) {
    store.objects['smv1/store.json'] = utf8.encode(
      jsonEncode({'storeId': storeId, 'formatVersion': 1, 'createdAt': ''}),
    );
  }

  setUp(() async {
    // A fresh local cache sweep stamp keeps the weekly pass (which needs
    // the live database services) out of these tests.
    SharedPreferences.setMockInitialValues({
      kLocalCacheSweepStampKey: DateTime.now().millisecondsSinceEpoch,
      // This device is attached to store-1, and the store carries its
      // marker: the preflight every sweep now runs passes.
      MediaStoreAttachState.storeIdKey: 'store-1',
    });
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('storage_gc_providers');
    useFakePathProvider(_TempPathProvider(root.path));
    store = InMemoryMediaObjectStore();
    writeMarker('store-1');
    syncCloud = FakeCloudStorageProvider();
    libraryCloud = FakeCloudStorageProvider();
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  /// A photo this database knows, with its object in the store: without one
  /// the database does not know the store and the sweep deletes nothing.
  Future<void> knownPhoto() async {
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
    store.objects[StoreKeys.objectKey('aabb', extension: 'jpg')] = [1, 2, 3];
    store.modified[StoreKeys.objectKey('aabb', extension: 'jpg')] = old;
  }

  void deadObject() {
    store.objects[StoreKeys.objectKey('dead', extension: 'jpg')] = [1, 2, 3];
    store.modified[StoreKeys.objectKey('dead', extension: 'jpg')] = old;
  }

  Future<void> registerStore() => MediaStoresRepository().upsertActive(
    storeId: 'store-1',
    providerType: 's3',
    displayHint: 'test',
  );

  ProviderContainer container({
    List<SharedLibrary> libraries = const [],
    bool syncOn = true,
    bool runtimeAvailable = true,
    bool runtimeHangs = false,
    Future<void> Function()? whileRuntimeBuilds,
  }) {
    final cache = MediaCacheStore(database: cacheDb, root: root);
    final c = ProviderContainer(
      overrides: [
        if (runtimeHangs)
          mediaStoreRuntimeWaitProvider.overrideWithValue(
            const Duration(milliseconds: 50),
          ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageGcNetworkProvider.overrideWithValue(
          () async => NetworkKind.unmetered,
        ),
        mediaRepositoryProvider.overrideWithValue(MediaRepository()),
        mediaTransferQueueRepositoryProvider.overrideWithValue(
          MediaTransferQueueRepository(database: cacheDb),
        ),
        mediaStoreRuntimeProvider.overrideWith((ref) async {
          if (runtimeHangs) return Completer<MediaStoreRuntime?>().future;
          await whileRuntimeBuilds?.call();
          if (!runtimeAvailable) return null;
          return MediaStoreRuntime(
            storeId: 'store-1',
            store: store,
            cache: cache,
            resolver: MediaStoreResolver(store: store, cache: cache),
          );
        }),
        cloudStorageProviderProvider.overrideWithValue(
          syncOn ? syncCloud : null,
        ),
        // The store, not the libraries stream: an unlistened stream provider
        // is paused in Riverpod 3, and the cleanup runs with nothing
        // listening to it.
        sharedLibraryStoreProvider.overrideWithValue(
          _FakeLibraryStore(libraries),
        ),
        sharedLibraryTransportFactoryProvider.overrideWithValue(
          (library) async =>
              SharedLibraryTransport(libraryCloud, prefix: library.prefix),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('rescan measures the media store, sync folder and libraries', () async {
    store.objects[StoreKeys.objectKey('aabb', extension: 'jpg')] = [1, 2, 3];
    store.modified[StoreKeys.objectKey('aabb', extension: 'jpg')] = old;
    await syncCloud.uploadFile(Uint8List(20), 'ssv1.dev1.manifest.json');
    await libraryCloud.uploadFile(Uint8List(7), 'keyslots.json');
    final c = container(
      libraries: const [
        SharedLibrary(
          id: 'L1',
          name: 'Reef Survey',
          connectedAccountId: 'acct',
          prefix: 'site-sync',
        ),
      ],
    );

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.rescan);

    final usage = c.read(storageGcStoreProvider).cloudUsage!;
    expect(usage.mediaBytes, 3);
    // The sync row is set up but no snapshot exists yet, so the orphan
    // waits rather than counting as reclaimable.
    expect(usage.mediaReclaimableBytes, 0);
    expect(usage.mediaWaitingBytes, 3);
    expect(usage.syncBytes, 20);
    expect(usage.librariesBytes, 7);
    expect(
      store.objects,
      isNotEmpty,
      reason: 'a rescan never deletes anything',
    );
  });

  test('no libraries leaves the library figure out', () async {
    final c = container();

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.rescan);

    expect(c.read(storageGcStoreProvider).cloudUsage!.librariesBytes, isNull);
  });

  test(
    "the fleet cadence is the attached store's, not the newest row",
    () async {
      // A device still attached to an older store sweeps that store; stamping
      // whichever row is newest would hold off the other store's cleanup.
      await registerStore();
      await knownPhoto();
      deadObject();
      await MediaStoresRepository().upsertActive(
        storeId: 'store-2',
        providerType: 's3',
        displayHint: 'newer',
      );
      final c = container(syncOn: false);

      await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.manual);

      final stores = MediaStoresRepository();
      expect((await stores.getById('store-1'))!.lastSweepAt, isNotNull);
      expect((await stores.getById('store-2'))!.lastSweepAt, isNull);
    },
  );

  test('no cloud deletes when only another store has a row', () async {
    await knownPhoto();
    deadObject();
    await MediaStoresRepository().upsertActive(
      storeId: 'store-2',
      providerType: 's3',
      displayHint: 'another',
    );
    final c = container(syncOn: false);

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.manual);

    expect(
      store.objects.keys,
      contains(StoreKeys.objectKey('dead', extension: 'jpg')),
    );
  });

  test('a manual run that may delete stamps the active descriptor', () async {
    await registerStore();
    await knownPhoto();
    deadObject();
    // Sync off: the 7-day grace window is the only rule, so the old orphan
    // may go.
    final c = container(syncOn: false);

    final reclaimed = await c
        .read(storageGcCoordinatorProvider)
        .run(StorageGcTrigger.manual);

    expect(
      store.objects.keys,
      isNot(contains(StoreKeys.objectKey('dead', extension: 'jpg'))),
    );
    expect(reclaimed, greaterThanOrEqualTo(3));
    expect((await MediaStoresRepository().getActive())!.lastSweepAt, isNotNull);
    final usage = c.read(storageGcStoreProvider).cloudUsage!;
    expect(usage.syncBytes, isNull, reason: 'no sync backend set up');
    expect(c.read(storageGcStoreProvider).lastCloudResult!.bytes, 3);
  });

  test('no cloud deletes without a media_stores row for the store', () async {
    // A database that never registered this store (a fresh dive log, a
    // restore from before it was attached) must not decide what in it is
    // orphaned.
    await knownPhoto();
    deadObject();
    final c = container(syncOn: false);

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.manual);

    expect(
      store.objects.keys,
      contains(StoreKeys.objectKey('dead', extension: 'jpg')),
    );
  });

  test('a restore that starts during the sweep stops its deletes', () async {
    // The sweep judged orphans against the database it started with; once a
    // restore records itself that database is on its way out.
    await registerStore();
    await knownPhoto();
    deadObject();
    store.objects[StoreKeys.objectKey('dead2', extension: 'jpg')] = [4, 5, 6];
    store.modified[StoreKeys.objectKey('dead2', extension: 'jpg')] = old;
    store.onDelete = (_) => StorageGcStore.markRestored(prefs, DateTime.now());
    final c = container(syncOn: false);

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.manual);

    final survivors = [
      StoreKeys.objectKey('dead', extension: 'jpg'),
      StoreKeys.objectKey('dead2', extension: 'jpg'),
    ].where(store.objects.containsKey);
    expect(survivors, hasLength(1), reason: 'one delete, then the restore');
  });

  test('a restore while the store connects stops the deletes', () async {
    // Building the runtime opens the keychain and reads the store marker;
    // the guard's starting point must come before that wait, or a restore
    // recorded during it reads as the state the sweep began from.
    await registerStore();
    await knownPhoto();
    deadObject();
    final c = container(
      syncOn: false,
      whileRuntimeBuilds: () =>
          StorageGcStore.markRestored(prefs, DateTime.now()),
    );

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.manual);

    expect(
      store.objects.keys,
      contains(StoreKeys.objectKey('dead', extension: 'jpg')),
    );
  });

  test('a store that fails its marker check is not swept', () async {
    // Repointed or wiped: the store's objects are not this library's.
    await registerStore();
    await knownPhoto();
    deadObject();
    writeMarker('another-library');
    final c = container(syncOn: false);

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.manual);

    expect(
      store.objects.keys,
      contains(StoreKeys.objectKey('dead', extension: 'jpg')),
    );
    expect(c.read(storageGcStoreProvider).cloudUsage!.partial, isTrue);
  });

  test(
    'an attached store that cannot be built marks the scan partial',
    () async {
      final c = container(runtimeAvailable: false);

      await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.rescan);

      final usage = c.read(storageGcStoreProvider).cloudUsage!;
      expect(usage.partial, isTrue, reason: 'attached, not "not set up"');
    },
  );

  test(
    'a runtime that never finishes building does not hang the pass',
    () async {
      // Riverpod retries a build that throws, and with nothing listening the
      // future it hands out never completes: every later run (and every
      // Reclaim or Rescan tap) would join a pass that never ends.
      final c = container(runtimeHangs: true);

      await c
          .read(storageGcCoordinatorProvider)
          .run(StorageGcTrigger.rescan)
          .timeout(const Duration(seconds: 10));

      expect(c.read(storageGcStoreProvider).cloudUsage!.partial, isTrue);
    },
  );

  test('an unavailable store keeps the post-restore cleanup pending', () async {
    await StorageGcStore.markRestored(prefs, DateTime.now());
    final c = container(runtimeAvailable: false, syncOn: false);
    await registerStore();

    await c.read(storageGcCoordinatorProvider).run(StorageGcTrigger.launch);

    expect(c.read(storageGcStoreProvider).postRestoreCloudPending, isTrue);
  });

  test('the device figure is worked out once per visit', () async {
    // It used to rebuild when the page's state stream delivered its first
    // value, walking every device folder twice and throwing one away.
    final gcStore = StorageGcStore(prefs);
    await gcStore.setLastDeviceResult(
      AreaResult(bytes: 5, items: 1, at: DateTime(2026, 10, 1)),
    );
    var dryRuns = 0;
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageGcCoordinatorProvider.overrideWith((ref) {
          final coordinator = StorageGcCoordinator(
            deviceSweeps: [
              ({required now, required dryRun}) async {
                if (dryRun) dryRuns++;
                return ScratchSweepReport.empty;
              },
            ],
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
            store: gcStore,
          );
          ref.onDispose(coordinator.dispose);
          return coordinator;
        }),
      ],
    );
    addTearDown(c.dispose);

    c.listen(storageGcStateProvider, (_, _) {});
    c.listen(deviceReclaimableBytesProvider, (_, _) {});
    await c.read(deviceReclaimableBytesProvider.future);
    await pumpEventQueue();

    expect(dryRuns, 1);
  });

  test('the page shows only cloud areas set up now', () async {
    // A scan from before a sync backend was disconnected still holds its
    // figure; showing it would count an area that is gone.
    await StorageGcStore(prefs).setCloudUsage(
      CloudUsage(
        scannedAt: DateTime(2026, 10, 1),
        mediaBytes: 10,
        mediaStoreId: 'store-1',
        syncBytes: 20,
        librariesBytes: 30,
      ),
    );
    final c = container(syncOn: false);
    c.listen(storageGcStateProvider, (_, _) {});

    final view = await c.read(storageGcStateProvider.future);

    expect(view.cloudUsage!.mediaBytes, 10, reason: 'store-1 is attached');
    expect(view.cloudUsage!.syncBytes, isNull);
    expect(view.cloudUsage!.librariesBytes, isNull);
  });

  test('the page hides the figures of a store no longer attached', () async {
    await StorageGcStore(prefs).setCloudUsage(
      CloudUsage(
        scannedAt: DateTime(2026, 10, 1),
        mediaBytes: 10,
        mediaStoreId: 'old-store',
      ),
    );
    final c = container(syncOn: false);
    c.listen(storageGcStateProvider, (_, _) {});

    final view = await c.read(storageGcStateProvider.future);

    expect(view.cloudUsage!.mediaBytes, isNull);
  });

  test('last reclaimed adds the device and cloud results of one pass', () {
    final at = DateTime(2026, 10, 17);
    final view = StorageGcView(
      running: false,
      lastDeviceResult: AreaResult(bytes: 5, items: 1, at: at),
      lastCloudResult: AreaResult(bytes: 300, items: 2, at: at),
    );
    expect(view.lastReclaimed!.bytes, 305);
    expect(view.lastReclaimed!.items, 3);
  });
}

class _FakeLibraryStore extends SharedLibraryStore {
  _FakeLibraryStore(this.libraries);

  final List<SharedLibrary> libraries;

  @override
  Future<List<SharedLibrary>> getLibraries() async => libraries;

  @override
  Stream<void> watchLibraries() => const Stream.empty();
}

/// Points the temporary directory at the test's own folder: the store
/// marker read goes through it.
class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}
