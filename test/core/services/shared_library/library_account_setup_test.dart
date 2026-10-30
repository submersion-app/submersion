import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
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

  test('webdavServer reads the stored server url', () async {
    await credentials.write(
      'lib',
      jsonEncode(
        WebDavConfig(
          serverUrl: 'https://dav.example.com/remote.php/dav/files/ann',
          username: 'ann',
          password: 'pw',
          folder: 'submersion-sites/site-sync',
        ).toJson(),
      ),
    );
    expect(
      await setup.webdavServer('lib'),
      'https://dav.example.com/remote.php/dav/files/ann',
    );
    expect(await setup.webdavServer('missing'), isNull);
    await credentials.write('broken', 'not json');
    expect(await setup.webdavServer('broken'), isNull);
  });

  test('an empty folder is submersion-sites itself', () {
    expect(LibraryAccountSetup.libraryFolder(' / '), 'submersion-sites');
    expect(LibraryAccountSetup.libraryFolder('reef'), 'submersion-sites/reef');
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
      // A library may hand out a login that can only read.
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
