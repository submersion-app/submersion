import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/git_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  final config = GitConfig(
    repoUrl: 'https://github.com/you/dive-log',
    username: 'you',
    token: 'ghp_secret',
  );
  final account = ConnectedAccount(
    id: accountIdFor(kind: AccountKind.git, naturalKey: gitNaturalKey(config)),
    kind: AccountKind.git,
    label: config.displayLabel,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('Git maps both ways between account kind and provider type', () {
    expect(AccountKind.git.cloudProviderType, CloudProviderType.git);
    expect(
      AccountKind.fromCloudProviderType(CloudProviderType.git),
      AccountKind.git,
    );
  });

  test(
    'status follows the per-account blob; it syncs but stores no media',
    () async {
      final adapter = GitAccountAdapter(
        credentials: AccountCredentialsStore(storage: InMemoryKeychain()),
        legacySync: GitCredentialsStore(storage: InMemoryKeychain()),
      );
      expect(adapter.kind, AccountKind.git);
      expect(adapter, isA<SyncCapable>());
      expect(adapter, isNot(isA<MediaStoreCapable>()));
      expect(await adapter.status(account), AccountStatus.needsSignIn);
      await adapter.saveConfig(account, config);
      expect(await adapter.status(account), AccountStatus.signedIn);
      expect((await adapter.loadConfig(account))!.toJson(), config.toJson());
      expect(adapter.syncProvider(account), isA<GitStorageProvider>());
      await adapter.disconnect(account);
      expect(await adapter.status(account), AccountStatus.needsSignIn);
    },
  );

  test(
    'disconnecting the sync account clears the sync settings blob too',
    () async {
      final keychain = InMemoryKeychain();
      final legacy = GitCredentialsStore(storage: keychain);
      await legacy.save(config);
      final adapter = GitAccountAdapter(
        credentials: AccountCredentialsStore(storage: keychain),
        legacySync: legacy,
      );
      final other = ConnectedAccount(
        id: accountIdFor(
          kind: AccountKind.git,
          naturalKey: gitNaturalKey(config.copyWith(branch: 'other')),
        ),
        kind: AccountKind.git,
        label: 'o',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await adapter.disconnect(other);
      expect(
        await legacy.load(),
        isNotNull,
        reason: 'another branch leaves sync alone',
      );
      await adapter.disconnect(account);
      expect(await legacy.load(), isNull);
    },
  );
}
