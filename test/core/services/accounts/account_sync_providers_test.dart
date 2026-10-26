// Issue #3482 phase 3: the scheduled backup builds the chosen account's
// provider from its roster id alone, through the same constructors the
// account adapters use.

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_sync_providers.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';

import '../../../support/fake_cloud_storage_provider.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  test('an S3 row reads its own per-account key, not the sync one', () async {
    final keychain = InMemoryKeychain();
    await S3CredentialsStore(
      storage: keychain,
      storageKey: AccountCredentialsStore.keyFor('acct-b'),
    ).save(
      S3Config(
        endpoint: 'https://minio.home',
        bucket: 'copies',
        accessKeyId: 'k',
        secretAccessKey: 's',
      ),
    );
    await S3CredentialsStore(storage: keychain).save(
      S3Config(
        endpoint: 'https://minio.home',
        bucket: 'sync',
        accessKeyId: 'k',
        secretAccessKey: 's',
      ),
    );

    final provider =
        accountSyncProvider(AccountKind.s3, 'acct-b', storage: keychain)
            as S3StorageProvider;

    expect((await provider.loadConfig())?.bucket, 'copies');
  });

  test('a Dropbox row gets a Dropbox provider', () {
    expect(
      accountSyncProvider(
        AccountKind.dropbox,
        'acct-d',
        storage: InMemoryKeychain(),
      ),
      isA<DropboxStorageProvider>(),
    );
  });

  test('a Git row gets a Git provider', () {
    expect(
      accountSyncProvider(
        AccountKind.git,
        'acct-r',
        storage: InMemoryKeychain(),
      ),
      isA<GitStorageProvider>(),
    );
  });

  test('session kinds use the per-type instance', () {
    final built = <CloudProviderType>[];
    final provider = accountSyncProvider(
      AccountKind.googledrive,
      'acct-g',
      instanceFor: (type) {
        built.add(type);
        return FakeCloudStorageProvider(providerId: type.name);
      },
    );
    expect(built, [CloudProviderType.googledrive]);
    expect(provider!.providerId, 'googledrive');
  });

  test('Lightroom holds no files', () {
    expect(accountSyncProvider(AccountKind.adobeLightroom, 'acct-l'), isNull);
  });
}
