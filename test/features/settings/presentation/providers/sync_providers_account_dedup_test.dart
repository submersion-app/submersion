import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
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

  // Review of #3527: a sync row persisted before locations returns early,
  // so it never got one and other devices listed the server twice.
  test('a persisted sync row without a location gets one', () async {
    await s3Credentials.save(config);
    final row = await repo.ensureById(
      id: accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(config)),
      kind: AccountKind.s3,
      label: 'dive-sync @ minio.local',
    );
    await SyncRepository().setSyncAccount(
      accountId: row.id,
      providerType: CloudProviderType.s3,
    );
    expect((await repo.getById(row.id))!.location, isNull);

    final derived = await ensureAccountForProviderType(
      CloudProviderType.s3,
      repo,
      s3Credentials: s3Credentials,
    );

    expect(derived.id, row.id);
    expect((await repo.getById(row.id))!.location, isNotNull);
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
  test('Git resolves to one account per repository and branch', () async {
    final legacy = GitCredentialsStore(storage: keychain);
    final config = GitConfig(
      repoUrl: 'https://github.com/you/dive-log',
      username: 'you',
      token: 'ghp_secret',
    );
    await legacy.save(config);
    final first = await ensureAccountForProviderType(
      CloudProviderType.git,
      repo,
      gitCredentials: legacy,
    );
    expect(first.kind, AccountKind.git);
    expect(
      first.id,
      accountIdFor(kind: AccountKind.git, naturalKey: gitNaturalKey(config)),
    );
    expect(first.label, 'you/dive-log @ github.com');
    await SyncRepository().setSyncAccount(
      accountId: first.id,
      providerType: CloudProviderType.git,
    );
    final again = await ensureAccountForProviderType(
      CloudProviderType.git,
      repo,
      gitCredentials: legacy,
    );
    expect(again.id, first.id);

    await legacy.save(config.copyWith(branch: 'elsewhere'));
    final moved = await ensureAccountForProviderType(
      CloudProviderType.git,
      repo,
      gitCredentials: legacy,
    );
    expect(moved.id, isNot(first.id));
  });

  test(
    'WebDAV resolves to the deterministic account for its endpoint',
    () async {
      final keychain = InMemoryKeychain();
      final legacy = WebDavCredentialsStore(storage: keychain);
      final config = WebDavConfig(
        serverUrl: 'https://dav.test/dav',
        username: 'alice',
        password: 'secret',
      );
      await legacy.save(config);

      final account = await ensureAccountForProviderType(
        CloudProviderType.webdav,
        repo,
        webdavCredentials: legacy,
      );
      expect(account.kind, AccountKind.webdav);
      expect(
        account.id,
        accountIdFor(
          kind: AccountKind.webdav,
          naturalKey: webdavNaturalKey(config),
        ),
      );
      expect(account.label, 'alice @ dav.test');
    },
  );

  test(
    'editing the WebDAV server moves sync to the new endpoint account',
    () async {
      final legacy = WebDavCredentialsStore(storage: keychain);
      final first = WebDavConfig(
        serverUrl: 'https://dav.test/dav',
        username: 'alice',
        password: 'secret',
      );
      await legacy.save(first);
      final before = await ensureAccountForProviderType(
        CloudProviderType.webdav,
        repo,
        webdavCredentials: legacy,
      );
      await SyncRepository().setSyncAccount(
        accountId: before.id,
        providerType: CloudProviderType.webdav,
      );

      final moved = first.copyWith(folder: 'Elsewhere');
      await legacy.save(moved);
      final after = await ensureAccountForProviderType(
        CloudProviderType.webdav,
        repo,
        webdavCredentials: legacy,
      );
      expect(after.id, isNot(before.id));
      expect(
        after.id,
        accountIdFor(
          kind: AccountKind.webdav,
          naturalKey: webdavNaturalKey(moved),
        ),
      );
    },
  );
}
