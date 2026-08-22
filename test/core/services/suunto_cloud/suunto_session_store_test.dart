import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_session_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain storage;
  late SuuntoSessionStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = SuuntoSessionStore(storage: storage);
  });

  test('load returns null when nothing stored', () async {
    expect(await store.load(), isNull);
  });

  test('round-trips email and session key through the keychain blob', () async {
    await store.save(
      const SuuntoSessionData(email: 'diver@example.com', sessionKey: 'sk-123'),
    );
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.email, 'diver@example.com');
    expect(loaded.sessionKey, 'sk-123');
  });

  test('a corrupt blob loads as null but is left in place', () async {
    await storage.write(key: SuuntoSessionStore.storageKey, value: 'not json');
    expect(await store.load(), isNull);
    expect(await storage.read(key: SuuntoSessionStore.storageKey), 'not json');
  });

  test('a blob of the wrong shape loads as null', () async {
    await storage.write(
      key: SuuntoSessionStore.storageKey,
      value: jsonEncode([1, 2, 3]),
    );
    expect(await store.load(), isNull);
  });

  test('a blob missing sessionKey loads as null', () async {
    await storage.write(
      key: SuuntoSessionStore.storageKey,
      value: jsonEncode({'email': 'x@example.com'}),
    );
    expect(await store.load(), isNull);
  });

  test('clear removes the blob', () async {
    await store.save(
      const SuuntoSessionData(email: 'diver@example.com', sessionKey: 'sk-1'),
    );
    await store.clear();
    expect(await store.load(), isNull);
    expect(await storage.read(key: SuuntoSessionStore.storageKey), isNull);
  });
}
