import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

import '../../../../support/fake_cloud_storage_provider.dart';
import '../../../../support/fake_keychain_storage.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late EncryptionKeyStore keyStore;
  late SyncPreferences prefs;
  late LibraryEpochStore epochStore;
  late SyncEncryptionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();
    cloud = FakeCloudStorageProvider();
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    prefs = SyncPreferences(sharedPrefs);
    epochStore = LibraryEpochStore(sharedPrefs);
    service = SyncEncryptionService(keyStore: keyStore, preferences: prefs);
  });

  Future<EnableEncryptionResult> enable() => service.enable(
    rawProvider: cloud,
    passphrase: 'correct horse battery staple',
    epochStore: epochStore,
    deviceId: 'device-a',
    deviceName: 'Test Mac',
    kdf: _fastKdf,
  );

  Future<KeyslotFile> cloudKeyslots() async {
    final files = await cloud.listFiles(namePattern: KeyslotFile.cloudFileName);
    final match = files.singleWhere((f) => f.name == KeyslotFile.cloudFileName);
    return KeyslotFile.fromJsonBytes(await cloud.downloadFile(match.id));
  }

  test(
    'enable uploads keyslots, saves key+mirror, flags, pends replace',
    () async {
      final result = await enable();

      final file = await cloudKeyslots();
      expect(file.libraryKeyId, result.libraryKeyId);
      expect(file.slots.map((s) => s.type), ['passphrase', 'recovery']);
      // Both secrets unwrap the same MLK:
      final viaPass = await Keyslots.tryUnwrap(
        file: file,
        secret: 'correct horse battery staple',
      );
      final viaCode = await Keyslots.tryUnwrap(
        file: file,
        secret: result.recoveryCode,
      );
      expect(viaPass, isNotNull);
      expect(await viaCode!.extractBytes(), await viaPass!.extractBytes());
      // Local state:
      final key = await keyStore.loadKey();
      expect(key!.libraryKeyId, result.libraryKeyId);
      expect(await keyStore.loadKeyslotMirror(), isNotNull);
      expect(prefs.syncEncryptionEnabled, isTrue);
      expect(epochStore.pendingReplace, isNotNull);
      expect(epochStore.pendingReplace!.deviceId, 'device-a');
    },
  );

  test('unlock on a second device recovers the same MLK', () async {
    final enabled = await enable();
    final keyStoreB = EncryptionKeyStore(storage: InMemoryKeychain());
    final serviceB = SyncEncryptionService(
      keyStore: keyStoreB,
      preferences: prefs,
    );
    final unlocked = await serviceB.unlock(
      rawProvider: cloud,
      secret: 'correct horse battery staple',
    );
    expect(unlocked.libraryKeyId, enabled.libraryKeyId);
    final keyA = await keyStore.loadKey();
    final keyB = await keyStoreB.loadKey();
    expect(await keyB!.mlk.extractBytes(), await keyA!.mlk.extractBytes());
    expect(await keyStoreB.loadKeyslotMirror(), isNotNull);
  });

  test('unlock failures: wrong secret and missing keyslot file', () async {
    await enable();
    await expectLater(
      service.unlock(rawProvider: cloud, secret: 'nope'),
      throwsA(isA<WrongPassphraseException>()),
    );
    // Remove the keyslot file entirely:
    await service.deleteCloudKeyslots(cloud);
    await expectLater(
      service.unlock(rawProvider: cloud, secret: 'anything'),
      throwsA(isA<SyncEncryptionRequired>()),
    );
  });

  test('changePassphrase rewraps: old dead, new works, recovery survives, '
      'keyId unchanged', () async {
    final enabled = await enable();
    await service.changePassphrase(
      rawProvider: cloud,
      currentSecret: 'correct horse battery staple',
      newPassphrase: 'brand new passphrase',
      kdf: _fastKdf,
    );
    final file = await cloudKeyslots();
    expect(file.libraryKeyId, enabled.libraryKeyId);
    expect(
      await Keyslots.tryUnwrap(
        file: file,
        secret: 'correct horse battery staple',
      ),
      isNull,
    );
    expect(
      await Keyslots.tryUnwrap(file: file, secret: 'brand new passphrase'),
      isNotNull,
    );
    expect(
      await Keyslots.tryUnwrap(file: file, secret: enabled.recoveryCode),
      isNotNull,
    );
  });

  test('regenerateRecoveryCode: old code dead, new code unlocks', () async {
    final enabled = await enable();
    final newCode = await service.regenerateRecoveryCode(
      rawProvider: cloud,
      passphrase: 'correct horse battery staple',
      kdf: _fastKdf,
    );
    expect(newCode, isNot(enabled.recoveryCode));
    final file = await cloudKeyslots();
    expect(
      await Keyslots.tryUnwrap(file: file, secret: enabled.recoveryCode),
      isNull,
    );
    expect(await Keyslots.tryUnwrap(file: file, secret: newCode), isNotNull);
  });

  test('disable clears flag, pends replace, keeps the stored key', () async {
    await enable();
    // Consume the enable replace so disable's pending is unambiguous:
    await epochStore.clearPendingReplace();

    await service.disable(epochStore: epochStore, deviceId: 'device-a');
    expect(prefs.syncEncryptionEnabled, isFalse);
    expect(epochStore.pendingReplace, isNotNull);
    expect(await keyStore.loadKey(), isNotNull); // kept for old backups

    await service.deleteCloudKeyslots(cloud);
    final files = await cloud.listFiles(namePattern: KeyslotFile.cloudFileName);
    expect(files.where((f) => f.name == KeyslotFile.cloudFileName), isEmpty);
  });

  test(
    'selfHealKeyslots re-uploads the mirror when the cloud copy vanishes',
    () async {
      await enable();
      final mirror = await keyStore.loadKeyslotMirror();
      await service.deleteCloudKeyslots(cloud);

      await service.selfHealKeyslots(cloud);

      final files = await cloud.listFiles(
        namePattern: KeyslotFile.cloudFileName,
      );
      final match = files.singleWhere(
        (f) => f.name == KeyslotFile.cloudFileName,
      );
      expect(await cloud.downloadFile(match.id), mirror);
    },
  );

  test('selfHealKeyslots is a no-op when the cloud copy exists', () async {
    await enable();
    final before = await cloud.listFiles(
      namePattern: KeyslotFile.cloudFileName,
    );
    await service.selfHealKeyslots(cloud);
    final after = await cloud.listFiles(namePattern: KeyslotFile.cloudFileName);
    expect(after.length, before.length);
  });
}
