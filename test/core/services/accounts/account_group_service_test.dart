// Issue #3482 phase 2: signing in, adding a role, signing out and removing
// act on an account, which may be several roster rows (spec section 7.2).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_group_service.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  late ConnectedAccountsRepository accounts;
  late AccountCredentialsStore credentials;
  late AccountGroupService service;

  S3Config s3(String prefix, {String key = 'AKIA1', String secret = 'shh'}) =>
      S3Config(
        endpoint: 'https://minio.home:9000',
        bucket: 'dives',
        prefix: prefix,
        accessKeyId: key,
        secretAccessKey: secret,
      );

  setUp(() async {
    await setUpTestDatabase();
    accounts = ConnectedAccountsRepository();
    credentials = AccountCredentialsStore(storage: InMemoryKeychain());
    service = AccountGroupService(
      accounts: accounts,
      credentials: credentials,
      registry: AccountProviderRegistry([
        S3AccountAdapter(credentials: credentials),
      ]),
    );
  });

  tearDown(tearDownTestDatabase);

  /// A roster row for [config] carrying its location and no credentials,
  /// as a second device sees a row another device added.
  Future<ConnectedAccount> rowFor(S3Config config) => accounts.ensure(
    kind: AccountKind.s3,
    naturalKey: s3NaturalKey(config),
    label: '${config.bucket} @ ${config.displayHost}',
    location: S3AccountLocation.fromConfig(config),
  );

  Future<AccountGroup> groupOf(List<ConnectedAccount> rows) async {
    final fresh = [for (final r in rows) (await accounts.getById(r.id))!];
    return groupAccounts(
      rows: fresh,
      statusById: {for (final r in fresh) r.id: AccountStatus.needsSignIn},
      localLocationById: const {},
      usagesOf: (_) => const [],
    ).single;
  }

  Future<S3Config?> stored(String id) async {
    final raw = await credentials.read(id);
    return raw == null ? null : S3Config.fromJson(jsonDecode(raw));
  }

  test('signing in writes each row its own folder', () async {
    final sync = await rowFor(s3('submersion-sync/'));
    final lib = await rowFor(s3('submersion-sites/reef-team/'));
    final group = await groupOf([sync, lib]);

    final signedIn = await service.storeServerSecret(
      group,
      const S3Secret(accessKeyId: 'AKIA2', secretAccessKey: 'new'),
    );

    expect(signedIn, 2);
    expect((await stored(sync.id))!.prefix, 'submersion-sync/');
    expect((await stored(lib.id))!.prefix, 'submersion-sites/reef-team/');
    expect((await stored(lib.id))!.accessKeyId, 'AKIA2');
  });

  test('a row whose rebuilt config hashes elsewhere is skipped', () async {
    final sync = await rowFor(s3('submersion-sync/'));
    // A location that names another folder than the row's id was made from.
    await accounts.setLocation(
      sync.id,
      S3AccountLocation.fromConfig(s3('submersion-media/')),
    );
    final group = await groupOf([sync]);

    final signedIn = await service.storeServerSecret(
      group,
      const S3Secret(accessKeyId: 'AKIA2', secretAccessKey: 'new'),
    );

    expect(signedIn, 0);
    expect(await credentials.read(sync.id), isNull);
  });

  test('adding a library role reuses the group\'s credentials', () async {
    final sync = await rowFor(s3('submersion-sync/'));
    await credentials.write(
      sync.id,
      jsonEncode(s3('submersion-sync/').toJson()),
    );
    final group = await groupOf([sync]);

    final lib = await service.ensureRole(
      group,
      AccountRole.library,
      libraryFolder: 'reef-team',
    );

    expect(
      lib.id,
      accountIdFor(
        kind: AccountKind.s3,
        naturalKey: s3NaturalKey(s3('submersion-sites/reef-team/')),
      ),
    );
    expect((await stored(lib.id))!.accessKeyId, 'AKIA1');
    expect(lib.location!.serverKey, group.locationOf(sync.id)!.serverKey);
  });

  test('adding a role with no credentials here throws', () async {
    final sync = await rowFor(s3('submersion-sync/'));
    final group = await groupOf([sync]);
    expect(
      () => service.ensureRole(group, AccountRole.media),
      throwsStateError,
    );
  });

  test('saving a new server creates its sync-role row', () async {
    final row = await service.saveOwnServer(s3: s3('submersion-sync/'));
    expect(
      row.id,
      accountIdFor(
        kind: AccountKind.s3,
        naturalKey: s3NaturalKey(s3('submersion-sync/')),
      ),
    );
    expect(row.location, isA<S3AccountLocation>());
    expect((await stored(row.id))!.secretAccessKey, 'shh');
  });

  test('removing an account deletes every row and its credentials', () async {
    final sync = await rowFor(s3('submersion-sync/'));
    final lib = await rowFor(s3('submersion-sites/reef-team/'));
    await credentials.write(
      sync.id,
      jsonEncode(s3('submersion-sync/').toJson()),
    );
    final group = await groupOf([sync, lib]);

    await service.remove(group);

    expect(await accounts.getAll(), isEmpty);
    expect(await credentials.read(sync.id), isNull);
  });

  test('signing out keeps the rows and drops the credentials', () async {
    final sync = await rowFor(s3('submersion-sync/'));
    await credentials.write(
      sync.id,
      jsonEncode(s3('submersion-sync/').toJson()),
    );
    final group = await groupOf([sync]);

    await service.signOut(group);

    expect(await accounts.getAll(), hasLength(1));
    expect(await credentials.read(sync.id), isNull);
  });
}
