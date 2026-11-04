@TestOn('browser')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/secure_storage_backend.dart';
import 'package:submersion/core/platform/web/remember_credentials_provider.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// The browser's secure storage end to end (issue #4121): the wrapper every
/// credentials store uses writes to a session store, "remember on this
/// device" moves the entries into real browser local storage, lightly
/// obscured, and clearAll removes them and the flag.
void main() {
  const prefix = 'submersion.secure.';
  List<String> localKeys() => [
    for (var i = 0; i < web.window.localStorage.length; i++)
      web.window.localStorage.key(i)!,
  ];

  setUp(() async {
    await SecureStorageBackend.clearAll();
  });

  tearDown(() async {
    await SecureStorageBackend.clearAll();
  });

  test('a write stays in the session until the user asks otherwise', () async {
    final storage = FallbackSecureStorage(const FlutterSecureStorage());
    await storage.write(key: 's3.secret', value: 'hunter2');
    expect(await storage.read(key: 's3.secret'), 'hunter2');
    expect(await storage.legacyKeychainRequired(), isFalse);
    expect(localKeys().where((k) => k.startsWith(prefix)), isEmpty);
    // Every wrapper instance shares the one store.
    final other = FallbackSecureStorage(const FlutterSecureStorage());
    expect(await other.read(key: 's3.secret'), 'hunter2');
  });

  test('remember moves the entries into local storage, obscured', () async {
    final storage = FallbackSecureStorage(const FlutterSecureStorage());
    await storage.write(key: 's3.secret', value: 'hunter2');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(rememberCredentialsProvider), isFalse);
    await container.read(rememberCredentialsProvider.notifier).set(true);
    expect(container.read(rememberCredentialsProvider), isTrue);
    expect(
      web.window.localStorage.getItem('submersion.rememberCredentials'),
      'true',
    );
    final stored = web.window.localStorage.getItem('${prefix}s3.secret');
    expect(stored, isNotNull);
    expect(stored, isNot('hunter2'));
    expect(await storage.read(key: 's3.secret'), 'hunter2');

    await container.read(rememberCredentialsProvider.notifier).set(false);
    expect(localKeys().where((k) => k.startsWith(prefix)), isEmpty);
    expect(await storage.read(key: 's3.secret'), 'hunter2');
  });

  test('clearAll forgets the entries and the flag', () async {
    final storage = FallbackSecureStorage(const FlutterSecureStorage());
    await SecureStorageBackend.setRemember(true);
    await storage.write(key: 'token', value: 'abc');
    await SecureStorageBackend.clearAll();
    expect(await storage.read(key: 'token'), isNull);
    expect(SecureStorageBackend.remember, isFalse);
    expect(
      web.window.localStorage.getItem('submersion.rememberCredentials'),
      isNull,
    );
  });
}
