import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  test('round-trips, survives a corrupt blob as null, and clears', () async {
    final keychain = InMemoryKeychain();
    final store = WebDavCredentialsStore(storage: keychain);
    expect(await store.load(), isNull);

    final config = WebDavConfig(
      serverUrl: 'https://dav.example.com/dav',
      username: 'u',
      password: 'p',
    );
    await store.save(config);
    expect((await store.load())!.toJson(), config.toJson());

    await keychain.write(key: WebDavCredentialsStore.storageKey, value: '{bad');
    expect(await store.load(), isNull);

    await store.clear();
    expect(await keychain.read(key: WebDavCredentialsStore.storageKey), isNull);
  });

  test('a per-account key keeps accounts apart', () async {
    final keychain = InMemoryKeychain();
    final store = WebDavCredentialsStore(
      storage: keychain,
      storageKey: 'account_x_credentials',
    );
    await store.save(
      WebDavConfig(
        serverUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
      ),
    );
    expect(await keychain.read(key: 'account_x_credentials'), isNotNull);
    expect(await keychain.read(key: WebDavCredentialsStore.storageKey), isNull);
  });

  test('a blob saved with a server type loads as its full address', () async {
    final keychain = InMemoryKeychain();
    final store = WebDavCredentialsStore(storage: keychain);
    await keychain.write(
      key: WebDavCredentialsStore.storageKey,
      value: jsonEncode({
        'preset': 'nextcloud',
        'serverUrl': 'https://cloud.example.com',
        'username': 'alice@example.com',
        'password': 'p',
        'folder': 'Submersion',
        'nextcloudUserId': 'alice',
        'pinnedCertSha256': null,
      }),
    );
    final loaded = (await store.load())!;
    expect(
      loaded.serverUrl,
      'https://cloud.example.com/remote.php/dav/files/alice',
    );
    expect(loaded.chunkedUploadsRoot, isNotNull);
  });
}
