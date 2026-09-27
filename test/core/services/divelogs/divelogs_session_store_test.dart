import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain storage;
  late DivelogsSessionStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = DivelogsSessionStore(storage: storage);
  });

  test('load returns null when nothing stored', () async {
    expect(await store.load(), isNull);
  });

  test('round-trips username and token and never a password', () async {
    await store.save(const DivelogsSession(username: 'rainer', token: 'jwt'));
    final loaded = await store.load();
    expect(loaded!.username, 'rainer');
    expect(loaded.token, 'jwt');
    final raw = await storage.read(key: DivelogsSessionStore.storageKey);
    expect(jsonDecode(raw!), {'username': 'rainer', 'token': 'jwt'});
  });

  test('a corrupt blob loads as null but is left in place', () async {
    await storage.write(key: DivelogsSessionStore.storageKey, value: 'x');
    expect(await store.load(), isNull);
    expect(await storage.read(key: DivelogsSessionStore.storageKey), 'x');
  });

  test('a blob missing the token loads as null', () async {
    await storage.write(
      key: DivelogsSessionStore.storageKey,
      value: jsonEncode({'username': 'rainer'}),
    );
    expect(await store.load(), isNull);
  });

  test('clear removes the blob', () async {
    await store.save(const DivelogsSession(username: 'a', token: 'b'));
    await store.clear();
    expect(await store.load(), isNull);
  });
}
