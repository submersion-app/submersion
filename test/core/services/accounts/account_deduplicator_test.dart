import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_deduplicator.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

/// Fails the very first read the pass makes, so run()'s guarantee that a
/// dedup failure cannot block startup is exercised end to end.
class _ThrowingAccounts extends ConnectedAccountsRepository {
  @override
  Future<List<domain.ConnectedAccount>> getAll() async =>
      throw StateError('keychain unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ConnectedAccountsRepository accounts;
  late InMemoryKeychain keychain;
  late AccountCredentialsStore credentials;
  late S3CredentialsStore syncS3;
  late S3CredentialsStore mediaS3;

  final syncConfig = S3Config(
    endpoint: 'https://149b84f6.r2.cloudflarestorage.com',
    bucket: 'submersion-sync',
    prefix: 'submersion-sync/',
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  String syncCanonicalId() =>
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(syncConfig));

  Future<AccountDeduplicator> dedup(SharedPreferences prefs) async =>
      AccountDeduplicator(
        prefs: prefs,
        accounts: accounts,
        credentials: credentials,
        syncRepository: SyncRepository(),
        established: EstablishedProviderStore(prefs),
        syncS3: syncS3,
        mediaS3: mediaS3,
      );

  Future<int> deletionCount() async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM deletion_log "
          "WHERE entity_type = 'connectedAccounts'",
        )
        .getSingle();
    return row.data['c'] as int;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    accounts = ConnectedAccountsRepository();
    keychain = InMemoryKeychain();
    credentials = AccountCredentialsStore(storage: keychain);
    syncS3 = S3CredentialsStore(
      storage: keychain,
      storageKey: 'sync_s3_config',
    );
    mediaS3 = S3CredentialsStore(
      storage: keychain,
      storageKey: 'media_store_s3_config',
    );
    await SyncRepository().getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  test('collapses the observed duplicate roster', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);

    const label = 'submersion-sync @ 149b84f6.r2.cloudflarestorage.com';
    final s3Ids = <String>[];
    for (var i = 0; i < 9; i++) {
      final a = await accounts.create(kind: AccountKind.s3, label: label);
      s3Ids.add(a.id);
    }
    for (var i = 0; i < 2; i++) {
      await accounts.create(kind: AccountKind.icloud, label: 'iCloud');
    }
    await credentials.write(s3Ids.first, '{"blob":"sync"}');
    await SyncRepository().setSyncAccount(
      accountId: s3Ids.first,
      providerType: CloudProviderType.s3,
    );

    await (await dedup(prefs)).run();

