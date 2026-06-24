import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';

import '../../../../support/fake_keychain_storage.dart';

/// Throws a generic (non-[PlatformException]) error, proving the fallback only
/// intercepts keychain platform errors and lets everything else propagate.
class _ThrowingSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw Exception('keychain locked');

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw Exception('keychain locked');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw Exception('keychain locked');
}

void main() {
  late InMemoryKeychain storage;
  late S3CredentialsStore store;

  setUp(() {
    storage = InMemoryKeychain();
    store = S3CredentialsStore(storage: storage);
  });

  S3Config config() => S3Config(
    endpoint: 'http://nas.local:9000',
    bucket: 'dive-sync',
    accessKeyId: 'ak',
    secretAccessKey: 'sk',
  );

  test('load returns null when nothing is stored', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips the config', () async {
    await store.save(config());
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.endpoint, 'http://nas.local:9000');
    expect(loaded.bucket, 'dive-sync');
    expect(loaded.secretAccessKey, 'sk');
    expect(storage.values.keys, [S3CredentialsStore.storageKey]);
  });

  test('clear removes the blob', () async {
    await store.save(config());
    await store.clear();
    expect(await store.load(), isNull);
    expect(storage.values, isEmpty);
  });

  test('corrupted JSON loads as null instead of throwing', () async {
    storage.values[S3CredentialsStore.storageKey] = 'not-json{';
    expect(await store.load(), isNull);
  });

  test('valid JSON that is not an object loads as null', () async {
    storage.values[S3CredentialsStore.storageKey] = '[]';
    expect(await store.load(), isNull);
  });

  test('an object with wrong-typed fields loads as null', () async {
    storage.values[S3CredentialsStore.storageKey] = '{"endpoint": 1}';
    expect(await store.load(), isNull);
  });

  test('storage errors propagate to the caller', () async {
    final throwingStore = S3CredentialsStore(storage: _ThrowingSecureStorage());
    expect(throwingStore.load(), throwsA(isA<Exception>()));
  });

  group('keychain entitlement fallback', () {
    test('load falls back to the legacy keychain when the data-protection '
        'keychain reports errSecMissingEntitlement', () async {
      final storage = NoEntitlementKeychain();
      storage.legacy[S3CredentialsStore.storageKey] = jsonEncode(
        config().toJson(),
      );
      final fallbackStore = S3CredentialsStore(storage: storage);

      final loaded = await fallbackStore.load();

      expect(
        storage.dataProtectionAttempted,
        isTrue,
        reason: 'the secure keychain must be tried before the legacy one',
      );
      expect(loaded, isNotNull);
      expect(loaded!.bucket, 'dive-sync');
    });

    test(
      'save falls back to the legacy keychain on errSecMissingEntitlement',
      () async {
        final storage = NoEntitlementKeychain();
        final fallbackStore = S3CredentialsStore(storage: storage);

        await fallbackStore.save(config());

        expect(
          storage.legacy.containsKey(S3CredentialsStore.storageKey),
          isTrue,
        );
      },
    );

    test(
      'a non-entitlement PlatformException is not swallowed by the fallback',
      () async {
        final failingStore = S3CredentialsStore(
          storage: FailingKeychain(-25308),
        );

        expect(failingStore.load(), throwsA(isA<PlatformException>()));
      },
    );
  });
}
