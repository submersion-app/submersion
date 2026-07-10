import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';

import '../../../../support/fake_cloud_storage_provider.dart';
import '../../../../support/fake_keychain_storage.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);
const _passphrase = 'correct horse battery staple';

class _FakeBackupDatabaseAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('fake backup data');
  }

  @override
  Future<void> restore(String backupPath) async {}

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database =>
      throw UnimplementedError('Fake database does not support queries');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getTemporaryDirectory') {
              return Directory.systemTemp.path;
            }
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return Directory.systemTemp.path;
            }
            return null;
          },
        );
  });

  late BackupPreferences preferences;
  late SyncPreferences syncPreferences;
  late EncryptionKeyStore keyStore;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    preferences = BackupPreferences(prefs);
    syncPreferences = SyncPreferences(prefs);
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    cloud = FakeCloudStorageProvider();
  });

  BackupService buildService() => BackupService(
    dbAdapter: _FakeBackupDatabaseAdapter(),
    preferences: preferences,
    cloudProvider: cloud,
    encryptionKeyStore: keyStore,
    syncPreferences: syncPreferences,
  );

  /// Seed an unlocked encrypted-library state (key + mirror + flag).
  Future<String> seedEncryption() async {
    final mlk = SecretKey(List<int>.generate(32, (i) => (i * 3 + 1) % 256));
    const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';
    final file = KeyslotFile(
      version: 1,
      libraryKeyId: keyId,
      slots: [
        await Keyslots.createSlot(
          type: 'passphrase',
          secret: _passphrase,
          mlk: mlk,
          kdf: _fastKdf,
        ),
      ],
    );
    await keyStore.saveKey(
      libraryKeyId: keyId,
      mlkBytes: await mlk.extractBytes(),
    );
    await keyStore.saveKeyslotMirror(file.toJsonBytes());
    await syncPreferences.setSyncEncryptionEnabled(true);
    return keyId;
  }

  // The support fake's createFolder returns the folder name as its id.
  Future<String> backupFolderId() => cloud.createFolder('Submersion Backups');

  Future<({String name, Uint8List bytes})> singleCloudBackup() async {
    final files = await cloud.listFiles(
      folderId: await backupFolderId(),
      namePattern: 'submersion_backup_',
    );
    expect(files, hasLength(1));
    return (
      name: files.single.name,
      bytes: await cloud.downloadFile(files.single.id),
    );
  }

  test('encryption on: cloud copy is .sbe with SBE1 magic, local stays '
      'plaintext', () async {
    await seedEncryption();
    await preferences.setCloudBackupEnabled(true);

    final service = buildService();
    final record = await service.performBackup();

    final uploaded = await singleCloudBackup();
    expect(uploaded.name, endsWith('.sbe'));
    expect(SyncEnvelope.hasMagic(uploaded.bytes), isTrue);
    // Local artifact untouched:
    expect(record.localPath, isNotNull);
    expect(await File(record.localPath!).readAsString(), 'fake backup data');
  });

  test('encryption off: cloud copy keeps the plaintext .db name', () async {
    await preferences.setCloudBackupEnabled(true);

    final service = buildService();
    await service.performBackup();

    final uploaded = await singleCloudBackup();
    expect(uploaded.name, endsWith('.db'));
    expect(SyncEnvelope.hasMagic(uploaded.bytes), isFalse);
    expect(utf8.decode(uploaded.bytes), 'fake backup data');
  });

  test('restoreFromFile: encrypted artifact with no secret and no cached '
      'key throws BackupEncryptedException', () async {
    final keyId = await seedEncryption();
    await preferences.setCloudBackupEnabled(true);
    final service = buildService();
    await service.performBackup();
    final uploaded = await singleCloudBackup();
    // Write the encrypted artifact to disk as a picked file:
    final picked = File('${Directory.systemTemp.path}/picked_$keyId.sbe');
    await picked.writeAsBytes(uploaded.bytes);
    addTearDown(() async {
      if (await picked.exists()) await picked.delete();
    });
    // Drop the cached key: a fresh device with no key and no secret.
    await keyStore.clearKey();

    await expectLater(
      service.restoreFromFile(picked.path),
      throwsA(isA<BackupEncryptedException>()),
    );
  });

  test('restoreFromFile: succeeds with the passphrase, and silently with '
      'the cached key', () async {
    await seedEncryption();
    await preferences.setCloudBackupEnabled(true);
    final service = buildService();
    await service.performBackup();
    final uploaded = await singleCloudBackup();
    final picked = File('${Directory.systemTemp.path}/picked_enc.sbe');
    await picked.writeAsBytes(uploaded.bytes);
    addTearDown(() async {
      if (await picked.exists()) await picked.delete();
    });

    // Cached key path (key still present): no secret needed.
    await service.restoreFromFile(picked.path);

    // Passphrase path (no cached key):
    await keyStore.clearKey();
    await service.restoreFromFile(picked.path, encryptionSecret: _passphrase);
  });

  test('validateBackupFile accepts an encrypted .sbe artifact', () async {
    await seedEncryption();
    await preferences.setCloudBackupEnabled(true);
    final service = buildService();
    await service.performBackup();
    final uploaded = await singleCloudBackup();
    final picked = File('${Directory.systemTemp.path}/valid_enc.sbe');
    await picked.writeAsBytes(uploaded.bytes);
    addTearDown(() async {
      if (await picked.exists()) await picked.delete();
    });

    final result = await service.validateBackupFile(picked.path);
    expect(result.isValid, isTrue);
  });

  test('validateBackupFile rejects a .sbe file that lacks the magic', () async {
    final service = buildService();
    final bogus = File('${Directory.systemTemp.path}/bogus.sbe');
    await bogus.writeAsString('not an encrypted backup at all');
    addTearDown(() async {
      if (await bogus.exists()) await bogus.delete();
    });

    final result = await service.validateBackupFile(bogus.path);
    expect(result.isValid, isFalse);
  });

  test('deletePlaintextCloudBackups removes only *.db artifacts', () async {
    await preferences.setCloudBackupEnabled(true);
    final service = buildService();
    await service.performBackup(); // plaintext .db upload

    await seedEncryption();
    await service.performBackup(); // encrypted .sbe upload

    final removed = await service.deletePlaintextCloudBackups();
    expect(removed, 1);
    final remaining = await cloud.listFiles(
      folderId: await backupFolderId(),
      namePattern: 'submersion_backup_',
    );
    expect(remaining, hasLength(1));
    expect(remaining.single.name, endsWith('.sbe'));
  });
}
