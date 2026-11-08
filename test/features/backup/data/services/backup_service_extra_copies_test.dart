// Issue #3782: a backup copied to several accounts at once. The main copy
// keeps its own rules; each extra account gets the same stored bytes, and a
// failure in one never costs the backup or the other copies.

import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/deferred_write_provider.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_service.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/extra_copy_destination.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/extra_cloud_copy.dart';

import '../../../../helpers/mock_channels.dart';
import '../../../../support/fake_cloud_storage_provider.dart';
import '../../../../support/fake_keychain_storage.dart';

const _folder = 'Submersion Backups';
const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);

/// One connected account's storage: pushes deferred writes and resets its
/// history on demand, as a Git backend does, and can refuse uploads,
/// deletes or downloads.
class _Account extends FakeCloudStorageProvider
    implements DeferredWriteProvider, HistoryResettable {
  bool failUploads = false;
  bool failDeletes = false;
  bool failDownloads = false;
  int flushes = 0;
  int resets = 0;
  final deleted = <String>[];

  List<String> get names => [for (final f in allStoredFiles()) f.name];

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) {
    if (failUploads) {
      throw const CloudStorageException('upload refused (test)');
    }
    return super.uploadFile(data, filename, folderId: folderId);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (failDeletes) throw const CloudStorageException('delete refused');
    deleted.add(fileId);
    await super.deleteFile(fileId);
  }

  @override
  Future<Uint8List> downloadFile(String fileId) {
    if (failDownloads) throw const CloudStorageException('offline (test)');
    return super.downloadFile(fileId);
  }

  @override
  Future<void> flush({Duration? timeout}) async => flushes++;

  @override
  Future<void> resetHistoryNow() async => resets++;
}

class _Adapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath, {String? note}) async {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('fake backup data');
  }

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

class _Sync extends Fake implements SyncRepository {
  _Sync(this.accountId);

  final String? accountId;

  @override
  Future<String?> getSyncAccountId() async => accountId;

  @override
  Future<String> getDeviceId() async => 'device-under-test';
}

