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
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
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

  /// Makes [account] this device's sync account, a use that needs it signed
  /// in here.
  Future<void> useForSync(domain.ConnectedAccount account) =>
      SyncRepository().setSyncAccount(
        accountId: account.id,
        providerType: CloudProviderType.s3,
      );

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

  // The preflight remembers a store that no longer carries this device's
  // marker; the queue is suspended until the user reconnects (spec 7.1).
  group('marker mismatch', () {
    Future<MediaStoreAttachState> attachedWithMismatch() async {
      await stores.upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'dive-media @ minio',
      );
      final attach = MediaStoreAttachState(prefs: prefs);
      await attach.setAttached('store-1', providerType: CloudProviderType.s3);
      await attach.setMarkerMismatch(true);
      return attach;
    }

    test('offers a reconnect to the media storage page', () async {
      await attachedWithMismatch();

      final items = await service().compute();

      expect(items, hasLength(1));
      expect(items.single.kind, SetupItemKind.mediaStoreReconnect);
      expect(items.single.key, 'store_marker_store-1');
      expect(items.single.label, 'dive-media @ minio');
      expect(items.single.route, '/settings/media-storage');
    });

    test('a dismissed reconnect stays dismissed', () async {
      await attachedWithMismatch();
      await service().dismiss('store_marker_store-1');

      expect(await service().compute(), isEmpty);
    });

    test('no mismatch, no reconnect', () async {
      final attach = await attachedWithMismatch();
      await attach.setMarkerMismatch(false);

      expect(await service().compute(), isEmpty);
    });
  });

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

  test('accounts this device uses yield sign-in items; unavailable kinds are '
      'skipped', () async {
    await useForSync(
      await accounts.create(kind: AccountKind.s3, label: 'MinIO'),
    );
    await accounts.create(kind: AccountKind.icloud, label: 'iCloud');
    final items = await service().compute();
    expect(items, hasLength(1));
    expect(items.single.kind, SetupItemKind.accountSignIn);
    expect(items.single.label, 'MinIO');
    expect(items.single.accountKind, AccountKind.s3);
    expect(items.single.route, '/settings/cloud-sync');
  });

  // Issue #3482 phase 2: reminders only for accounts this device needs
  // (spec section 7.2): another device's server asks for nothing here.
  test('a roster row nothing here uses raises no sign-in item', () async {
    await accounts.create(kind: AccountKind.s3, label: 'Another device');
    expect(await service().compute(), isEmpty);
  });

  // Issue #3522: prompts name accounts and stores by their short names.
  group('names', () {
    const r2 =
        'sync @ 149b84f66d5479265f3e4d4ad4740926.r2.cloudflarestorage.com';

    test('a sign-in item uses the nickname, else the short label', () async {
      final named = await accounts.create(kind: AccountKind.s3, label: r2);
      await accounts.setNickname(named.id, 'Club bucket');
      await useForSync(named);
      final photos = await accounts.create(
        kind: AccountKind.s3,
        label: 'photos @ s3.eu-west-1.amazonaws.com',
      );
      // Only accounts this device uses ask for a sign-in (#3482).
      await MediaStoreAttachState(prefs: prefs).setAttached(
        'store-x',
        providerType: CloudProviderType.s3,
        accountId: photos.id,
      );
      final items = await service().compute();
      expect(items.map((i) => i.label).toSet(), {
        'Club bucket',
        'photos @ Amazon S3',
      });
    });

    test('a store item uses the short label', () async {
      await stores.upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: r2,
      );
      final items = await service().compute();
      expect(items.single.label, 'sync @ Cloudflare R2');
    });
  });

  test('signed-in accounts yield no items', () async {
    await useForSync(
      await accounts.create(kind: AccountKind.s3, label: 'MinIO'),
    );
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
    // Attach through the media account so only the sign-in items remain.
    await MediaStoreAttachState(prefs: prefs).setAttached(
      'store-1',
      providerType: CloudProviderType.s3,
      accountId: mediaAccount.id,
    );

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

  // Issue #3388: routing reads the same usage map as the Connected Accounts
  // page, so the account this device is attached through goes to Media
  // Storage even when the announced store has since moved to another kind.
  // Review of #3527: a library's account was sent to Media Storage when the
  // announced store was of the same kind; its own account page signs it in.
  test('a library\'s account routes to its account page', () async {
    final account = await accounts.create(kind: AccountKind.s3, label: 'Club');
    await SharedLibraryStore().upsertLibrary(
      SharedLibrary(
        id: 'lib',
        name: 'Reef',
        connectedAccountId: account.id,
        prefix: 'submersion-sites/reef',
      ),
    );
    final items = await service().compute();
    expect(items.single.route, '/settings/connected-accounts/${account.id}');
  });

  test('the attached media account routes to media storage', () async {
    final mediaAccount = await accounts.create(
      kind: AccountKind.s3,
      label: 'S3 media storage',
    );
    await stores.upsertActive(
      storeId: 'store-2',
      providerType: 'dropbox',
      displayHint: 'hint',
    );
    await MediaStoreAttachState(prefs: prefs).setAttached(
      'store-1',
      providerType: CloudProviderType.s3,
      accountId: mediaAccount.id,
    );
    await service().dismiss('store_store-2');

    final items = await service().compute();

    expect(items.single.key, 'account_${mediaAccount.id}');
    expect(items.single.route, '/settings/media-storage');
  });

  test('dismissal is per key and sticks', () async {
    final account = await accounts.create(kind: AccountKind.s3, label: 'M');
    await useForSync(account);
    final svc = service();
    expect(await svc.compute(), hasLength(1));

    await svc.dismiss('account_${account.id}');
    expect((await svc.compute()).where((i) => !i.dismissed), isEmpty);

    // A different object (new key) still surfaces.
    await useForSync(
      await accounts.create(kind: AccountKind.s3, label: 'Other'),
    );
    expect((await svc.compute()).where((i) => !i.dismissed), hasLength(1));
  });

  // Issue #3482 review: dismissing the prompt hides the card entry, but the
  // account still needs a sign-in, and the Settings > Data accounts row must
  // keep saying so instead of listing it as fine.
  test('a dismissed sign-in stays listed, flagged as dismissed', () async {
    final account = await accounts.create(kind: AccountKind.s3, label: 'M');
    await useForSync(account);
    final svc = service();
    expect((await svc.compute()).single.dismissed, isFalse);

    await svc.dismiss('account_${account.id}');

    final item = (await svc.compute()).single;
    expect(item.kind, SetupItemKind.accountSignIn);
    expect(item.dismissed, isTrue);
  });
}
