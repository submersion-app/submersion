import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';

import '../../../../support/fake_keychain_storage.dart';

GitConfig _config() => GitConfig(
  repoUrl: 'https://github.com/you/dive-log',
  username: 'you',
  token: 'ghp_secret',
);

void main() {
  test('round-trips, survives a corrupt blob as null, and clears', () async {
    final keychain = InMemoryKeychain();
    final store = GitCredentialsStore(storage: keychain);
    expect(await store.load(), isNull);

    await store.save(_config());
    expect((await store.load())!.toJson(), _config().toJson());

    await keychain.write(key: GitCredentialsStore.storageKey, value: '{bad');
    expect(await store.load(), isNull);

    await store.clear();
    expect(await keychain.read(key: GitCredentialsStore.storageKey), isNull);
  });

  test('a per-account key keeps accounts apart', () async {
    final keychain = InMemoryKeychain();
    final store = GitCredentialsStore(
      storage: keychain,
      storageKey: 'account_x_credentials',
    );
    await store.save(_config());
    expect(await keychain.read(key: 'account_x_credentials'), isNotNull);
    expect(await keychain.read(key: GitCredentialsStore.storageKey), isNull);
  });
}
