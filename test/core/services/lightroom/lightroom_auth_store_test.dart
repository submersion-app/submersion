import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  test('round-trips full auth data', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(
        clientId: 'cid',
        clientSecret: 'sec',
        refreshToken: 'rt',
        email: 'a@b.c',
        displayName: 'Eric',
        catalogId: 'cat123',
      ),
    );
    final loaded = await store.load();
    expect(loaded!.clientId, 'cid');
    expect(loaded.clientSecret, 'sec');
    expect(loaded.refreshToken, 'rt');
    expect(loaded.email, 'a@b.c');
    expect(loaded.displayName, 'Eric');
    expect(loaded.catalogId, 'cat123');
  });

  test('round-trips minimal auth data with null optionals', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(const LightroomAuthData(clientId: 'c', refreshToken: 'r'));
    final loaded = await store.load();
    expect(loaded!.clientSecret, isNull);
    expect(loaded.catalogId, isNull);
  });

  test('returns null when unset and on corrupt blob', () async {
    final keychain = InMemoryKeychain();
    final store = LightroomAuthStore(storage: keychain);
    expect(await store.load(), isNull);
    await keychain.write(key: LightroomAuthStore.storageKey, value: '{nope');
    expect(await store.load(), isNull);
    // Corrupt blob is left in place, never deleted.
    expect(await keychain.read(key: LightroomAuthStore.storageKey), '{nope');
  });

  test('copyWith preserves credentials and updates labels', () {
    const data = LightroomAuthData(clientId: 'c', refreshToken: 'r');
    final updated = data.copyWith(
      refreshToken: 'r2',
      catalogId: 'cat',
      displayName: 'Name',
    );
    expect(updated.clientId, 'c');
    expect(updated.refreshToken, 'r2');
    expect(updated.catalogId, 'cat');
    expect(updated.displayName, 'Name');
  });

  test('clear removes the blob', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(const LightroomAuthData(clientId: 'c', refreshToken: 'r'));
    await store.clear();
    expect(await store.load(), isNull);
  });

  test('round-trips a Native App blob with no refresh token and a redirect '
      'uri', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    const data = LightroomAuthData(
      clientId: 'cid',
      redirectUri: 'adobe+hash://adobeid/cid',
      catalogId: 'cat1',
    );
    await store.save(data);
    final loaded = (await store.load())!;
    expect(loaded.clientId, 'cid');
    expect(loaded.refreshToken, isNull);
    expect(loaded.redirectUri, 'adobe+hash://adobeid/cid');
    expect(loaded.catalogId, 'cat1');
  });
}
