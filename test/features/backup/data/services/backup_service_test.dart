import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

// =============================================================================
// Test Doubles
// =============================================================================

/// Fake database adapter for testing
class FakeBackupDatabaseAdapter implements BackupDatabaseAdapter {
  int backupCallCount = 0;
  int restoreCallCount = 0;
  String? lastBackupPath;
  String? lastRestorePath;

  @override
  Future<void> backup(String destinationPath) async {
    backupCallCount++;
    lastBackupPath = destinationPath;
    // Create the file so callers that check size don't throw
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('fake backup data');
  }

  @override
  Future<void> restore(String backupPath) async {
    restoreCallCount++;
    lastRestorePath = backupPath;
  }

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database =>
      throw UnimplementedError('Fake database does not support direct queries');
}

/// Fake cloud storage provider for testing
class FakeCloudStorageProvider implements CloudStorageProvider {
  final List<String> uploadedFiles = [];
  final List<String> deletedFiles = [];
  final Map<String, Uint8List> storedFiles = {};
  bool shouldFailUpload = false;
  bool shouldFailDelete = false;
  bool shouldFailDownload = false;
  String? createdFolder;
  int uploadCallCount = 0;

  @override
  String get providerName => 'Fake';
  @override
  String get providerId => 'fake';

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> authenticate() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> getUserEmail() async => 'test@example.com';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    uploadCallCount++;
    if (shouldFailUpload) {
      throw const CloudStorageException('Upload failed');
    }
    final fileId = 'cloud-${uploadedFiles.length}';
    uploadedFiles.add(filename);
    storedFiles[fileId] = data;
    return UploadResult(fileId: fileId, uploadTime: DateTime.now());
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    if (shouldFailDownload) {
      throw const CloudStorageException('Download failed');
    }
    return storedFiles[fileId] ?? Uint8List(0);
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async => null;

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    return [];
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (shouldFailDelete) {
      throw const CloudStorageException('Delete failed');
    }
    deletedFiles.add(fileId);
    storedFiles.remove(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async =>
      storedFiles.containsKey(fileId);

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    createdFolder = folderName;
    return 'folder-$folderName';
  }

  @override
  Future<String> getOrCreateSyncFolder() async => 'sync-folder';
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('BackupService', () {
    late BackupPreferences preferences;
    late FakeCloudStorageProvider fakeCloud;
    late FakeBackupDatabaseAdapter fakeDb;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      preferences = BackupPreferences(prefs);
      fakeCloud = FakeCloudStorageProvider();
      fakeDb = FakeBackupDatabaseAdapter();
    });

    group('pruneOldBackups', () {
      test('does nothing when under retention limit', () async {
        for (var i = 0; i < 3; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'r$i',
              filename: 'backup_$i.db',
              timestamp: DateTime(2025, 6, i + 1),
              sizeBytes: 1000,
              location: BackupLocation.local,
              diveCount: 5,
              siteCount: 2,
            ),
          );
        }

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.pruneOldBackups(5);

        final history = preferences.getHistory();
        expect(history, hasLength(3));
      });

      test('removes oldest records beyond retention limit', () async {
        for (var i = 0; i < 5; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'r$i',
              filename: 'backup_$i.db',
              timestamp: DateTime(2025, 6, i + 1),
              sizeBytes: 1000,
              location: BackupLocation.local,
              diveCount: 5,
              siteCount: 2,
            ),
          );
        }

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.pruneOldBackups(3);

        final history = preferences.getHistory();
        expect(history, hasLength(3));

