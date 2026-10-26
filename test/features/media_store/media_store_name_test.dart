import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

/// mediaStoreName (issue #3522): a store reads by the nickname of the
/// account this device attached it through, and only while attached to it.
void main() {
  const r2 =
      'photos @ 149b84f66d5479265f3e4d4ad4740926.r2.cloudflarestorage.com';

  late ConnectedAccountsRepository accounts;
  late MediaStoreAttachState attachState;
  late String accountId;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    accounts = ConnectedAccountsRepository();
    final account = await accounts.create(kind: AccountKind.s3, label: r2);
    accountId = account.id;
    await accounts.setNickname(accountId, 'Dive photos');
  });

  tearDown(tearDownTestDatabase);

  MediaStoreDescriptor store(String id) => (
    id: id,
    providerType: 's3',
    displayHint: r2,
    lastSweepAt: null,
    accountId: null,
  );

  test('the attached store reads by its account nickname', () async {
    await attachState.setAttached(
      'store-a',
      providerType: CloudProviderType.s3,
      accountId: accountId,
    );
    expect(
      await mediaStoreName(
        store('store-a'),
        attachState: attachState,
        accounts: accounts,
      ),
      'Dive photos',
    );
  });

  test('another store never borrows the attached account nickname', () async {
    await attachState.setAttached(
      'store-a',
      providerType: CloudProviderType.s3,
      accountId: accountId,
    );
    expect(
      await mediaStoreName(
        store('store-b'),
        attachState: attachState,
        accounts: accounts,
      ),
      'photos @ Cloudflare R2',
    );
  });

  group('mediaStoreStatusHintProvider', () {
    late LocalCacheDatabase cacheDb;
    late Directory root;
    late MediaStoresRepository stores;

    setUp(() async {
      cacheDb = LocalCacheDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      root = await Directory.systemTemp.createTemp('store_status_hint');
      stores = MediaStoresRepository();
    });

    tearDown(() async {
      await cacheDb.close();
      if (root.existsSync()) await root.delete(recursive: true);
    });

    Future<String?> statusHint() async {
      final store = InMemoryMediaObjectStore();
      final cache = MediaCacheStore(database: cacheDb, root: root);
      final container = ProviderContainer(
        overrides: [
          mediaStoreRuntimeProvider.overrideWith(
            (ref) async => MediaStoreRuntime(
              storeId: 'runtime-store',
              store: store,
              cache: cache,
              resolver: MediaStoreResolver(store: store, cache: cache),
            ),
          ),
          mediaStoreAttachStateProvider.overrideWithValue(attachState),
          mediaStoresRepositoryProvider.overrideWithValue(stores),
          connectedAccountsRepositoryProvider.overrideWithValue(accounts),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(mediaStoreStatusHintProvider, (_, _) {});
      addTearDown(sub.close);
      return container.read(mediaStoreStatusHintProvider.future);
    }

    test('names the attached store by its account nickname', () async {
      await stores.upsertActive(
        storeId: 'store-a',
        providerType: 's3',
        displayHint: r2,
      );
      await attachState.setAttached(
        'store-a',
        providerType: CloudProviderType.s3,
        accountId: accountId,
      );
      expect(await statusHint(), 'Dive photos');
    });

    test('falls back to the runtime store id without an announced '
        'store', () async {
      expect(await statusHint(), 'runtime-store');
    });
  });
}
