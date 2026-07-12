import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../helpers/test_database.dart';

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
