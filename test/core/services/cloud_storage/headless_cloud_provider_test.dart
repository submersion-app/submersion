import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/headless_cloud_provider.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

import '../../../support/fake_cloud_storage_provider.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EncryptionKeyStore keyStore;
  final built = <CloudProviderType>[];

  CloudStorageProvider instanceFor(CloudProviderType type) {
    built.add(type);
    return FakeCloudStorageProvider(providerId: type.name);
  }

  setUp(() {
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    built.clear();
  });

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Future<CloudStorageProvider?> resolve(SharedPreferences prefs) =>
      resolveHeadlessCloudProvider(
        prefs: prefs,
        encryptionKeyStore: keyStore,
        instanceFor: instanceFor,
      );

  test('resolves the provider recorded by the foreground app', () async {
    final prefs = await prefsWith({'sync_last_provider': 'dropbox'});

    final provider = await resolve(prefs);

    expect(provider, isA<FakeCloudStorageProvider>());
    expect(provider!.providerId, 'dropbox');
    expect(built, [CloudProviderType.dropbox]);
  });

  test('null when no provider has been selected', () async {
    final prefs = await prefsWith({});

    expect(await resolve(prefs), isNull);
    expect(built, isEmpty);
  });

  test('null for an unrecognized stored provider name', () async {
    final prefs = await prefsWith({'sync_last_provider': 'mystery-drive'});

    expect(await resolve(prefs), isNull);
    expect(built, isEmpty);
  });

  test('null in custom-folder storage mode, where an external service '
      'owns the sync', () async {
    final prefs = await prefsWith({
      'sync_last_provider': 'dropbox',
      'db_storage_mode': 'customFolder',
    });

    expect(await resolve(prefs), isNull);
    expect(built, isEmpty);
  });

  test('wraps in the encrypting decorator when sync encryption is on and '
      'the key is on this device', () async {
    final prefs = await prefsWith({'sync_last_provider': 's3'});
    await SyncPreferences(prefs).setSyncEncryptionEnabled(true);
    await keyStore.saveKey(
      libraryKeyId: 'lib-1',
      mlkBytes: List<int>.generate(32, (i) => i),
    );

    final provider = await resolve(prefs);

    expect(provider, isA<EncryptingCloudStorageProvider>());
    expect((provider as EncryptingCloudStorageProvider).inner.providerId, 's3');
  });

  test(
    'stays raw when sync encryption is on but no key is cached here',
    () async {
      final prefs = await prefsWith({'sync_last_provider': 's3'});
      await SyncPreferences(prefs).setSyncEncryptionEnabled(true);

      final provider = await resolve(prefs);

      expect(provider, isA<FakeCloudStorageProvider>());
    },
  );

  test('stays raw when a key exists but sync encryption is off', () async {
    final prefs = await prefsWith({'sync_last_provider': 's3'});
    await keyStore.saveKey(
      libraryKeyId: 'lib-1',
      mlkBytes: List<int>.generate(32, (i) => i),
    );

    final provider = await resolve(prefs);

    expect(provider, isA<FakeCloudStorageProvider>());
  });

  test('a decorator failure resolves to no provider rather than throwing '
      'the whole scheduled backup away', () async {
    final prefs = await prefsWith({'sync_last_provider': 's3'});
    await SyncPreferences(prefs).setSyncEncryptionEnabled(true);
    await keyStore.saveKey(
      libraryKeyId: 'lib-1',
      mlkBytes: List<int>.generate(32, (i) => i),
    );

    final provider = await resolveHeadlessCloudProvider(
      prefs: prefs,
      encryptionKeyStore: _ThrowingKeyStore(),
      instanceFor: instanceFor,
    );

    expect(provider, isNull);
  });
}

/// Models a keychain read that fails (locked device, revoked entitlement).
class _ThrowingKeyStore implements EncryptionKeyStore {
  @override
  Future<UnlockedKey?> loadKey() async => throw StateError('keychain locked');

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
