import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../../helpers/test_database.dart';

class _StatusAdapter extends AccountProviderAdapter {
  _StatusAdapter(this.kind, this.result);

  @override
  final AccountKind kind;
  final AccountStatus result;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async => result;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectedAccountsRepository accounts;
  late MediaStoresRepository stores;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    accounts = ConnectedAccountsRepository();
    stores = MediaStoresRepository();
    await SyncRepository().getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  PendingSetupService service({
    AccountStatus s3Status = AccountStatus.needsSignIn,
  }) => PendingSetupService(
    prefs: prefs,
    accounts: accounts,
    stores: stores,
    attachState: MediaStoreAttachState(prefs: prefs),
    registry: AccountProviderRegistry([
      _StatusAdapter(AccountKind.s3, s3Status),
      _StatusAdapter(AccountKind.icloud, AccountStatus.unavailable),
    ]),
  );

  test(
    'announced store without a local attachment yields an attach item',
    () async {
      await stores.upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'dive-media @ minio',
      );
      final items = await service().compute();
      expect(items, hasLength(1));
      expect(items.single.kind, SetupItemKind.mediaStoreAttach);
      expect(items.single.label, 'dive-media @ minio');
    },
  );

  test('an attached device gets no store item', () async {
    await stores.upsertActive(
      storeId: 'store-1',
      providerType: 's3',
      displayHint: 'hint',
    );
    await MediaStoreAttachState(
      prefs: prefs,
    ).setAttached('store-1', providerType: CloudProviderType.s3);
    expect(await service().compute(), isEmpty);
  });

  test(
    'a device attached to a different store still gets the attach item',
    () async {
      await stores.upsertActive(
        storeId: 'store-NEW',
        providerType: 's3',
        displayHint: 'new store',
      );
      await MediaStoreAttachState(
        prefs: prefs,
      ).setAttached('store-OLD', providerType: CloudProviderType.s3);

      final items = await service().compute();
      expect(items, hasLength(1));
      expect(items.single.kind, SetupItemKind.mediaStoreAttach);
      expect(items.single.key, 'store_store-NEW');
    },
  );

  test(
    'accounts needing sign-in yield items; unavailable kinds are skipped',
    () async {
      await accounts.create(kind: AccountKind.s3, label: 'MinIO');
      await accounts.create(kind: AccountKind.icloud, label: 'iCloud');
      final items = await service().compute();
      expect(items, hasLength(1));
      expect(items.single.kind, SetupItemKind.accountSignIn);
      expect(items.single.label, 'MinIO');
      expect(items.single.accountKind, AccountKind.s3);
      expect(
        items.single.route,
        '/settings/cloud-sync',
        reason: 'no store announced and not the sync account: default route',
      );
    },
  );

  test('signed-in accounts yield no items', () async {
    await accounts.create(kind: AccountKind.s3, label: 'MinIO');
    final items = await service(s3Status: AccountStatus.signedIn).compute();
    expect(items, isEmpty);
  });

  test('an account matching the announced store provider routes to '
      'media storage; the sync account routes to cloud sync', () async {
    final mediaAccount = await accounts.create(
      kind: AccountKind.s3,
      label: 'S3 media storage',
    );
    final syncAccount = await accounts.create(
      kind: AccountKind.dropbox,
      label: 'Dropbox',
    );
    await SyncRepository().setSyncAccount(
      accountId: syncAccount.id,
      providerType: CloudProviderType.dropbox,
    );
    await stores.upsertActive(
      storeId: 'store-1',
      providerType: 's3',
      displayHint: 'hint',
    );
    // Attach so only the sign-in items remain.
    await MediaStoreAttachState(
      prefs: prefs,
    ).setAttached('store-1', providerType: CloudProviderType.s3);

    final svc = PendingSetupService(
      prefs: prefs,
      accounts: accounts,
      stores: stores,
      attachState: MediaStoreAttachState(prefs: prefs),
      registry: AccountProviderRegistry([
        _StatusAdapter(AccountKind.s3, AccountStatus.needsSignIn),
        _StatusAdapter(AccountKind.dropbox, AccountStatus.needsSignIn),
      ]),
    );
    final routes = {
      for (final item in await svc.compute()) item.key: item.route,
    };
    expect(routes['account_${mediaAccount.id}'], '/settings/media-storage');
    expect(routes['account_${syncAccount.id}'], '/settings/cloud-sync');
  });

  test('dismissal is per key and sticks', () async {
    final account = await accounts.create(kind: AccountKind.s3, label: 'M');
    final svc = service();
    expect(await svc.compute(), hasLength(1));

    await svc.dismiss('account_${account.id}');
    expect(await svc.compute(), isEmpty);

    // A different object (new key) still surfaces.
    await accounts.create(kind: AccountKind.s3, label: 'Other');
    expect(await svc.compute(), hasLength(1));
  });
}