    final remaining = await accounts.getAll();
    expect(remaining.length, 1);
    expect(remaining.single.id, syncCanonicalId());
    expect(remaining.single.label, label);
    expect(await SyncRepository().getSyncAccountId(), syncCanonicalId());
    expect(await credentials.read(syncCanonicalId()), '{"blob":"sync"}');
    // All 11 legacy rows are tombstoned, including the anchor: its id
    // genuinely changes, so the canonical row is a new row rather than a
    // rename of the anchor.
    expect(await deletionCount(), 11);
  });

  test('is a no-op on a second run', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);
    final a = await accounts.create(kind: AccountKind.s3, label: 'x');
    await SyncRepository().setSyncAccount(
      accountId: a.id,
      providerType: CloudProviderType.s3,
    );

    await (await dedup(prefs)).run();
    final afterFirst = await deletionCount();
    await (await dedup(prefs)).run();

    expect(await deletionCount(), afterFirst);
    expect((await accounts.getAll()).length, 1);
  });

  test('keeps a sync and a media anchor that differ by prefix', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);
    final mediaConfig = S3Config(
      endpoint: syncConfig.endpoint,
      bucket: syncConfig.bucket,
      prefix: 'media/',
      accessKeyId: 'AK',
      secretAccessKey: 'SK',
    );
    await mediaS3.save(mediaConfig);

    const label = 'submersion-sync @ 149b84f6.r2.cloudflarestorage.com';
    final syncRow = await accounts.create(kind: AccountKind.s3, label: label);
    final mediaRow = await accounts.create(kind: AccountKind.s3, label: label);
    await SyncRepository().setSyncAccount(
      accountId: syncRow.id,
      providerType: CloudProviderType.s3,
    );
    await prefs.setString('media_store_account_id', mediaRow.id);

    await (await dedup(prefs)).run();

    final remaining = await accounts.getAll();
    expect(remaining.length, 2);
    expect(remaining.map((a) => a.id).toSet(), {
      syncCanonicalId(),
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(mediaConfig)),
    });
    expect(prefs.getString('media_store_account_id'), isNot(mediaRow.id));
  });

  test('leaves Lightroom rows untouched', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lr = await accounts.create(
      kind: AccountKind.adobeLightroom,
      label: 'Lightroom',
      accountIdentifier: 'catalog-1',
      id: 'preserved-lightroom-id',
    );
    final lr2 = await accounts.create(
      kind: AccountKind.adobeLightroom,
      label: 'Lightroom',
      accountIdentifier: 'catalog-2',
    );

    await (await dedup(prefs)).run();

    final ids = (await accounts.getAll()).map((a) => a.id).toSet();
    expect(ids, containsAll([lr.id, lr2.id]));
    expect(await deletionCount(), 0);
  });

  test(
    'keeps an anchor whose S3 config is unreadable, drops inert rows',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const label = 'submersion-sync @ 149b84f6.r2.cloudflarestorage.com';
      final anchor = await accounts.create(kind: AccountKind.s3, label: label);
      await accounts.create(kind: AccountKind.s3, label: label);
      await accounts.create(kind: AccountKind.s3, label: label);
      await SyncRepository().setSyncAccount(
        accountId: anchor.id,
        providerType: CloudProviderType.s3,
      );

      await (await dedup(prefs)).run();

      final remaining = await accounts.getAll();
      expect(remaining.length, 1);
      expect(remaining.single.id, anchor.id);
      expect(await SyncRepository().getSyncAccountId(), anchor.id);
      expect(await deletionCount(), 2);
    },
  );

  test('carries an established marker onto the canonical id', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await syncS3.save(syncConfig);
    final anchor = await accounts.create(kind: AccountKind.s3, label: 'x');
    await SyncRepository().setSyncAccount(
      accountId: anchor.id,
      providerType: CloudProviderType.s3,
    );
    final established = EstablishedProviderStore(prefs);
    await established.add(anchor.id);

    await (await dedup(prefs)).run();

    expect(established.contains(syncCanonicalId()), isTrue);
  });

  test('canonicalizes a managed-kind sync anchor', () async {
    // The observed real-world roster had iCloud as the sync anchor, not S3:
    // sync_metadata pointed at one of the two duplicate iCloud rows.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = await accounts.create(
      kind: AccountKind.icloud,
      label: 'iCloud',
    );
    await accounts.create(kind: AccountKind.icloud, label: 'iCloud');
    await SyncRepository().setSyncAccount(
      accountId: first.id,
      providerType: CloudProviderType.icloud,
    );

    await (await dedup(prefs)).run();

    final canonical = accountIdFor(
      kind: AccountKind.icloud,
      naturalKey: 'icloud',
    );
    final remaining = await accounts.getAll();
    expect(remaining.length, 1);
    expect(remaining.single.id, canonical);
    expect(await SyncRepository().getSyncAccountId(), canonical);
  });

  test('a failure never blocks startup', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final failing = AccountDeduplicator(
      prefs: prefs,
      accounts: _ThrowingAccounts(),
      credentials: credentials,
      syncRepository: SyncRepository(),
      established: EstablishedProviderStore(prefs),
      syncS3: syncS3,
      mediaS3: mediaS3,
    );

    // Swallowed, not rethrown: startup must proceed.
    await expectLater(failing.run(), completes);
  });

  test('does nothing when there is nothing to collapse', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await (await dedup(prefs)).run();
    expect(await accounts.getAll(), isEmpty);
    expect(await deletionCount(), 0);
  });
}