final _isolatedTempDir = Directory.systemTemp.createTempSync('extra_copy_pp_');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => _isolatedTempDir.path,
        );
  });
  tearDownAll(() {
    clearPathAndShareChannelMocks();
    if (_isolatedTempDir.existsSync()) {
      _isolatedTempDir.deleteSync(recursive: true);
    }
  });

  late BackupPreferences preferences;
  late SyncPreferences syncPreferences;
  late EncryptionKeyStore syncKeys;
  late BackupEncryptionKeyStore backupKeys;
  late Directory folder;
  late _Account main;
  late _Account git;
  late _Account dropbox;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    preferences = BackupPreferences(prefs);
    syncPreferences = SyncPreferences(prefs);
    syncKeys = EncryptionKeyStore(storage: InMemoryKeychain());
    backupKeys = BackupEncryptionKeyStore(storage: InMemoryKeychain());
    folder = await Directory.systemTemp.createTemp('extra_copy_');
    await preferences.setBackupLocation(folder.path);
    await preferences.setCloudBackupEnabled(true);
    main = _Account();
    git = _Account();
    dropbox = _Account();
  });
  tearDown(() => folder.delete(recursive: true));

  BackupService service({
    List<ExtraCopyDestination>? extras,
    CloudStorageProvider? mainProvider,
    bool noMain = false,
    String? syncAccountId = 'gd-row',
  }) => BackupService(
    dbAdapter: _Adapter(),
    preferences: preferences,
    cloudProvider: noMain ? null : (mainProvider ?? main),
    syncRepository: _Sync(syncAccountId),
    encryptionKeyStore: syncKeys,
    syncPreferences: syncPreferences,
    backupEncryptionKeyStore: backupKeys,
    extraCopies:
        extras ??
        [
          ExtraCopyDestination('git-row', git),
          ExtraCopyDestination('db-row', dropbox),
        ],
  );

  group('writing a backup', () {
    test('uploads the backup to every extra account', () async {
      final record = await service().performBackup();

      expect(main.names, hasLength(1));
      expect(git.names, [record.filename]);
      expect(dropbox.names, [record.filename]);
      expect(record.extraCloudCopies, [
        ExtraCloudCopy(
          accountId: 'git-row',
          fileId: '$_folder/${record.filename}',
        ),
        ExtraCloudCopy(
          accountId: 'db-row',
          fileId: '$_folder/${record.filename}',
        ),
      ]);
      expect(record.location, BackupLocation.both);
      expect(preferences.getSettings().lastExtraCopyMissingIds, isEmpty);
    });

    test('a failing extra does not stop the next one or the backup', () async {
      git.failUploads = true;

      final record = await service().performBackup();

      expect(dropbox.names, [record.filename]);
      expect(record.extraCloudCopies.map((c) => c.accountId), ['db-row']);
      expect(record.location, BackupLocation.both);
      expect(preferences.getSettings().lastExtraCopyMissingIds, ['git-row']);
    });

    test('missed when its provider is null', () async {
      final record = await service(
        extras: [
          const ExtraCopyDestination('gone-row', null),
          ExtraCopyDestination('db-row', dropbox),
        ],
      ).performBackup();

      expect(record.extraCloudCopies.map((c) => c.accountId), ['db-row']);
      expect(preferences.getSettings().lastExtraCopyMissingIds, ['gone-row']);
    });

    test("skips an extra that is the main copy's account", () async {
      // The copy follows sync, and sync now runs on the Git account.
      final record = await service(syncAccountId: 'git-row').performBackup();

      expect(git.names, isEmpty);
      expect(main.names, [record.filename]);
      expect(record.extraCloudCopies.map((c) => c.accountId), ['db-row']);
      expect(preferences.getSettings().lastExtraCopyMissingIds, isEmpty);
    });

    test('still copies to the extras when the main copy fails', () async {
      main.failUploads = true;

      final record = await service().performBackup();

      expect(record.location, BackupLocation.local);
      expect(record.extraCloudCopies, hasLength(2));
      expect(preferences.getSettings().lastCloudCopyMissing, isTrue);
    });

    test('no extra copies while the copy is off', () async {
      await preferences.setCloudBackupEnabled(false);
      await preferences.setLastExtraCopyMissingIds(['git-row']);

      final record = await service().performBackup();

      expect(git.names, isEmpty);
      expect(dropbox.names, isEmpty);
      expect(record.extraCloudCopies, isEmpty);
      expect(preferences.getSettings().lastExtraCopyMissingIds, isEmpty);
    });

    test('extra copy uploads the sbe', () async {
      await BackupEncryptionService(
        keyStore: backupKeys,
      ).enable(passphrase: 'backuppass1', kdf: _fastKdf);
      await preferences.setBackupEncryptionEnabled(true);

      final record = await service().performBackup();

      expect(record.filename, endsWith('.sbe'));
      final local = await File(record.localPath!).readAsBytes();
      final copy = git.allStoredFiles().single;
      expect(copy.name, record.filename);
      expect(SyncEnvelope.hasMagic(copy.bytes), isTrue);
      expect(copy.bytes, local);
    });

    test('extra copy fails closed when locked', () async {
      // End-to-end encryption is on, but this device holds no key.
      await syncPreferences.setSyncEncryptionEnabled(true);

      final record = await service().performBackup();

      expect(git.allStoredFiles(), isEmpty);
      expect(dropbox.allStoredFiles(), isEmpty);
      expect(record.extraCloudCopies, isEmpty);
      expect(preferences.getSettings().lastExtraCopyMissingIds, [
        'git-row',
        'db-row',
      ]);
    });

    test('an unlocked device frames the extra copy', () async {
      final mlk = SecretKey(List<int>.generate(32, (i) => (i * 3 + 1) % 256));
      const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';
      final slots = KeyslotFile(
        version: 1,
        libraryKeyId: keyId,
        slots: [
          await Keyslots.createSlot(
            type: 'passphrase',
            secret: 'pass',
            mlk: mlk,
            kdf: _fastKdf,
          ),
        ],
      );
      await syncKeys.saveKey(
        libraryKeyId: keyId,
        mlkBytes: await mlk.extractBytes(),
      );
      await syncKeys.saveKeyslotMirror(slots.toJsonBytes());
      await syncPreferences.setSyncEncryptionEnabled(true);

      final record = await service().performBackup();

      final copy = git.allStoredFiles().single;
      expect(copy.name, endsWith('.sbe'));
      expect(SyncEnvelope.hasMagic(copy.bytes), isTrue);
      expect(record.extraCloudCopies.first.fileId, '$_folder/${copy.name}');
    });
  });
}