        // Should keep the 3 newest (timestamps: June 5, 4, 3)
        final ids = history.map((r) => r.id).toList();
        expect(ids, contains('r4'));
        expect(ids, contains('r3'));
        expect(ids, contains('r2'));
        expect(ids, isNot(contains('r0')));
        expect(ids, isNot(contains('r1')));
      });

      test('deletes cloud files during pruning', () async {
        for (var i = 0; i < 3; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'r$i',
              filename: 'backup_$i.db',
              timestamp: DateTime(2025, 6, i + 1),
              sizeBytes: 1000,
              location: BackupLocation.both,
              diveCount: 5,
              siteCount: 2,
              cloudFileId: 'cloud-$i',
            ),
          );
        }

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
          cloudProvider: fakeCloud,
        );

        await service.pruneOldBackups(1);

        expect(fakeCloud.deletedFiles, hasLength(2));
      });

      test('continues pruning even if cloud delete fails', () async {
        fakeCloud.shouldFailDelete = true;

        for (var i = 0; i < 3; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'r$i',
              filename: 'backup_$i.db',
              timestamp: DateTime(2025, 6, i + 1),
              sizeBytes: 1000,
              location: BackupLocation.both,
              diveCount: 5,
              siteCount: 2,
              cloudFileId: 'cloud-$i',
            ),
          );
        }

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
          cloudProvider: fakeCloud,
        );

        // Should not throw
        await service.pruneOldBackups(1);

        // Records still removed from preferences
        final history = preferences.getHistory();
        expect(history, hasLength(1));
      });
    });

    group('deleteBackup', () {
      test('removes record from preferences', () async {
        final record = BackupRecord(
          id: 'r1',
          filename: 'backup.db',
          timestamp: DateTime(2025, 6, 15),
          sizeBytes: 1000,
          location: BackupLocation.local,
          diveCount: 5,
          siteCount: 2,
        );
        await preferences.addRecord(record);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.deleteBackup(record);

        final history = preferences.getHistory();
        expect(history, isEmpty);
      });

      test('attempts cloud file deletion for cloud backups', () async {
        final record = BackupRecord(
          id: 'r1',
          filename: 'backup.db',
          timestamp: DateTime(2025, 6, 15),
          sizeBytes: 1000,
          location: BackupLocation.both,
          diveCount: 5,
          siteCount: 2,
          cloudFileId: 'cloud-abc',
        );
        await preferences.addRecord(record);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
          cloudProvider: fakeCloud,
        );

        await service.deleteBackup(record);

        expect(fakeCloud.deletedFiles, contains('cloud-abc'));
      });

      test('skips cloud deletion when no cloud provider', () async {
        final record = BackupRecord(
          id: 'r1',
          filename: 'backup.db',
          timestamp: DateTime(2025, 6, 15),
          sizeBytes: 1000,
          location: BackupLocation.both,
          diveCount: 5,
          siteCount: 2,
          cloudFileId: 'cloud-abc',
        );
        await preferences.addRecord(record);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
          // No cloud provider
        );

        await service.deleteBackup(record);

        // Record still removed from preferences
        final history = preferences.getHistory();
        expect(history, isEmpty);
      });
    });

    group('getBackupHistory', () {
      test('returns records sorted newest-first', () async {
        await preferences.addRecord(
          BackupRecord(
            id: 'old',
            filename: 'old.db',
            timestamp: DateTime(2025, 1, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 5,
            siteCount: 2,
          ),
        );
        await preferences.addRecord(
          BackupRecord(
            id: 'new',
            filename: 'new.db',
            timestamp: DateTime(2025, 12, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 15,
            siteCount: 5,
          ),
        );
        await preferences.addRecord(
          BackupRecord(
            id: 'mid',
            filename: 'mid.db',
            timestamp: DateTime(2025, 6, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 10,
            siteCount: 3,
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final history = service.getBackupHistory();

        expect(history[0].id, 'new');
        expect(history[1].id, 'mid');
        expect(history[2].id, 'old');
      });

      test('returns empty list when no history', () {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final history = service.getBackupHistory();
        expect(history, isEmpty);
      });
    });

    group('validateBackupFile', () {
      test('returns invalid for non-existent file', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final result = await service.validateBackupFile('/nonexistent/file.db');
        expect(result.isValid, false);
        expect(result.error, contains('not found'));
      });

      test('returns invalid for wrong extension', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final badFile = File('${tempDir.path}/not_a_backup.txt');
        await badFile.writeAsString('not a database');

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final result = await service.validateBackupFile(badFile.path);
          expect(result.isValid, false);
          expect(result.error, contains('extension'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('returns invalid for empty file', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final emptyFile = File('${tempDir.path}/empty.db');
        await emptyFile.create();

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final result = await service.validateBackupFile(emptyFile.path);
          expect(result.isValid, false);
          expect(result.error, contains('empty'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('returns valid for SQLite database with expected tables', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final dbFile = File('${tempDir.path}/valid.db');

        final db = sqlite3.sqlite3.open(dbFile.path);
        db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        db.dispose();

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final result = await service.validateBackupFile(dbFile.path);
          expect(result.isValid, true);
          expect(result.sizeBytes, greaterThan(0));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test(
        'returns valid for older-schema database without triggering migrations',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('backup_test_');
          final dbFile = File('${tempDir.path}/old_schema.db');

          // Simulate a backup from an older app version (schema < 30)
          // that does NOT have the wearable_source column
          final db = sqlite3.sqlite3.open(dbFile.path);
          db.execute(
            'CREATE TABLE dives (id TEXT PRIMARY KEY, dive_date_time INTEGER)',
          );
          db.execute(
            'CREATE TABLE dive_sites (id TEXT PRIMARY KEY, name TEXT)',
          );
          db.execute('PRAGMA user_version = 20');
          db.dispose();

          final service = BackupService(
            dbAdapter: fakeDb,
            preferences: preferences,
          );

          try {
            final result = await service.validateBackupFile(dbFile.path);
            expect(result.isValid, true);
            expect(result.sizeBytes, greaterThan(0));

            // Verify the backup file was NOT modified (no migration ran)
            final verifyDb = sqlite3.sqlite3.open(
              dbFile.path,
              mode: sqlite3.OpenMode.readOnly,
            );
            try {
              final columns = verifyDb.select("PRAGMA table_info('dives')");
              final columnNames = columns
                  .map((row) => row['name'] as String)
                  .toList();
              expect(columnNames, isNot(contains('wearable_source')));
            } finally {
              verifyDb.dispose();
            }
          } finally {
            await tempDir.delete(recursive: true);
          }
        },
      );

      test('returns invalid for non-SQLite file with .db extension', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final fakeDbFile = File('${tempDir.path}/fake.db');
        await fakeDbFile.writeAsString('this is not a sqlite database');

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final result = await service.validateBackupFile(fakeDbFile.path);
          expect(result.isValid, false);
          expect(result.error, contains('not a valid database'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test(
        'returns invalid for SQLite database missing expected tables',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('backup_test_');
          final dbFile = File('${tempDir.path}/wrong_tables.db');

          final db = sqlite3.sqlite3.open(dbFile.path);
          db.execute('CREATE TABLE some_other_table (id TEXT PRIMARY KEY)');
          db.dispose();

          final service = BackupService(
            dbAdapter: fakeDb,
            preferences: preferences,
          );

          try {
            final result = await service.validateBackupFile(dbFile.path);
            expect(result.isValid, false);
            expect(result.error, contains('missing expected tables'));
          } finally {
            await tempDir.delete(recursive: true);
          }
        },
      );
    });

    group('getCloudBackups', () {
      test('returns empty list when no cloud provider', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final backups = await service.getCloudBackups();
        expect(backups, isEmpty);
      });
    });

    group('exportBackupToPath', () {
      test('copies database to specified path', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final destPath = '${tempDir.path}/my_backup.db';

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final record = await service.exportBackupToPath(destPath);

          expect(fakeDb.lastBackupPath, destPath);
          expect(fakeDb.backupCallCount, 1);
          expect(record.localPath, destPath);
          expect(record.filename, 'my_backup.db');
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('records export in history', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final destPath = '${tempDir.path}/my_backup.db';

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          await service.exportBackupToPath(destPath);

          final history = preferences.getHistory();
          expect(history, hasLength(1));
          expect(history.first.localPath, destPath);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('exportBackupToTemp', () {
      test('copies database to temp directory', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final tempFile = await service.exportBackupToTemp();

        expect(fakeDb.backupCallCount, 1);
        expect(fakeDb.lastBackupPath, contains('submersion_backup_'));
        expect(fakeDb.lastBackupPath, endsWith('.db'));
        expect(tempFile.path, fakeDb.lastBackupPath);
      });

      test('does not record in history', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.exportBackupToTemp();

        final history = preferences.getHistory();
        expect(history, isEmpty);
      });
    });

    group('restoreFromFile', () {
      test('throws BackupException for non-existent file', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        expect(
          () => service.restoreFromFile('/nonexistent/file.db'),
          throwsA(isA<BackupException>()),
        );
      });

      test('creates pre-restore backup with history entry', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final backupFile = File('${tempDir.path}/test.db');
        await backupFile.writeAsString('fake db content');

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          await service.restoreFromFile(backupFile.path);

          // performBackup() creates a backup, then restore replaces the db
          expect(fakeDb.backupCallCount, 1); // pre-restore backup
          expect(fakeDb.restoreCallCount, 1); // restore
          expect(fakeDb.lastRestorePath, backupFile.path);

          // Pre-restore backup should appear in history
          final history = preferences.getHistory();
          expect(history, hasLength(1));
          expect(history.first.filename, contains('submersion_backup_'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('pre-restore backup uses configured backup location', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final customDir = await Directory.systemTemp.createTemp('custom_');
        final backupFile = File('${tempDir.path}/test.db');
        await backupFile.writeAsString('fake db content');

        await preferences.setBackupLocation(customDir.path);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          await service.restoreFromFile(backupFile.path);

          // Pre-restore backup should go to the custom location
          expect(fakeDb.lastBackupPath, startsWith(customDir.path));

          // And be recorded in history
          final history = preferences.getHistory();
          expect(history, hasLength(1));
          expect(history.first.localPath, startsWith(customDir.path));
        } finally {
          await tempDir.delete(recursive: true);
          await customDir.delete(recursive: true);
        }
      });
    });

    group('performBackup with custom location', () {
      test('uses custom backup location from settings', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');

        await preferences.setBackupLocation(tempDir.path);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          await service.performBackup();

          expect(fakeDb.lastBackupPath, startsWith(tempDir.path));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('falls back to default location when no custom location', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.performBackup();

        // Default location uses the _localBackupFolder path
        expect(fakeDb.lastBackupPath, contains('Submersion'));
        expect(fakeDb.lastBackupPath, contains('Backups'));
      });
    });

    group('getValidatedBackupHistory', () {
      test(
        'removes records where local file is gone and no cloud backup',
        () async {
          await preferences.addRecord(
            BackupRecord(
              id: 'gone',
              filename: 'gone.db',
              timestamp: DateTime(2025, 6, 1),
              sizeBytes: 1000,
              location: BackupLocation.local,
              diveCount: 5,
              siteCount: 2,
              localPath: '/this/file/does/not/exist.db',
            ),
          );
          await preferences.addRecord(
            BackupRecord(
              id: 'has-cloud',
              filename: 'cloud.db',
              timestamp: DateTime(2025, 7, 1),
              sizeBytes: 1000,
              location: BackupLocation.both,
              diveCount: 10,
              siteCount: 3,
              localPath: '/also/missing.db',
              cloudFileId: 'cloud-123',
            ),
          );

          final service = BackupService(
            dbAdapter: fakeDb,
            preferences: preferences,
          );

          final history = await service.getValidatedBackupHistory();

          // 'gone' should be pruned (local-only, file missing)
          // 'has-cloud' should be kept (has cloud backup)
          expect(history, hasLength(1));
          expect(history.first.id, 'has-cloud');
        },
      );

      test('keeps records where local file exists', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final realFile = File('${tempDir.path}/real.db');
        await realFile.writeAsString('data');

        await preferences.addRecord(
          BackupRecord(
            id: 'real',
            filename: 'real.db',
            timestamp: DateTime(2025, 6, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 5,
            siteCount: 2,
            localPath: realFile.path,
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final history = await service.getValidatedBackupHistory();
          expect(history, hasLength(1));
          expect(history.first.id, 'real');
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('keeps records with no localPath (legacy)', () async {
        await preferences.addRecord(
          BackupRecord(
            id: 'legacy',
            filename: 'legacy.db',
            timestamp: DateTime(2025, 6, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 5,
            siteCount: 2,
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final history = await service.getValidatedBackupHistory();
        expect(history, hasLength(1));
      });

      test('persists pruning to preferences', () async {
        await preferences.addRecord(
          BackupRecord(
            id: 'stale',
            filename: 'stale.db',
            timestamp: DateTime(2025, 6, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 5,
            siteCount: 2,
            localPath: '/nonexistent/stale.db',
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.getValidatedBackupHistory();

        // Stale record should be removed from preferences
        final rawHistory = preferences.getHistory();
        expect(rawHistory, isEmpty);
      });
    });

    group('pinBackup / unpinBackup', () {
      test('pinBackup flips pinned to true on the record', () async {
        final record = BackupRecord(
          id: 'pin-me',
          filename: 'backup.db',
          timestamp: DateTime(2025, 6, 15),
          sizeBytes: 1000,
          location: BackupLocation.local,
          diveCount: 5,
          siteCount: 2,
        );
        await preferences.addRecord(record);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.pinBackup('pin-me');

        final history = preferences.getHistory();
        expect(history.single.pinned, true);
      });

      test('unpinBackup flips pinned to false', () async {
        final record = BackupRecord(
          id: 'unpin-me',
          filename: 'backup.db',
          timestamp: DateTime(2025, 6, 15),
          sizeBytes: 1000,
          location: BackupLocation.local,
          diveCount: 5,
          siteCount: 2,
          pinned: true,
        );
        await preferences.addRecord(record);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.unpinBackup('unpin-me');

        final history = preferences.getHistory();
        expect(history.single.pinned, false);
      });

      test('pinBackup is a no-op for unknown ids (does not throw)', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await expectLater(service.pinBackup('unknown'), completes);

        expect(preferences.getHistory(), isEmpty);
      });
    });

    group('pruneOldBackups type + pinned isolation', () {
      test('only prunes manual records, never pre-migration', () async {
        // Seed 3 manual records + 2 pre-migration records
        for (var i = 0; i < 3; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'm$i',
              filename: 'm$i.db',
              timestamp: DateTime(2026, 1, 1 + i),
              sizeBytes: 1,
              location: BackupLocation.local,
              type: BackupType.manual,
            ),
          );
        }
        for (var i = 0; i < 2; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'p$i',
              filename: 'p$i.db',
              timestamp: DateTime(2025, 1, 1 + i), // older than manuals
              sizeBytes: 1,
              location: BackupLocation.local,
              type: BackupType.preMigration,
              fromSchemaVersion: 63,
              toSchemaVersion: 64,
            ),
          );
        }

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        // Prune to keep 1 — should delete 2 manual, keep all pre-migration
        await service.pruneOldBackups(1);

        final remaining = preferences.getHistory();
        final manualCount = remaining
            .where((r) => r.type == BackupType.manual)
            .length;
        final preMigCount = remaining
            .where((r) => r.type == BackupType.preMigration)
            .length;
        expect(manualCount, 1, reason: 'should keep only 1 manual');
        expect(preMigCount, 2, reason: 'pre-migration untouched');
      });

      test('does not prune pinned manual records', () async {
        // Seed 3 manual records, middle one pinned
        await preferences.addRecord(
          BackupRecord(
            id: 'm0',
            filename: 'm0.db',
            timestamp: DateTime(2026, 1, 1),
            sizeBytes: 1,
            location: BackupLocation.local,
            type: BackupType.manual,
          ),
        );
        await preferences.addRecord(
          BackupRecord(
            id: 'm1-pinned',
            filename: 'm1.db',
            timestamp: DateTime(2026, 1, 2),
            sizeBytes: 1,
            location: BackupLocation.local,
            type: BackupType.manual,
            pinned: true,
          ),
        );
        await preferences.addRecord(
          BackupRecord(
            id: 'm2',
            filename: 'm2.db',
            timestamp: DateTime(2026, 1, 3),
            sizeBytes: 1,
            location: BackupLocation.local,
            type: BackupType.manual,
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        // Prune to keep 1 — should keep newest (m2) + pinned (m1-pinned), drop m0
        await service.pruneOldBackups(1);

        final remaining = preferences.getHistory();
        final ids = remaining.map((r) => r.id).toSet();
        expect(ids, contains('m1-pinned'));
        expect(ids, contains('m2'));
        expect(ids, isNot(contains('m0')));
      });

      test('keepCount applies only to unpinned manual records', () async {
        // 2 pinned + 5 unpinned manuals
        for (var i = 0; i < 2; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'pinned-$i',
              filename: 'p$i.db',
              timestamp: DateTime(2026, 1, 1 + i),
              sizeBytes: 1,
              location: BackupLocation.local,
              type: BackupType.manual,
              pinned: true,
            ),
          );
        }
        for (var i = 0; i < 5; i++) {
          await preferences.addRecord(
            BackupRecord(
              id: 'u$i',
              filename: 'u$i.db',
              timestamp: DateTime(2026, 2, 1 + i),
              sizeBytes: 1,
              location: BackupLocation.local,
              type: BackupType.manual,
            ),
          );
        }

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        // Keep 2 unpinned manuals; all 2 pinned stay
        await service.pruneOldBackups(2);

        final remaining = preferences.getHistory();
        final pinnedCount = remaining.where((r) => r.pinned).length;
        final unpinnedCount = remaining.where((r) => !r.pinned).length;
        expect(pinnedCount, 2);
        expect(unpinnedCount, 2);
      });
    });

    group('BackupSettings integration', () {
      test('isBackupDue returns true when never backed up', () {
        const settings = BackupSettings(enabled: true);
        expect(settings.isBackupDue, true);
      });

      test('isBackupDue returns false when recently backed up', () {
        final settings = BackupSettings(
          enabled: true,
          frequency: BackupFrequency.daily,
          lastBackupTime: DateTime.now().subtract(const Duration(hours: 12)),
        );
        expect(settings.isBackupDue, false);
      });

      test('isBackupDue returns true when backup is overdue', () {
        final settings = BackupSettings(
          enabled: true,
          frequency: BackupFrequency.daily,
          lastBackupTime: DateTime.now().subtract(const Duration(hours: 25)),
        );
        expect(settings.isBackupDue, true);
      });

      test('isBackupDue returns false when disabled', () {
        const settings = BackupSettings(enabled: false);
        expect(settings.isBackupDue, false);
      });

      test('frequencyDuration is correct for each frequency', () {
        expect(
          const BackupSettings(
            frequency: BackupFrequency.daily,
          ).frequencyDuration,
          const Duration(days: 1),
        );
        expect(
          const BackupSettings(
            frequency: BackupFrequency.weekly,
          ).frequencyDuration,
          const Duration(days: 7),
        );
        expect(
          const BackupSettings(
            frequency: BackupFrequency.monthly,
          ).frequencyDuration,
          const Duration(days: 30),
        );
      });
    });
  });
}
