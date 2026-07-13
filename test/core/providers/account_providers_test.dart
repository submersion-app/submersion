import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

import '../../support/fake_keychain_storage.dart';

void main() {
  test(
    'overriding accountCredentialsStoreProvider reaches the S3 adapter',
    () async {
      final keychain = InMemoryKeychain();
      final container = ProviderContainer(
        overrides: [
          accountCredentialsStoreProvider.overrideWithValue(
            AccountCredentialsStore(storage: keychain),
          ),
        ],
      );
      addTearDown(container.dispose);

      final account = domain.ConnectedAccount(
        id: 'acc-s3',
        kind: AccountKind.s3,
        label: 'MinIO',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

      // No blob under the injected store yet -> needsSignIn.
      final adapter = container
          .read(accountProviderRegistryProvider)
          .adapterFor(AccountKind.s3);
      expect(await adapter.status(account), AccountStatus.needsSignIn);

      // Write a valid config through the SAME injected store; the adapter
      // must observe it (proving it shares the overridden instance, not a
      // private default AccountCredentialsStore).
      keychain.values[AccountCredentialsStore.keyFor(account.id)] = jsonEncode(
        S3Config(
          endpoint: 'https://minio.local:9000',
          bucket: 'dive-media',
          accessKeyId: 'AK',
          secretAccessKey: 'SK',
        ).toJson(),
      );
      expect(await adapter.status(account), AccountStatus.signedIn);
    },
  );
}
