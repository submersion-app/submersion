import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../helpers/test_database.dart';
import '../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectedAccountsRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = ConnectedAccountsRepository();
    await SyncRepository().getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  test(
    'ensureAccountForProviderType creates then reuses the kind account',
    () async {
      final first = await ensureAccountForProviderType(
        CloudProviderType.dropbox,
        repo,
      );
      expect(first.kind, AccountKind.dropbox);
      expect(first.label, 'Dropbox');

      final second = await ensureAccountForProviderType(
        CloudProviderType.dropbox,
        repo,
      );
      expect(second.id, first.id, reason: 'kind accounts are single-instance');
    },
  );

  test('selectedSyncAccountProvider derives the account and persists the '
      'selection to sync metadata', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.s3;

    final account = await container.read(selectedSyncAccountProvider.future);
    expect(account, isNotNull);
    expect(account!.kind, AccountKind.s3);
    expect(await SyncRepository().getSyncAccountId(), account.id);
  });

  test('selectedSyncAccountProvider is null without a selected type', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(selectedSyncAccountProvider.future), isNull);
  });

  test('selectedSyncAccountProvider mirrors the legacy S3 blob into the '
      'per-account key (for account-first resolution)', () async {
    final keychain = InMemoryKeychain();
    // The connect UI writes the legacy key; the derivation must mirror it.
    keychain.values[S3CredentialsStore.storageKey] = jsonEncode(
      S3Config(
        endpoint: 'https://minio.local:9000',
        bucket: 'dive-media',
        accessKeyId: 'AK',
        secretAccessKey: 'SK',
      ).toJson(),
    );
    final container = ProviderContainer(
      overrides: [
        accountCredentialsStoreProvider.overrideWithValue(
          AccountCredentialsStore(storage: keychain),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.s3;
    final account = await container.read(selectedSyncAccountProvider.future);

    expect(account, isNotNull);
    expect(
      keychain.values[AccountCredentialsStore.keyFor(account!.id)],
      isNotNull,
      reason: 'legacy S3 blob mirrored to the per-account key',
    );
  });

  test('a Google Drive selection does not attempt a credential mirror '
      '(session-managed, no keychain blob)', () async {
    final keychain = InMemoryKeychain();
    final container = ProviderContainer(
      overrides: [
        accountCredentialsStoreProvider.overrideWithValue(
          AccountCredentialsStore(storage: keychain),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.googledrive;
    final account = await container.read(selectedSyncAccountProvider.future);

    expect(account, isNotNull);
    expect(
      keychain.values[AccountCredentialsStore.keyFor(account!.id)],
      isNull,
      reason: 'no legacy blob to mirror for session-managed kinds',
    );
  });

  test(
    'an S3 sync selection never adopts an existing (media) S3 account',
    () async {
      final mediaS3 = await repo.create(
        kind: AccountKind.s3,
        label: 'S3 media storage',
      );

      final syncAccount = await ensureAccountForProviderType(
        CloudProviderType.s3,
        repo,
      );
      expect(
        syncAccount.id,
        isNot(mediaS3.id),
        reason: 'sync-S3 and media-S3 are distinct accounts by design',
      );
    },
  );

  test('a persisted sync account of the same kind is preferred', () async {
    final first = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
    );
    await SyncRepository().setSyncAccount(
      accountId: first.id,
      providerType: CloudProviderType.s3,
    );

    final second = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
    );
    expect(second.id, first.id, reason: 'no duplicate account per re-derive');
  });
}
