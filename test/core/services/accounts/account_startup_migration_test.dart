import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_startup_migration.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late InMemoryKeychain keychain;
  late ConnectedAccountsRepository accounts;

  Future<AccountStartupMigration> migration(SharedPreferences prefs) async {
    return AccountStartupMigration(
      prefs: prefs,
      database: db,
      accounts: accounts,
      credentials: AccountCredentialsStore(storage: keychain),
      syncRepository: SyncRepository(),
      established: EstablishedProviderStore(prefs),
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    keychain = InMemoryKeychain();
    accounts = ConnectedAccountsRepository();
    // setCloudProvider is update-only; seed the global metadata row first.
    await SyncRepository().getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  test('fresh install: no accounts created, flag set', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await (await migration(prefs)).run();

    expect(await accounts.getAll(), isEmpty);
    expect(prefs.getBool('accounts_migration_v1_done'), isTrue);
  });

  test('sync S3 config becomes an account with re-keyed credentials and '
      'carried established flag', () async {
    SharedPreferences.setMockInitialValues({
      'sync_established_providers': ['s3'],
    });
    final prefs = await SharedPreferences.getInstance();
    keychain.values['sync_s3_config'] = '{"endpoint":"e","bucket":"b"}';
    await SyncRepository().setCloudProvider(CloudProviderType.s3);

    await (await migration(prefs)).run();

    final account = await accounts.getByKind(AccountKind.s3);
    expect(account, isNotNull);
    expect(
      keychain.values[AccountCredentialsStore.keyFor(account!.id)],
      '{"endpoint":"e","bucket":"b"}',
    );
    expect(
      keychain.values['sync_s3_config'],
      '{"endpoint":"e","bucket":"b"}',
      reason: 'legacy blob preserved for rollback',
    );
    expect(
      EstablishedProviderStore(prefs).contains(account.id),
      isTrue,
      reason: 'established flag carried to the account id',
    );

    final meta = await db
        .customSelect(
          "SELECT sync_account_id FROM sync_metadata WHERE id = 'global'",
        )
        .getSingle();
    expect(meta.data['sync_account_id'], account.id);
  });

  test('sync S3 and media S3 become two distinct accounts', () async {
    SharedPreferences.setMockInitialValues({
      'media_store_attached_store_id': 'store-1',
      'media_store_provider_type': 's3',
    });
    final prefs = await SharedPreferences.getInstance();
    keychain.values['sync_s3_config'] = '{"sync":true}';
    keychain.values['media_store_s3_config'] = '{"media":true}';
    await SyncRepository().setCloudProvider(CloudProviderType.s3);

    await (await migration(prefs)).run();

    final all = await accounts.getAll();
    final s3Accounts = all.where((a) => a.kind == AccountKind.s3).toList();
    expect(s3Accounts, hasLength(2));

    final mediaAccountId = prefs.getString('media_store_account_id');
    expect(mediaAccountId, isNotNull);
    expect(
      keychain.values[AccountCredentialsStore.keyFor(mediaAccountId!)],
      '{"media":true}',
    );

    final syncAccount = s3Accounts.singleWhere((a) => a.id != mediaAccountId);
    expect(
      keychain.values[AccountCredentialsStore.keyFor(syncAccount.id)],
      '{"sync":true}',
    );
  });

  test(
    'managed media store provider reuses the sync account of that kind',
    () async {
      SharedPreferences.setMockInitialValues({
        'media_store_attached_store_id': 'store-1',
        'media_store_provider_type': 'dropbox',
      });
      final prefs = await SharedPreferences.getInstance();
      keychain.values['sync_dropbox_auth'] = '{"refreshToken":"rt"}';
      await SyncRepository().setCloudProvider(CloudProviderType.dropbox);

      await (await migration(prefs)).run();

      final all = await accounts.getAll();
      expect(all.where((a) => a.kind == AccountKind.dropbox), hasLength(1));
      expect(
        prefs.getString('media_store_account_id'),
        (await accounts.getByKind(AccountKind.dropbox))!.id,
      );
    },
  );

  test(
    'adopted lightroom accounts get the legacy auth blob re-keyed',
    () async {
      // The v107 DB migration copies connector_accounts rows into
      // connected_accounts (ids preserved); the startup migration only owns
      // the keychain copy. Simulate the post-v107 state: an adopted row
      // without per-account credentials.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      keychain.values['lightroom_auth'] = '{"clientId":"c","refreshToken":"r"}';
      await accounts.create(
        kind: AccountKind.adobeLightroom,
        label: 'My Lightroom',
        accountIdentifier: 'catalog-9',
        id: 'lr-1',
      );

      // Simulate the v107 SQL adoption: no HLC, no pending mark.
      await db.customStatement(
        "UPDATE connected_accounts SET hlc = NULL WHERE id = 'lr-1'",
      );
      await db.customStatement(
        "DELETE FROM sync_records WHERE id = 'connectedAccounts_lr-1'",
      );

      await (await migration(prefs)).run();

      expect(
        keychain.values[AccountCredentialsStore.keyFor('lr-1')],
        '{"clientId":"c","refreshToken":"r"}',
      );
      expect(
        keychain.values['lightroom_auth'],
        '{"clientId":"c","refreshToken":"r"}',
        reason: 'legacy blob preserved',
      );

      final pending = await db
          .customSelect(
            "SELECT id FROM sync_records "
            "WHERE id = 'connectedAccounts_lr-1'",
          )
          .get();
      expect(
        pending,
        hasLength(1),
        reason: 'SQL-adopted rows must be marked pending so they sync out',
      );
      final hlc = await db
          .customSelect("SELECT hlc FROM connected_accounts WHERE id = 'lr-1'")
          .getSingle();
      expect(hlc.data['hlc'], isNotNull, reason: 'HLC stamped');
    },
  );

  test('a retry after partial failure reuses the persisted sync account '
      'even when a newer S3 account exists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    keychain.values['sync_s3_config'] = '{"sync":true}';
    await SyncRepository().setCloudProvider(CloudProviderType.s3);

    // Simulate the partial prior run: sync account created + persisted,
    // then a NEWER media-S3 account created before the failure.
    final syncAccount = await accounts.create(
      kind: AccountKind.s3,
      label: 'S3',
    );
    await SyncRepository().setSyncAccount(
      accountId: syncAccount.id,
      providerType: CloudProviderType.s3,
    );
    await accounts.create(kind: AccountKind.s3, label: 'S3 media storage');

    await (await migration(prefs)).run();

    expect(await SyncRepository().getSyncAccountId(), syncAccount.id);
  });

  test(
    'a retry after partial failure reuses the recorded media account',
    () async {
      final prior = await accounts.create(
        kind: AccountKind.s3,
        label: 'S3 media storage',
      );
      SharedPreferences.setMockInitialValues({
        'media_store_attached_store_id': 'store-1',
        'media_store_provider_type': 's3',
        'media_store_account_id': prior.id,
      });
      final prefs = await SharedPreferences.getInstance();

      await (await migration(prefs)).run();

      final s3Accounts = (await accounts.getAll())
          .where((a) => a.kind == AccountKind.s3)
          .toList();
      expect(s3Accounts, hasLength(1), reason: 'no duplicate media account');
      expect(prefs.getString('media_store_account_id'), prior.id);
    },
  );

  test('run is idempotent', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    keychain.values['sync_s3_config'] = '{"a":1}';
    await SyncRepository().setCloudProvider(CloudProviderType.s3);

    await (await migration(prefs)).run();
    final countAfterFirst = (await accounts.getAll()).length;
    await (await migration(prefs)).run();

    expect((await accounts.getAll()).length, countAfterFirst);
  });
}
