import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

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
              filename: 'backup_$i.sqlite',
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
              filename: 'backup_$i.sqlite',
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
              filename: 'backup_$i.sqlite',
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
              filename: 'backup_$i.sqlite',
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
          filename: 'backup.sqlite',
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
          filename: 'backup.sqlite',
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
          filename: 'backup.sqlite',
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
            filename: 'old.sqlite',
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
            filename: 'new.sqlite',
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
            filename: 'mid.sqlite',
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
