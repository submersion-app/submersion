// Issue #3482 phase 2: a library's server comes from the account sheet; its
// own roster row, which carries the library folder, is resolved from the
// server and the folder.

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
import 'package:submersion/features/shared_library/presentation/widgets/library_location_fields.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  late ConnectedAccountsRepository accounts;
  late AccountCredentialsStore credentials;
  late AccountGroupService service;

  S3Config s3(String prefix, {String key = 'AKIA1'}) => S3Config(
    endpoint: 'https://minio.home:9000',
    bucket: 'dives',
    prefix: prefix,
    accessKeyId: key,
    secretAccessKey: 'shh',
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

  Future<ConnectedAccount> row(S3Config c, {bool signedIn = true}) async {
    final a = await accounts.ensure(
      kind: AccountKind.s3,
      naturalKey: s3NaturalKey(c),
      label: c.bucket,
      location: S3AccountLocation.fromConfig(c),
    );
    if (signedIn) await credentials.write(a.id, jsonEncode(c.toJson()));
    return (await accounts.getById(a.id))!;
  }

  AccountGroup groupOf(
    List<ConnectedAccount> rows, {
    Set<String> keyless = const {},
  }) => groupAccounts(
    rows: rows,
    statusById: {
      for (final r in rows)
        r.id: keyless.contains(r.id)
            ? AccountStatus.needsSignIn
            : AccountStatus.signedIn,
    },
    localLocationById: const {},
    usagesOf: (_) => const [],
  ).single;

  Future<S3Config> storedFor(String id) async =>
      S3Config.fromJson(jsonDecode((await credentials.read(id))!));

  test(
    'a new folder on a signed-in server gets a library row of its own',
    () async {
      final sync = await row(s3('submersion-sync/'));
      final c = LibraryLocationController(initialPrefix: 'reef')
        ..selectServer(groupOf([sync]));
      addTearDown(c.dispose);

      final account = (await c.resolveAccount(service))!;

      expect(
        account.id,
        accountIdFor(
          kind: AccountKind.s3,
          naturalKey: s3NaturalKey(s3('submersion-sites/reef/')),
        ),
      );
      expect((await storedFor(account.id)).accessKeyId, 'AKIA1');
    },
  );

  test('a row already there for the folder is used, keys left alone', () async {
    final sync = await row(s3('submersion-sync/'));
    // The library's row exists (another device made it) but holds no keys
    // here: it must not be overwritten with the diver's own sync keys.
    final lib = await row(s3('submersion-sites/reef/'), signedIn: false);
    final c = LibraryLocationController(initialPrefix: 'reef')
      ..selectServer(groupOf([sync, lib]));
    addTearDown(c.dispose);

    final account = (await c.resolveAccount(service))!;

    expect(account.id, lib.id);
    expect(await credentials.read(lib.id), isNull);
  });

  test('the library\'s own row stays while nothing changed', () async {
    // Not signed in here: a new row could not be made, the old one is kept.
    final lib = await row(s3('submersion-sites/reef/'), signedIn: false);
    final c = LibraryLocationController()
      ..seed(folder: 'site-sync', accountId: lib.id)
      ..selectServer(groupOf([lib]));
    addTearDown(c.dispose);

    expect((await c.resolveAccount(service))!.id, lib.id);
  });

  test('a row nothing here can place is used as is', () async {
    final legacy = await accounts.create(kind: AccountKind.s3, label: 'old');
    final c = LibraryLocationController(initialPrefix: 'reef')
      ..selectServer(groupOf([legacy]));
    addTearDown(c.dispose);

    expect((await c.resolveAccount(service))!.id, legacy.id);
  });

  test('with no server chosen there is no account', () async {
    final c = LibraryLocationController(initialPrefix: 'reef');
    addTearDown(c.dispose);
    expect(await c.resolveAccount(service), isNull);
  });

  // Review of #3527: a check saves nothing; every folder tried used to leave
  // a synced roster row behind.
  test('a check goes through a signed-in row and saves nothing', () async {
    final sync = await row(s3('submersion-sync/'));
    final c = LibraryLocationController(initialPrefix: 'reef')
      ..selectServer(groupOf([sync]));
    addTearDown(c.dispose);
    final before = (await accounts.getAll()).length;

    final probed = c.probeAccount()!;

    expect(probed.id, sync.id);
    expect((await accounts.getAll()).length, before);
  });

  test('a check with nothing signed in on the server says so', () async {
    final lib = await row(s3('submersion-sites/reef/'), signedIn: false);
    final other = await row(s3('submersion-sync/'), signedIn: false);
    final c = LibraryLocationController(initialPrefix: 'wrecks')
      ..selectServer(groupOf([lib, other], keyless: {lib.id, other.id}));
    addTearDown(c.dispose);

    expect(c.probeAccount, throwsStateError);
  });

  test('a folder typed with extra slashes finds its row', () async {
    final sync = await row(s3('submersion-sync/'));
    final lib = await row(s3('submersion-sites/reef/team/'), signedIn: false);
    final c = LibraryLocationController(initialPrefix: 'reef//team')
      ..selectServer(groupOf([sync, lib]));
    addTearDown(c.dispose);

    expect((await c.resolveAccount(service))!.id, lib.id);
    expect(await credentials.read(lib.id), isNull);
  });
}
