import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_service.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

import '../../../../support/fake_cloud_storage_provider.dart';
import '../../../../support/fake_keychain_storage.dart';

/// Tests the issue #580 backup-encryption write/restore paths on BackupService.
/// Uses the fast KDF so enable/change never runs 64 MiB Argon2id.
const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);

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
  late BackupEncryptionKeyStore backupKeyStore;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    preferences = BackupPreferences(prefs);
    backupKeyStore = BackupEncryptionKeyStore(storage: InMemoryKeychain());
    cloud = FakeCloudStorageProvider();
  });

  BackupService buildService() => BackupService(
    dbAdapter: _FakeBackupDatabaseAdapter(),
    preferences: preferences,
    cloudProvider: cloud,
    backupEncryptionKeyStore: backupKeyStore,
  );

  /// Enable backup encryption end-to-end (key + mirror + flag) with a fast KDF.
  Future<void> enableBackupEncryption() async {
    await BackupEncryptionService(
      keyStore: backupKeyStore,
    ).enable(passphrase: 'backuppass1', kdf: _fastKdf);
    await preferences.setBackupEncryptionEnabled(true);
  }

  test(
    'backup encryption OFF: local backup is plaintext .db (unchanged)',
    () async {
      final record = await buildService().performBackup();
      expect(record.filename, endsWith('.db'));
      expect(await File(record.localPath!).readAsString(), 'fake backup data');
    },
  );

  test(
    'backup encryption ON: local history file is .sbe with SBE1 magic',
    () async {
      await enableBackupEncryption();
      final record = await buildService().performBackup();
      expect(record.filename, endsWith('.sbe'));
      final bytes = await File(record.localPath!).readAsBytes();
      expect(SyncEnvelope.hasMagic(bytes), isTrue);
    },
  );

  test(
    'backup encryption ON: cloud copy is the SAME .sbe (single encryption)',
    () async {
      await enableBackupEncryption();
      await preferences.setCloudBackupEnabled(true);
      await buildService().performBackup();

      final folderId = await cloud.createFolder('Submersion Backups');
      final files = await cloud.listFiles(
        folderId: folderId,
        namePattern: 'submersion_backup_',
      );
      expect(files, hasLength(1));
      expect(files.single.name, endsWith('.sbe'));
      expect(
        SyncEnvelope.hasMagic(await cloud.downloadFile(files.single.id)),
        isTrue,
      );
    },
  );

  test('exportBackupToTemp encrypts to .sbe when enabled', () async {
    await enableBackupEncryption();
    final file = await buildService().exportBackupToTemp();
    expect(file.path, endsWith('.sbe'));
    expect(SyncEnvelope.hasMagic(await file.readAsBytes()), isTrue);
  });

  test(
    'exportBackupToPath encrypts the chosen destination when enabled',
    () async {
      await enableBackupEncryption();
      final dest =
          '${Directory.systemTemp.path}/exp_${DateTime.now().microsecondsSinceEpoch}.sbe';
      addTearDown(() async {
        final f = File(dest);
        if (await f.exists()) await f.delete();
      });
      final record = await buildService().exportBackupToPath(dest);
      expect(
        SyncEnvelope.hasMagic(await File(record.localPath!).readAsBytes()),
        isTrue,
      );
    },
  );
}
