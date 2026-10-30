// Issue #3482 phase 5: the steps replace and join takes once the library
// has been swapped, on the app's own stores.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/replace_and_join_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show sharedPreferencesProvider;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_cloud_storage_provider.dart';
import '../../../../support/fake_keychain_storage.dart';

/// Records the backup and the pin instead of writing a database copy.
class _Backups extends Fake implements BackupService {
  String? note;
  final pinned = <String>[];

  @override
  Future<BackupRecord> performBackup({
    bool isAutomatic = false,
    String? note,
  }) async {
    this.note = note;
    return BackupRecord(
      id: 'set-aside',
      filename: 'set-aside.db',
      timestamp: DateTime.utc(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
      note: note,
    );
  }

  @override
  Future<void> pinBackup(String id) async => pinned.add(id);
}

/// Records a worker-safe drop of queue rows.
class _Worker extends Fake implements MediaStoreWorker {
  final deleted = <int>[];

  @override
  Future<void> deleteEntries(List<int> ids) async => deleted.addAll(ids);
}

/// Counts full detaches.
class _MediaStore extends MediaStoreService {
  _MediaStore()
    : super(
        credentials: MediaStoreCredentialsStore(storage: InMemoryKeychain()),
        attachState: MediaStoreAttachState(),
        storesRepository: MediaStoresRepository(),
        mediaRepository: MediaRepository(),
      );

  int disconnects = 0;

  @override
  Future<void> disconnect() async => disconnects++;
}

void main() {
  late SharedPreferences prefs;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late FakeCloudStorageProvider cloud;
  late ProductionReplaceJoinSteps steps;
  late _Backups backups;
  late _MediaStore mediaStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    queue = MediaTransferQueueRepository(database: cacheDb);
    cloud = FakeCloudStorageProvider();
    backups = _Backups();
    mediaStore = _MediaStore();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mediaTransferQueueRepositoryProvider.overrideWithValue(queue),
        cloudStorageProviderProvider.overrideWithValue(cloud),
        backupServiceProvider.overrideWithValue(backups),
        mediaStoreServiceProvider.overrideWithValue(mediaStore),
      ],
    );
    addTearDown(container.dispose);
    steps = container.read(
      Provider<ProductionReplaceJoinSteps>(ProductionReplaceJoinSteps.new),
    );
  });

  tearDown(() => cacheDb.close());

  test('the photo queue is emptied', () async {
    await queue.enqueueUpload(mediaId: 'old-1');
    await queue.enqueueUpload(mediaId: 'old-2');

    await steps.discardPhotoQueue();

    expect(await queue.allForTesting(), isEmpty);
  });

  test(
    'the account counts as established and no restore sync is left',
    () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      await container.read(postRestoreSyncStoreProvider).setPending();

      await steps.settleSyncState();

      expect(
        container
            .read(establishedProviderStoreProvider)
            .contains(cloud.providerId),
        isTrue,
      );
      expect(container.read(postRestoreSyncStoreProvider).pending, isFalse);
    },
  );

  test('the set-aside backup carries the note and is pinned', () async {
    await steps.takePinnedBackup('Before joining the library, 21 Oct');

    expect(backups.note, 'Before joining the library, 21 Oct');
    expect(backups.pinned, ['set-aside']);
  });

  test('the photo store is fully detached', () async {
    await steps.forgetPhotoStore();

    expect(mediaStore.disconnects, 1);
  });

  test('an active diver the new library lacks is let go', () async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await prefs.setString(currentDiverIdKey, 'diver-from-before');

    await steps.realignActiveDiver();

    expect(prefs.getString(currentDiverIdKey), isNull);
  });

  // The provider end to end: the account's library replaces this device's,
  // through the app's own sync service and the steps above.
  test(
    'the provider replaces the library through the app\'s services',
    () async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'lib-1', diveNumber: 1),
      );
      await seedPeerLog(cloud, 'peer-1');
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'mine-1', diveNumber: 7),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaTransferQueueRepositoryProvider.overrideWithValue(queue),
          cloudStorageProviderProvider.overrideWithValue(cloud),
          backupServiceProvider.overrideWithValue(backups),
          mediaStoreServiceProvider.overrideWithValue(mediaStore),
          mediaStoreAttachStateProvider.overrideWithValue(
            MediaStoreAttachState(prefs: prefs),
          ),
          syncServiceProvider.overrideWithValue(
            SyncService(
              syncRepository: SyncRepository(),
              serializer: SyncDataSerializer(),
              cloudProvider: cloud,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(replaceAndJoinServiceProvider)
          .run(backupNote: 'Before joining the library');

      expect(result.outcome, ReplaceJoinOutcome.replaced);
      final dives = await DatabaseService.instance.database
          .customSelect('SELECT id FROM dives')
          .get();
      expect([for (final r in dives) r.read<String>('id')], ['lib-1']);
      expect(backups.pinned, ['set-aside']);
      expect(mediaStore.disconnects, 1);
    },
  );

  // Copilot review: the queue goes through the old store's worker, which
  // abandons each row's resumable session with the provider.
  test('the photo queue is dropped through the worker when one runs', () async {
    final a = await queue.enqueueUpload(mediaId: 'old-1');
    final b = await queue.enqueueUpload(mediaId: 'old-2');
    final worker = _Worker();
    final root = await Directory.systemTemp.createTemp('replace_join_runtime');
    addTearDown(() => root.delete(recursive: true));
    final store = InMemoryMediaObjectStore();
    final cache = MediaCacheStore(database: cacheDb, root: root);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mediaTransferQueueRepositoryProvider.overrideWithValue(queue),
        mediaStoreRuntimeProvider.overrideWith(
          (ref) async => MediaStoreRuntime(
            storeId: 'store-a',
            store: store,
            cache: cache,
            resolver: MediaStoreResolver(store: store, cache: cache),
            worker: worker,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mediaStoreRuntimeProvider.future);
    final withWorker = container.read(
      Provider<ProductionReplaceJoinSteps>(ProductionReplaceJoinSteps.new),
    );

    await withWorker.discardPhotoQueue();

    expect(worker.deleted.toSet(), {a, b});
  });

  test('transfers settle when nothing is claimed', () async {
    expect(await steps.settlePhotoTransfers(), isTrue);
  });
}
