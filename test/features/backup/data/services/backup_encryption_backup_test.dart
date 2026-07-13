import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_service.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';

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

  test('backup encryption ON: cloud copy is byte-identical to the local .sbe '
      '(verbatim single encryption)', () async {
    await enableBackupEncryption();
    await preferences.setCloudBackupEnabled(true);
    final record = await buildService().performBackup();

    final localBytes = await File(record.localPath!).readAsBytes();
    expect(SyncEnvelope.hasMagic(localBytes), isTrue);

    final folderId = await cloud.createFolder('Submersion Backups');
    final files = await cloud.listFiles(
      folderId: folderId,
      namePattern: 'submersion_backup_',
    );
    expect(files, hasLength(1));
    expect(files.single.name, endsWith('.sbe'));

    // Byte-for-byte equality is the real single-encryption guarantee: a
    // double-encrypted upload would also start with SBE1 but would NOT match
    // the local artifact.
    final cloudBytes = await cloud.downloadFile(files.single.id);
    expect(cloudBytes, equals(localBytes));
  });

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

  test(
    'restore: silent with the stored backup key; via passphrase after clear',
    () async {
      await enableBackupEncryption();
      final file = await buildService().exportBackupToTemp(); // encrypted .sbe
      final picked = File(
        '${Directory.systemTemp.path}/pick_${DateTime.now().microsecondsSinceEpoch}.sbe',
      );
      await picked.writeAsBytes(await file.readAsBytes());
      addTearDown(() async {
        if (await picked.exists()) await picked.delete();
      });

      // Stored backup key present -> silent restore, no secret needed.
      await buildService().restoreFromFile(picked.path);

      // Simulate a fresh device: no key, encryption never enabled locally.
      await backupKeyStore.clearKey();
      await preferences.setBackupEncryptionEnabled(false);
      await buildService().restoreFromFile(
        picked.path,
        encryptionSecret: 'backuppass1',
      );
    },
  );

  test(
    'restore: encrypted, no key, no secret -> BackupEncryptedException',
    () async {
      await enableBackupEncryption();
      final file = await buildService().exportBackupToTemp();
      final picked = File(
        '${Directory.systemTemp.path}/pick2_${DateTime.now().microsecondsSinceEpoch}.sbe',
      );
      await picked.writeAsBytes(await file.readAsBytes());
      addTearDown(() async {
        if (await picked.exists()) await picked.delete();
      });

      // Fresh device: no key, encryption not enabled locally.
      await backupKeyStore.clearKey();
      await preferences.setBackupEncryptionEnabled(false);

      await expectLater(
        buildService().restoreFromFile(picked.path),
        throwsA(isA<BackupEncryptedException>()),
      );
    },
  );

  test(
    'reencrypt: plaintext local history entries become .sbe, .sbe skipped',
    () async {
      // One plaintext local backup exists first.
      final plainRecord = await buildService().performBackup();
      expect(plainRecord.filename, endsWith('.db'));

      await enableBackupEncryption();
      final result = await buildService().reencryptExistingBackups();

      expect(result.reencrypted, 1);
      final history = preferences.getHistory();
      expect(history.single.filename, endsWith('.sbe'));
      expect(
        SyncEnvelope.hasMagic(
          await File(history.single.localPath!).readAsBytes(),
        ),
        isTrue,
      );

      // Idempotent: a second run re-encrypts nothing.
      final again = await buildService().reencryptExistingBackups();
      expect(again.reencrypted, 0);
      expect(again.skipped, 1);
    },
  );

  test(
    'reencrypt: non-filesystem records fail (disclosed); missing file skips',
    () async {
      await enableBackupEncryption();
      BackupRecord seed(String id, String? localPath) => BackupRecord(
        id: id,
        filename: '$id.db',
        timestamp: DateTime.now(),
        sizeBytes: 1,
        location: BackupLocation.local,
        localPath: localPath,
      );
      await preferences.addRecord(seed('none', null)); // no local path
      await preferences.addRecord(
        seed('saf', 'content://tree/doc/backup.db'),
      ); // SAF ref
      await preferences.addRecord(
        seed('gone', '${Directory.systemTemp.path}/does_not_exist_x9.db'),
      ); // missing file

      final result = await buildService().reencryptExistingBackups();
      expect(result.reencrypted, 0);
      // null path + SAF ref can't be re-encrypted in place -> failures
      // (surfaced to the user); a genuinely missing file is a harmless skip.
      expect(result.failed, 2);
      expect(result.skipped, 1);
    },
  );

  test(
    'reencrypt: cloud copy replaced; old object deleted when its id differs',
    () async {
      await preferences.setCloudBackupEnabled(true);
      // Plaintext local + plaintext cloud .db (encryption still off here).
      final plain = await buildService().performBackup();
      expect(plain.filename, endsWith('.db'));
      final oldCloudId = preferences.getHistory().single.cloudFileId;
      expect(oldCloudId, isNotNull);
      expect(oldCloudId, endsWith('.db'));

      await enableBackupEncryption();
      final result = await buildService().reencryptExistingBackups();
      expect(result.reencrypted, 1);

      final rec = preferences.getHistory().single;
      // Cloud id moved to the new .sbe object; the old .db object is gone.
      expect(rec.cloudFileId, endsWith('.sbe'));
      expect(rec.cloudFileId, isNot(oldCloudId));
      await expectLater(
        cloud.downloadFile(oldCloudId!),
        throwsA(isA<Object>()),
      );
      expect(
        SyncEnvelope.hasMagic(await cloud.downloadFile(rec.cloudFileId!)),
        isTrue,
      );
    },
  );

  test('reencrypt: path-based provider reuses the cloud id; the object is NOT '
      'deleted (single-encryption collision is safe)', () async {
    // Seed a record whose cloud object already carries the .sbe name the
    // re-encrypt upload will produce -- the case a path-based provider
    // (S3/Dropbox/iCloud) returns the SAME id for. A blind delete here would
    // destroy the object we just uploaded.
    final localDb = File(
      '${Directory.systemTemp.path}/collide_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await localDb.writeAsString('plaintext db');
    addTearDown(() async {
      if (await localDb.exists()) await localDb.delete();
      final sbe = File(
        '${localDb.parent.path}/${localDb.uri.pathSegments.last.replaceAll('.db', '.sbe')}',
      );
      if (await sbe.exists()) await sbe.delete();
    });
    final base = localDb.uri.pathSegments.last.replaceAll('.db', '');
    // The upload target folder id is 'Submersion Backups' (fake createFolder),
    // so the colliding id is that folder + the new .sbe name.
    final upload = await cloud.uploadFile(
      Uint8List.fromList('old sync-encrypted bytes'.codeUnits),
      '$base.sbe',
      folderId: 'Submersion Backups',
    );
    await preferences.addRecord(
      BackupRecord(
        id: 'seed',
        filename: '$base.db',
        timestamp: DateTime.now(),
        sizeBytes: await localDb.length(),
        location: BackupLocation.both,
        localPath: localDb.path,
        cloudFileId: upload.fileId,
      ),
    );

    await enableBackupEncryption();
    final result = await buildService().reencryptExistingBackups();
    expect(result.reencrypted, 1);

    final rec = preferences.getHistory().single;
    // Same id reused; the object survives and is the new backup-key .sbe.
    expect(rec.cloudFileId, upload.fileId);
    final bytes = await cloud.downloadFile(upload.fileId);
    expect(SyncEnvelope.hasMagic(bytes), isTrue);
  });

  test('reencrypt: a failed cloud upload leaves the record resumable (points at '
      'the intact plaintext .db)', () async {
    await preferences.setCloudBackupEnabled(true);
    final plain = await buildService().performBackup();
    final oldLocal = plain.localPath!;
    expect(oldLocal, endsWith('.db'));

    await enableBackupEncryption();
    // A cloud provider that always fails uploads simulates an interrupted run.
    final failing = BackupService(
      dbAdapter: _FakeBackupDatabaseAdapter(),
      preferences: preferences,
      cloudProvider: _AlwaysFailUploadCloud(),
      backupEncryptionKeyStore: backupKeyStore,
    );
    final result = await failing.reencryptExistingBackups();
    expect(result.failed, 1);
    expect(result.reencrypted, 0);

    // The record still points at the untouched plaintext .db, so the next run
    // can re-encrypt it -- resumability is preserved.
    final rec = preferences.getHistory().single;
    expect(rec.localPath, oldLocal);
    expect(rec.filename, endsWith('.db'));
    expect(await File(oldLocal).exists(), isTrue);
  });

  test('reencrypt: a null cloud upload result is a failure, not a dangling '
      'commit', () async {
    await preferences.setCloudBackupEnabled(true);
    final plain = await buildService().performBackup();
    final oldLocal = plain.localPath!;
    final oldCloudId = preferences.getHistory().single.cloudFileId;
    expect(oldCloudId, isNotNull);

    await enableBackupEncryption();
    // Folder creation fails -> _uploadToCloud returns null (does not throw).
    final noFolder = BackupService(
      dbAdapter: _FakeBackupDatabaseAdapter(),
      preferences: preferences,
      cloudProvider: _FolderCreateFailsCloud(),
      backupEncryptionKeyStore: backupKeyStore,
    );
    final result = await noFolder.reencryptExistingBackups();
    expect(result.failed, 1);
    expect(result.reencrypted, 0);

    // History untouched: still the plaintext .db and its original cloud id (no
    // commit that would strand the record on a deleted object).
    final rec = preferences.getHistory().single;
    expect(rec.localPath, oldLocal);
    expect(rec.filename, endsWith('.db'));
    expect(rec.cloudFileId, oldCloudId);
  });

  test('reencrypt: a record with a cloud copy fails when no provider is '
      'available (does not falsely claim the cloud copy is protected)', () async {
    final localDb = File(
      '${Directory.systemTemp.path}/noprov_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await localDb.writeAsString('plaintext db');
    addTearDown(() async {
      if (await localDb.exists()) await localDb.delete();
      final sbe = File(localDb.path.replaceAll('.db', '.sbe'));
      if (await sbe.exists()) await sbe.delete();
    });
    await preferences.addRecord(
      BackupRecord(
        id: 'np',
        filename: 'noprov.db',
        timestamp: DateTime.now(),
        sizeBytes: await localDb.length(),
        location: BackupLocation.both,
        localPath: localDb.path,
        cloudFileId: 'Submersion Backups/noprov.sbe',
      ),
    );

    await enableBackupEncryption();
    // No cloud provider injected, but the record claims a cloud copy.
    final noProvider = BackupService(
      dbAdapter: _FakeBackupDatabaseAdapter(),
      preferences: preferences,
      backupEncryptionKeyStore: backupKeyStore,
    );
    final result = await noProvider.reencryptExistingBackups();
    expect(result.failed, 1);
    expect(result.reencrypted, 0);

    // Record unchanged: still plaintext .db pointing at its original cloud id.
    final rec = preferences.getHistory().single;
    expect(rec.filename, endsWith('.db'));
    expect(rec.cloudFileId, 'Submersion Backups/noprov.sbe');
  });

  test('reencrypt: a failed old-cloud-object delete is disclosed as a failure '
      '(record still committed to .sbe)', () async {
    await preferences.setCloudBackupEnabled(true);
    await buildService().performBackup(); // plaintext local + cloud .db

    await enableBackupEncryption();
    final deleteFails = BackupService(
      dbAdapter: _FakeBackupDatabaseAdapter(),
      preferences: preferences,
      cloudProvider: _DeleteFailsCloud(),
      backupEncryptionKeyStore: backupKeyStore,
    );
    final result = await deleteFails.reencryptExistingBackups();

    // The new .sbe was uploaded and committed, but the old plaintext cloud
    // object could not be deleted -> disclosed as a failure, not a clean pass.
    expect(result.failed, 1);
    expect(result.reencrypted, 0);
    final rec = preferences.getHistory().single;
    expect(rec.filename, endsWith('.sbe'));
    expect(
      SyncEnvelope.hasMagic(await File(rec.localPath!).readAsBytes()),
      isTrue,
    );
  });
}

/// A cloud provider that fails every upload (all other calls delegate to a
/// plain fake). Used to prove the re-encrypt run stays resumable when an upload
/// throws after the new local .sbe is already written.
class _AlwaysFailUploadCloud extends FakeCloudStorageProvider {
  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async => throw const CloudStorageException('Fake: upload failed');
}

/// A cloud provider whose folder creation fails, so `_uploadToCloud` returns
/// null (rather than throwing). Proves re-encrypt treats a null upload result
/// as a failure instead of committing a dangling history pointer.
class _FolderCreateFailsCloud extends FakeCloudStorageProvider {
  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => throw const CloudStorageException('Fake: cannot create folder');
}

/// A cloud provider that uploads normally but fails to delete. Proves a failed
/// cleanup of the OLD cloud object is disclosed as a residual-exposure failure
/// even though the new encrypted record is committed.
class _DeleteFailsCloud extends FakeCloudStorageProvider {
  @override
  Future<void> deleteFile(String fileId) async =>
      throw const CloudStorageException('Fake: delete failed');
}
