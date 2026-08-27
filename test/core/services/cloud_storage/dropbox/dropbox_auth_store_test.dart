import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain storage;
  late DropboxAuthStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = DropboxAuthStore(storage: storage);
  });

  DropboxAuthData auth() => DropboxAuthData(
    refreshToken: 'rt-123',
    email: 'diver@example.com',
    displayName: 'Diver',
  );

  test('load returns null when nothing stored', () async {
    expect(await store.load(), isNull);
  });

  test('round-trips all fields through the keychain blob', () async {
    await store.save(auth());
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.refreshToken, 'rt-123');
    expect(loaded.email, 'diver@example.com');
    expect(loaded.displayName, 'Diver');
  });

  test('optional fields round-trip as null', () async {
    await store.save(DropboxAuthData(refreshToken: 'rt-only'));
    final loaded = await store.load();
    expect(loaded!.refreshToken, 'rt-only');
    expect(loaded.email, isNull);
    expect(loaded.displayName, isNull);
  });

  test('a corrupt blob loads as null but is left in place', () async {
    await storage.write(key: DropboxAuthStore.storageKey, value: 'not json');
    expect(await store.load(), isNull);
    expect(await storage.read(key: DropboxAuthStore.storageKey), 'not json');
  });

  test('a blob of the wrong shape loads as null', () async {
    await storage.write(
      key: DropboxAuthStore.storageKey,
      value: jsonEncode([1, 2, 3]),
    );
    expect(await store.load(), isNull);
  });

  test('a blob missing refreshToken loads as null', () async {
    await storage.write(
      key: DropboxAuthStore.storageKey,
      value: jsonEncode({'email': 'x@example.com'}),
    );
    expect(await store.load(), isNull);
  });

  test('clear removes the blob', () async {
    await store.save(auth());
    await store.clear();
    expect(await store.load(), isNull);
    expect(await storage.read(key: DropboxAuthStore.storageKey), isNull);
  });
}
