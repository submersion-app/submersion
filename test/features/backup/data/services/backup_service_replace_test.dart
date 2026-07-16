import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';

import '../../../../support/fake_cloud_storage_provider.dart';

/// Fake database adapter (mirror of backup_service_test.dart's).
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
      throw UnimplementedError('Fake database does not support direct queries');
}

/// Spy repository with a live epoch, isolating restore wiring from the DB.
class _EpochSpySyncRepository extends SyncRepository {
  String? preservedDeviceId;
  String? preservedEpochId;
  final String? liveEpochId;

  _EpochSpySyncRepository({this.liveEpochId});

  @override
  Future<String> getDeviceId() async => 'live-device-id';

  @override
  Future<String?> getLastAcceptedEpochId() async => liveEpochId;

  @override
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {
    preservedDeviceId = preserveDeviceId;
    preservedEpochId = preserveEpochId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackupPreferences preferences;
  late LibraryEpochStore epochStore;
  late _FakeBackupDatabaseAdapter fakeDb;
  late Directory tempDir;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    preferences = BackupPreferences(prefs);
    epochStore = LibraryEpochStore(prefs);
    fakeDb = _FakeBackupDatabaseAdapter();
    tempDir = await Directory.systemTemp.createTemp('backup_replace_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<String> writeRestoreSource() async {
    final src = File('${tempDir.path}/restore_src.db');
    await src.writeAsString('db');
    return src.path;
  }

  group('restore modes', () {
    test('merge mode (default) does not mint a pending replace', () async {
      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: _EpochSpySyncRepository(),
        epochStore: epochStore,
      );

      await service.restoreFromFile(await writeRestoreSource());

      expect(epochStore.pendingReplace, isNull);
    });

    test('replace mode mints a pending replace with a fresh epoch', () async {
      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: _EpochSpySyncRepository(),
        epochStore: epochStore,
      );

      await service.restoreFromFile(
        await writeRestoreSource(),
        mode: RestoreMode.replace,
      );

      final intent = epochStore.pendingReplace;
      expect(intent, isNotNull);
      expect(intent!.epochId, isNotEmpty);
      expect(intent.replacedAt, greaterThan(0));
      expect(intent.deviceId, 'live-device-id');
    });

    test('restore preserves the live epoch through the rebaseline', () async {
      final spy = _EpochSpySyncRepository(liveEpochId: 'live-e');
      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: spy,
        epochStore: epochStore,
      );

      await service.restoreFromFile(await writeRestoreSource());

      expect(spy.preservedEpochId, 'live-e');
      expect(spy.preservedDeviceId, 'live-device-id');
    });
  });

  group('history restore validation parity', () {
    test('restoreFromBackup rejects a corrupt backup file', () async {
      final corrupt = File('${tempDir.path}/corrupt.db');
      await corrupt.writeAsString('not a database');
      final record = BackupRecord(
        id: 'r1',
        filename: 'corrupt.db',
        timestamp: DateTime(2026),
        sizeBytes: 10,
        location: BackupLocation.local,
        localPath: corrupt.path,
      );

      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: _EpochSpySyncRepository(),
        epochStore: epochStore,
      );

      await expectLater(
        () => service.restoreFromBackup(record),
        throwsA(isA<BackupException>()),
      );
    });

    test('history restore in replace mode mints a pending replace', () async {
      final dbFile = File('${tempDir.path}/valid_replace.db');
      final db = sqlite3.sqlite3.open(dbFile.path);
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
      db.dispose();
      final record = BackupRecord(
        id: 'r3',
        filename: 'valid_replace.db',
        timestamp: DateTime(2026),
        sizeBytes: 10,
        location: BackupLocation.local,
        localPath: dbFile.path,
      );

      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: _EpochSpySyncRepository(),
        epochStore: epochStore,
      );

      await service.restoreFromBackup(record, mode: RestoreMode.replace);

      expect(epochStore.pendingReplace, isNotNull);
    });

    test('replace mode without an epoch store is a safe no-op', () async {
      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: _EpochSpySyncRepository(),
        // no epochStore
      );

      await service.restoreFromFile(
        await writeRestoreSource(),
        mode: RestoreMode.replace,
      );

      expect(epochStore.pendingReplace, isNull);
    });

    test('restoreFromBackup accepts a valid backup file', () async {
      final dbFile = File('${tempDir.path}/valid.db');
      final db = sqlite3.sqlite3.open(dbFile.path);
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
      db.dispose();
      final record = BackupRecord(
        id: 'r2',
        filename: 'valid.db',
        timestamp: DateTime(2026),
        sizeBytes: 10,
        location: BackupLocation.local,
        localPath: dbFile.path,
      );

      final spy = _EpochSpySyncRepository();
      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: spy,
        epochStore: epochStore,
      );

      await service.restoreFromBackup(record);

      expect(spy.preservedDeviceId, 'live-device-id');
    });

    test('restoreFromBackup downloads a cloud-only backup into the temp '
        'dir and restores it', () async {
      // A record with only a cloudFileId (no local copy) is pulled down to a
      // temp file first. This exercises _downloadFromCloud, whose
      // resolveSyncTempDir() creates the temp dir on a fresh install.
      final dbFile = File('${tempDir.path}/cloud_source.db');
      final db = sqlite3.sqlite3.open(dbFile.path);
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
      db.dispose();

      final cloud = FakeCloudStorageProvider();
      final upload = await cloud.uploadFile(
        await dbFile.readAsBytes(),
        'valid_cloud.db',
      );
      final record = BackupRecord(
        id: 'r-cloud',
        filename: 'valid_cloud.db',
        timestamp: DateTime(2026),
        sizeBytes: 10,
        location: BackupLocation.cloud,
        cloudFileId: upload.fileId,
      );

      final spy = _EpochSpySyncRepository();
      final service = BackupService(
        dbAdapter: fakeDb,
        preferences: preferences,
        syncRepository: spy,
        epochStore: epochStore,
        cloudProvider: cloud,
      );

      await service.restoreFromBackup(record);

      expect(spy.preservedDeviceId, 'live-device-id');
    });
  });
}
