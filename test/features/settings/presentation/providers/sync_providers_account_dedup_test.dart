import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectedAccountsRepository repo;
  late InMemoryKeychain keychain;
  late S3CredentialsStore s3Credentials;

  final config = S3Config(
    endpoint: 'https://minio.local',
    bucket: 'dive-sync',
    prefix: 'submersion-sync/',
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  setUp(() async {
    await setUpTestDatabase();
    repo = ConnectedAccountsRepository();
    keychain = InMemoryKeychain();
    s3Credentials = S3CredentialsStore(storage: keychain);
    await SyncRepository().getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  test('flipping S3 to iCloud and back reuses one S3 row', () async {
    await s3Credentials.save(config);

    final s3First = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );
    await SyncRepository().setSyncAccount(
      accountId: s3First.id,
      providerType: CloudProviderType.s3,
    );

    final icloud = await ensureAccountForProviderType(
      CloudProviderType.icloud,
      repo,
      s3Credentials: s3Credentials,
    );
    await SyncRepository().setSyncAccount(
      accountId: icloud.id,
      providerType: CloudProviderType.icloud,
    );

    final s3Second = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );

    expect(s3Second.id, s3First.id);
    final all = await repo.getAll();
    expect(all.where((a) => a.kind == AccountKind.s3).length, 1);
    expect(all.where((a) => a.kind == AccountKind.icloud).length, 1);
  });

  test('the S3 account uses the deterministic id', () async {
    await s3Credentials.save(config);
    final account = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );
    expect(
      account.id,
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(config)),
    );
  });

  test('an unreadable S3 config still yields an account', () async {
    final account = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );
    expect(account.kind, AccountKind.s3);
    expect((await repo.getAll()).length, 1);
  });

  test('iCloud selected twice reuses one row', () async {
    final first = await ensureAccountForProviderType(
      CloudProviderType.icloud,
      repo,
      s3Credentials: s3Credentials,
    );
    final second = await ensureAccountForProviderType(
      CloudProviderType.icloud,
      repo,
      s3Credentials: s3Credentials,
    );
    expect(second.id, first.id);
    expect((await repo.getAll()).length, 1);
  });
}
