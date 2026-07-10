import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../support/fake_keychain_storage.dart';

/// The riverpod seam of encrypted sync: the provider wrap follows the
/// unlocked SESSION, and the session follows the preference flag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';
  final mlkBytes = List<int>.generate(32, (i) => i);

  late EncryptionKeyStore keyStore;

  Future<ProviderContainer> makeContainer({
    required bool encryptionEnabled,
  }) async {
    SharedPreferences.setMockInitialValues({
      'sync_encryption_enabled': encryptionEnabled,
    });
    final prefs = await SharedPreferences.getInstance();
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        encryptionKeyStoreProvider.overrideWithValue(keyStore),
      ],
    );
    addTearDown(container.dispose);
    // Select a provider type so cloudStorageProviderProvider is non-null.
    container.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.s3;
    return container;
  }

  test('disabled: resolved provider is the raw provider', () async {
    final container = await makeContainer(encryptionEnabled: false);
    final provider = container.read(cloudStorageProviderProvider);
    expect(provider, isNotNull);
    expect(provider, isNot(isA<EncryptingCloudStorageProvider>()));
  });

  test('enabled + unlocked session: resolved provider encrypts', () async {
    final container = await makeContainer(encryptionEnabled: true);
    await keyStore.saveKey(libraryKeyId: keyId, mlkBytes: mlkBytes);
    final loaded = await container
        .read(encryptionKeyNotifierProvider.notifier)
        .ensureLoaded();
    expect(loaded, isNotNull);
    final provider = container.read(cloudStorageProviderProvider);
    expect(provider, isA<EncryptingCloudStorageProvider>());
  });

  test('enabled but no stored key: session stays null, provider raw', () async {
    final container = await makeContainer(encryptionEnabled: true);
    final loaded = await container
        .read(encryptionKeyNotifierProvider.notifier)
        .ensureLoaded();
    expect(loaded, isNull);
    final provider = container.read(cloudStorageProviderProvider);
    expect(provider, isNot(isA<EncryptingCloudStorageProvider>()));
  });

  test(
    'flag OFF with a stored key: no session (key kept for backups only)',
    () async {
      final container = await makeContainer(encryptionEnabled: false);
      await keyStore.saveKey(libraryKeyId: keyId, mlkBytes: mlkBytes);
      final loaded = await container
          .read(encryptionKeyNotifierProvider.notifier)
          .ensureLoaded();
      expect(loaded, isNull);
      expect(
        container.read(cloudStorageProviderProvider),
        isNot(isA<EncryptingCloudStorageProvider>()),
      );
    },
  );

  test('setUnlocked activates the wrap; clear() reverts to raw', () async {
    final container = await makeContainer(encryptionEnabled: true);
    final notifier = container.read(encryptionKeyNotifierProvider.notifier);
    await keyStore.saveKey(libraryKeyId: keyId, mlkBytes: mlkBytes);
    final key = (await keyStore.loadKey())!;
    await notifier.setUnlocked(key);
    expect(
      container.read(cloudStorageProviderProvider),
      isA<EncryptingCloudStorageProvider>(),
    );
    await notifier.clear();
    expect(
      container.read(cloudStorageProviderProvider),
      isNot(isA<EncryptingCloudStorageProvider>()),
    );
  });
}
