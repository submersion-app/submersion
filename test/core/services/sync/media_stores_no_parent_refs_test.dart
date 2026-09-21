import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

/// Spec 5.3 asked for a parentRefs entry and a tombstone for mediaStores.
/// Neither applies today, and these tests say why, so the next change to
/// either fact fails here with the reason rather than silently diverging.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'media_stores declares no foreign keys, so it needs no parentRefs entry',
    () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);

      final fks = await db
          .customSelect("PRAGMA foreign_key_list('media_stores')")
          .get();

      expect(
        fks,
        isEmpty,
        reason:
            'add an FK here and sync_parent_refs_completeness_test will '
            'demand a parentRefs entry for mediaStores; add it there, not here',
      );
      expect(SyncService.parentRefs.containsKey('mediaStores'), isFalse);
    },
  );

  test('disconnecting keeps the synced descriptor', () async {
    // Disconnect clears credentials and attach state and deliberately keeps
    // the row, so other devices still learn the store exists. That is why
    // there is no local delete, and so nothing to tombstone. A delete path
    // added later must call SyncRepository.logDeletion, or peers re-add the
    // row on their next publish.
    SharedPreferences.setMockInitialValues({});
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final stores = MediaStoresRepository();
    await stores.upsertActive(
      storeId: 'store-1',
      providerType: 's3',
      displayHint: 'dive-media @ minio',
    );
    final service = MediaStoreService(
      credentials: MediaStoreCredentialsStore(storage: InMemoryKeychain()),
      attachState: MediaStoreAttachState(),
      storesRepository: stores,
      accountsRepository: ConnectedAccountsRepository(),
      accountCredentials: AccountCredentialsStore(storage: InMemoryKeychain()),
    );

    await service.disconnect();

    expect((await stores.getActive())?.id, 'store-1');
    final tombstones = await db
        .customSelect(
          'SELECT record_id FROM deletion_log '
          "WHERE entity_type = 'mediaStores'",
        )
        .get();
    expect(tombstones, isEmpty);
  });
}
