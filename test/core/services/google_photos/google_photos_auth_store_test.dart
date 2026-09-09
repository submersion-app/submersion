import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  test('round-trips full auth data', () async {
    final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
    await store.save(
      const GooglePhotosAuthData(
        refreshToken: 'rt',
        email: 'diver@example.com',
        displayName: 'diver@example.com',
      ),
    );
    final loaded = await store.load();
    expect(loaded!.refreshToken, 'rt');
    expect(loaded.email, 'diver@example.com');
    expect(loaded.displayName, 'diver@example.com');
  });

  test('round-trips minimal auth data with null optionals', () async {
    final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
    await store.save(const GooglePhotosAuthData(refreshToken: 'r'));
    final loaded = await store.load();
    expect(loaded!.refreshToken, 'r');
    expect(loaded.email, isNull);
    expect(loaded.displayName, isNull);
  });

  test('returns null when unset and on a corrupt blob, leaving it in '
      'place', () async {
    final keychain = InMemoryKeychain();
    final store = GooglePhotosAuthStore(storage: keychain);
    expect(await store.load(), isNull);

    await keychain.write(key: GooglePhotosAuthStore.storageKey, value: '{nope');
    expect(await store.load(), isNull);
    expect(await keychain.read(key: GooglePhotosAuthStore.storageKey), '{nope');
  });

  test('a per-account storage key isolates connections', () async {
    final keychain = InMemoryKeychain();
    final a = GooglePhotosAuthStore(storage: keychain, storageKey: 'acct_a');
    final b = GooglePhotosAuthStore(storage: keychain, storageKey: 'acct_b');
    await a.save(const GooglePhotosAuthData(refreshToken: 'ra'));
    await b.save(const GooglePhotosAuthData(refreshToken: 'rb'));
    expect((await a.load())!.refreshToken, 'ra');
    expect((await b.load())!.refreshToken, 'rb');

    await a.clear();
    expect(await a.load(), isNull);
    expect((await b.load())!.refreshToken, 'rb');
  });

  test('copyWith replaces only the named fields', () {
    const data = GooglePhotosAuthData(refreshToken: 'r', email: 'a@b.c');
    final updated = data.copyWith(refreshToken: 'r2');
    expect(updated.refreshToken, 'r2');
    expect(updated.email, 'a@b.c');
  });
}
