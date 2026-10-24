import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

class _NeedsSignInAdapter extends AccountProviderAdapter {
  @override
  AccountKind get kind => AccountKind.s3;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      AccountStatus.needsSignIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}
}

/// The real provider, driven through the ticks that refresh it: the moved
/// tests of the old pending card (issue #2304), plus a backup copy change.
void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountProviderRegistryProvider.overrideWithValue(
          AccountProviderRegistry([_NeedsSignInAdapter()]),
        ),
      ],
    );
    // Kept alive as a showing card keeps it.
    final sub = container.listen(pendingSetupItemsProvider, (_, _) {});
    addTearDown(() {
      sub.close();
      container.dispose();
    });
  });

  tearDown(() => tearDownTestDatabase());

  /// The items once the provider has caught up with the last write.
  Future<List<PendingSetupItem>> items() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(pendingSetupItemsProvider.future);
  }

  Future<void> announce(String storeId, String hint) => MediaStoresRepository()
      .upsertActive(storeId: storeId, providerType: 's3', displayHint: hint);

  test('follows every write while it is watched (issue #2304)', () async {
    expect(await items(), isEmpty);

    await announce('store-1', 'first @ minio');
    expect((await items()).single.label, contains('first'));

    // The same store re-announced under a new hint: a second write that
    // fires the bus.
    await announce('store-1', 'second @ minio');
    expect((await items()).single.label, contains('second'));
  });

  test('a marker mismatch found while watched appears, and a reconnect clears '
      'it', () async {
    final attach = MediaStoreAttachState(prefs: prefs);
    await announce('store-1', 'dive-media @ minio');
    await attach.setAttached('store-1', providerType: CloudProviderType.s3);
    expect(await items(), isEmpty);

    await attach.setMarkerMismatch(true);
    expect((await items()).single.kind, SetupItemKind.mediaStoreReconnect);

    await attach.setAttached('store-1', providerType: CloudProviderType.s3);
    expect(await items(), isEmpty);
  });

  // Issue #3482 review: a backup copy change is a preferences write that
  // fires no bus event, yet it decides which accounts this device uses.
  test('a backup copy turned off drops the sign-in it needed', () async {
    final account = await ConnectedAccountsRepository().create(
      kind: AccountKind.s3,
      label: 'Backups server',
    );
    await prefs.setBool('backup_cloud_enabled', true);
    await prefs.setString('backup_copy_account_id', account.id);
    await prefs.setString('backup_copy_account_kind', 's3');
    await container.read(backupSettingsProvider.notifier).reloadFromDisk();
    container.invalidate(pendingSetupItemsProvider);
    expect((await items()).single.accountId, account.id);

    await container.read(backupSettingsProvider.notifier).setNoCopy();

    expect(await items(), isEmpty);
  });
}
