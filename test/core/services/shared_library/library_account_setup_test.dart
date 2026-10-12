import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/shared_library/library_account_setup.dart';

import '../../../helpers/fake_webdav_server.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  late AccountCredentialsStore credentials;
  late LibraryAccountSetup setup;

  setUp(() async {
    await setUpTestDatabase();
    credentials = AccountCredentialsStore(storage: InMemoryKeychain());
    setup = LibraryAccountSetup(credentials: credentials);
  });

  tearDown(tearDownTestDatabase);

  S3Config s3({String key = 'AKIACLUB'}) => S3Config(
    endpoint: 'https://s3.eu-west-1.amazonaws.com',
    region: 'eu-west-1',
    bucket: 'submersion-sync',
    accessKeyId: key,
    secretAccessKey: 'secret',
  );

  test(
    'an S3 account for libraries never takes over the sync account',
    () async {
      // The bucket's personal sync account, with its own keys.
      final syncId = accountIdFor(
        kind: AccountKind.s3,
        naturalKey: s3NaturalKey(s3(key: 'AKIASYNC')),
      );
      await credentials.write(syncId, jsonEncode(s3(key: 'AKIASYNC').toJson()));

      final account = await setup.saveS3(s3());

      expect(account.kind, AccountKind.s3);
      expect(account.id, isNot(syncId));
      // Told apart from the sync account in the picker, which shares the
      // bucket and so the 'bucket @ host' label.
      final label = (await ConnectedAccountsRepository().getById(
        account.id,
      ))?.label;
      expect(label, contains('submersion-sync'));
      expect(label, contains('submersion-sites'));
      expect(label, isNot('submersion-sync @ s3.eu-west-1.amazonaws.com'));
      final stored = jsonDecode((await credentials.read(account.id))!) as Map;
      expect(stored['accessKeyId'], 'AKIACLUB');
      expect(stored['prefix'], 'submersion-sites/');
      final sync = jsonDecode((await credentials.read(syncId))!) as Map;
      expect(sync['accessKeyId'], 'AKIASYNC', reason: 'sync keys untouched');
    },
  );

  test('a WebDAV account for libraries keeps its own folder', () async {
    final account = await setup.saveWebDav(
      WebDavConfig(
        serverUrl: 'https://dav.example.com/remote.php/dav/files/ann',
        username: 'ann',
        password: 'pw',
      ),
    );
    expect(account.kind, AccountKind.webdav);
    final stored = jsonDecode((await credentials.read(account.id))!) as Map;
    expect(stored['folder'], 'submersion-sites');
    expect(stored['username'], 'ann');
    expect(account.label, 'ann @ dav.example.com (submersion-sites)');
  });

  group('reachWebDav', () {
    late FakeWebDavServer server;

    setUp(() {
      server = FakeWebDavServer();
      setup = LibraryAccountSetup(
        credentials: credentials,
        webdavClient: (c) => WebDavClient(
          c,
          httpClient: server.client,
          backoff: (_) => Duration.zero,
        ),
      );
    });

    WebDavConfig at(String url) =>
        WebDavConfig(serverUrl: url, username: 'alice', password: 'secret');

    test('reaches the server without writing to it', () async {
      // A club may hand out a login that can only read.
      final config = at('https://dav.test/dav');
      expect(await setup.reachWebDav(config), config);
      expect(
        server.captured.map((r) => r.method),
        everyElement(isIn(['PROPFIND', 'GET', 'HEAD', 'OPTIONS'])),
      );
    });

    test('an address with no WebDAV folder is refused', () async {
      await expectLater(
        setup.reachWebDav(at('https://dav.test/nothing')),
        throwsA(isA<WebDavException>()),
      );
    });
  });
}
