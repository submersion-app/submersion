import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';
import '../../../support/fake_keychain_storage.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);
const _passphrase = 'correct horse battery staple';

/// End-to-end encrypted sync: enable-as-replace, the no-plaintext-leak
/// invariant, the locked-device halt, and two-device convergence through
/// the real merge -- all against the raw bytes the provider stores.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'enable -> leak invariant -> locked halt -> unlock -> converge',
    () async {
      final cloud = FakeCloudStorageProvider();

      // ---- Device A: seed a dive, enable encryption, publish ----
      await setUpTestDatabase();
      SharedPreferences.setMockInitialValues({});
      final prefsA = await SharedPreferences.getInstance();
      final keyStoreA = EncryptionKeyStore(storage: InMemoryKeychain());
      final syncPrefsA = SyncPreferences(prefsA);
      final epochStoreA = LibraryEpochStore(prefsA);
      final encryptionA = SyncEncryptionService(
        keyStore: keyStoreA,
        preferences: syncPrefsA,
      );

      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'a1', diveNumber: 1),
      );

      await encryptionA.enable(
        rawProvider: cloud,
        passphrase: _passphrase,
        epochStore: epochStoreA,
        deviceId: 'device-a',
        kdf: _fastKdf,
      );
      final keyA = (await keyStoreA.loadKey())!;
      final providerA = EncryptingCloudStorageProvider(
        cloud,
        dataKey: await Keyslots.deriveDataKey(keyA.mlk),
        libraryKeyId: keyA.libraryKeyId,
      );
      var svcA = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: providerA,
        epochStore: epochStoreA,
        encryptionService: encryptionA,
      );
      // First sync consumes the pending replace (wipes + republishes encrypted);
      // the second is a normal encrypted sync.
      expect((await svcA.performSync()).status, SyncResultStatus.success);
      expect((await svcA.performSync()).status, SyncResultStatus.success);

      // ---- No-plaintext-leak invariant over the RAW stored bytes ----
      final stored = cloud.allStoredFiles();
      expect(stored, isNotEmpty);
      for (final f in stored) {
        if (f.name == KeyslotFile.cloudFileName) {
          expect(
            SyncEnvelope.hasMagic(f.bytes),
            isFalse,
            reason: 'keyslot file must stay plaintext (bootstrap)',
          );
          continue;
        }
        expect(
          SyncEnvelope.hasMagic(f.bytes),
          isTrue,
          reason: '${f.name} stored as plaintext',
        );
        expect(
          utf8.decode(f.bytes, allowMalformed: true),
          isNot(contains('epochId')),
          reason: '${f.name} leaks protocol plaintext',
        );
      }
      await tearDownTestDatabase();

      // ---- Device B (locked): fresh DB + RAW provider -> halt ----
      await setUpTestDatabase();
      SharedPreferences.setMockInitialValues({});
      final prefsB = await SharedPreferences.getInstance();
      final keyStoreB = EncryptionKeyStore(storage: InMemoryKeychain());
      final syncPrefsB = SyncPreferences(prefsB);
      final epochStoreB = LibraryEpochStore(prefsB);
      final encryptionB = SyncEncryptionService(
        keyStore: keyStoreB,
        preferences: syncPrefsB,
      );

      var svcB = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud, // raw: no key yet
        epochStore: epochStoreB,
      );
      expect(
        (await svcB.performSync()).status,
        SyncResultStatus.awaitingPassphrase,
        reason: 'a locked device must halt, not error or destroy anything',
      );

      // ---- Device B unlocks, adopts, converges ----
      final unlockedB = await encryptionB.unlock(
        rawProvider: cloud,
        secret: _passphrase,
      );
      final providerB = EncryptingCloudStorageProvider(
        cloud,
        dataKey: await Keyslots.deriveDataKey(unlockedB.mlk),
        libraryKeyId: unlockedB.libraryKeyId,
      );
      svcB = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: providerB,
        epochStore: epochStoreB,
        encryptionService: encryptionB,
      );
      // The encrypted marker now decrypts; the unaccepted epoch halts for
      // adoption. B is empty, so adopt (mirroring the notifier's silent path).
      final rb = await svcB.performSync();
      expect(rb.status, SyncResultStatus.awaitingAdoption);
      expect((await svcB.adoptReplacedLibrary()).isSuccess, isTrue);
      expect((await svcB.performSync()).status, SyncResultStatus.success);

      final row = await DatabaseService.instance.database
          .customSelect("SELECT id FROM dives WHERE id = 'a1'")
          .getSingleOrNull();
      expect(
        row,
        isNotNull,
        reason: "device B must receive device A's dive through encryption",
      );

      // ---- Steady-state: B edits, A pulls the encrypted changeset ----
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'b1', diveNumber: 2),
      );
      expect((await svcB.performSync()).status, SyncResultStatus.success);
      await tearDownTestDatabase();

      await setUpTestDatabase();
      // Device A state was torn down with its DB; re-adopt as an empty device
      // to prove the changeset path (this also exercises re-join).
      SharedPreferences.setMockInitialValues({});
      final prefsA2 = await SharedPreferences.getInstance();
      final keyStoreA2 = EncryptionKeyStore(storage: InMemoryKeychain());
      final encryptionA2 = SyncEncryptionService(
        keyStore: keyStoreA2,
        preferences: SyncPreferences(prefsA2),
      );
      final unlockedA2 = await encryptionA2.unlock(
        rawProvider: cloud,
        secret: _passphrase,
      );
      svcA = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: EncryptingCloudStorageProvider(
          cloud,
          dataKey: await Keyslots.deriveDataKey(unlockedA2.mlk),
          libraryKeyId: unlockedA2.libraryKeyId,
        ),
        epochStore: LibraryEpochStore(prefsA2),
      );
      final ra2 = await svcA.performSync();
      expect(ra2.status, SyncResultStatus.awaitingAdoption);
      expect((await svcA.adoptReplacedLibrary()).isSuccess, isTrue);
      expect((await svcA.performSync()).status, SyncResultStatus.success);

      final both = await DatabaseService.instance.database
          .customSelect('SELECT COUNT(*) AS c FROM dives')
          .getSingle();
      expect(both.data['c'], 2, reason: 'a1 and b1 must both converge');

      // The leak invariant still holds after all the above traffic.
      for (final f in cloud.allStoredFiles()) {
        if (f.name == KeyslotFile.cloudFileName) continue;
        expect(
          SyncEnvelope.hasMagic(f.bytes),
          isTrue,
          reason: '${f.name} stored as plaintext after steady-state syncs',
        );
      }
      await tearDownTestDatabase();
    },
  );
}
