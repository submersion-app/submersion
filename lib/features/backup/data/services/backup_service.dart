import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

/// Thin interface for the database operations BackupService needs.
///
/// Allows injecting a fake in tests without depending on the
/// [DatabaseService] singleton directly.
abstract class BackupDatabaseAdapter {
  Future<void> backup(String destinationPath);
  Future<void> restore(String backupPath);
  Future<String> get databasePath;
  AppDatabase get database;
}

/// Default adapter that delegates to [DatabaseService.instance].
class DefaultBackupDatabaseAdapter implements BackupDatabaseAdapter {
  final DatabaseService _dbAdapter;

  const DefaultBackupDatabaseAdapter(this._dbAdapter);

  @override
  Future<void> backup(String destinationPath) =>
      _dbAdapter.backup(destinationPath);

  @override
  Future<void> restore(String backupPath) => _dbAdapter.restore(backupPath);

  @override
  Future<String> get databasePath => _dbAdapter.databasePath;

  @override
  AppDatabase get database => _dbAdapter.database;
}

/// Core backup service handling backup creation, restore, pruning, and cloud upload.
///
/// Dependencies are constructor-injected for testability.
/// Cloud provider is optional — backups work locally without it.
class BackupService {
  final BackupDatabaseAdapter _dbAdapter;
  final BackupPreferences _preferences;
  final CloudStorageProvider? _cloudProvider;
  final _log = LoggerService.forClass(BackupService);
  final _uuid = const Uuid();

  static const String _localBackupFolder = 'Submersion/Backups';
  static const String _cloudBackupFolder = 'Submersion Backups';

  BackupService({
    required BackupDatabaseAdapter dbAdapter,
    required BackupPreferences preferences,
    CloudStorageProvider? cloudProvider,
  }) : _dbAdapter = dbAdapter,
       _preferences = preferences,
       _cloudProvider = cloudProvider;

  // ===========================================================================
  // Backup
  // ===========================================================================

  /// Create a new backup of the current database.
  ///
  /// Returns the [BackupRecord] describing the created backup.
  /// If cloud provider is available and cloud backup is enabled,
  /// the backup is also uploaded to cloud storage.
  Future<BackupRecord> performBackup({bool isAutomatic = false}) async {
    _log.info('Starting backup (automatic: $isAutomatic)');

    final filename = _generateFilename();
    final localDir = await getLocalBackupsDirectory();
    final localPath = p.join(localDir, filename);

    // Copy the database file
    await _dbAdapter.backup(localPath);

    // Get file size
    final backupFile = File(localPath);
    final sizeBytes = await backupFile.length();

    // Get dive and site counts
    final counts = await _getDiveSiteCounts();

    // Attempt cloud upload
    String? cloudFileId;
    var location = BackupLocation.local;

    final settings = _preferences.getSettings();
    if (settings.cloudBackupEnabled && _cloudProvider != null) {
      try {
        cloudFileId = await _uploadToCloud(localPath, filename);
        location = BackupLocation.both;
        _log.info('Backup uploaded to cloud: $cloudFileId');
      } catch (e, stack) {
        _log.error('Cloud upload failed, backup is local-only', e, stack);
        // Local backup still succeeded — continue with local-only
      }
    }

    final record = BackupRecord(
      id: _uuid.v4(),
      filename: filename,
      timestamp: DateTime.now(),
      sizeBytes: sizeBytes,
      location: location,
      diveCount: counts.diveCount,
      siteCount: counts.siteCount,
      cloudFileId: cloudFileId,
      localPath: localPath,
      isAutomatic: isAutomatic,
    );

    // Persist record and update last backup time
    await _preferences.addRecord(record);
    await _preferences.setLastBackupTime(record.timestamp);

    // Prune old backups
    await pruneOldBackups(settings.retentionCount);

    _log.info('Backup completed: ${record.filename} (${record.formattedSize})');
    return record;
  }

  // ===========================================================================
  // Restore
  // ===========================================================================

  /// Restore the database from a backup record.
  ///
  /// Creates a safety backup of the current database first,
  /// then replaces the database with the backup.
  Future<void> restoreFromBackup(BackupRecord record) async {
    _log.info('Starting restore from: ${record.filename}');

    // Create safety backup first
    _log.info('Creating safety backup before restore');
    await performBackup(isAutomatic: true);

    // Determine backup source path
    String sourcePath;
    if (record.localPath != null && await File(record.localPath!).exists()) {
      sourcePath = record.localPath!;
    } else if (record.cloudFileId != null && _cloudProvider != null) {
      // Download from cloud to a temp location
      _log.info('Downloading backup from cloud');
      sourcePath = await _downloadFromCloud(
        record.cloudFileId!,
        record.filename,
      );
    } else {
      throw const BackupException('Backup file not found locally or in cloud');
    }

    // Restore using DatabaseService (handles close/copy/reinitialize)
    await _dbAdapter.restore(sourcePath);

    _log.info('Restore completed from: ${record.filename}');
  }

  // ===========================================================================
  // History & Management
  // ===========================================================================

  /// Get all backup records sorted by timestamp descending.
  List<BackupRecord> getBackupHistory() {
    final history = _preferences.getHistory();
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  /// Delete a specific backup (local file + cloud file + metadata).
  Future<void> deleteBackup(BackupRecord record) async {
    _log.info('Deleting backup: ${record.filename}');

    // Delete local file
    if (record.localPath != null) {
      final file = File(record.localPath!);
      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted local file: ${record.localPath}');
      }
    }

    // Delete cloud file
    if (record.cloudFileId != null && _cloudProvider != null) {
      try {
        await _cloudProvider.deleteFile(record.cloudFileId!);
        _log.info('Deleted cloud file: ${record.cloudFileId}');
      } catch (e, stack) {
        _log.error('Failed to delete cloud file', e, stack);
        // Continue with removing the record even if cloud delete fails
      }
    }

    // Remove from history
    await _preferences.removeRecord(record.id);
    _log.info('Backup deleted: ${record.filename}');
  }

  /// Remove old backups beyond the retention count.
  ///
  /// Keeps the [keepCount] most recent backups and deletes the rest.
  Future<void> pruneOldBackups(int keepCount) async {
    final history = getBackupHistory(); // Already sorted newest-first
    if (history.length <= keepCount) return;

    final toDelete = history.sublist(keepCount);
    _log.info('Pruning ${toDelete.length} old backups (keeping $keepCount)');

    for (final record in toDelete) {
      await deleteBackup(record);
    }
  }

  // ===========================================================================
  // Cloud Operations
  // ===========================================================================

  /// List backup files available in cloud storage.
  Future<List<CloudFileInfo>> getCloudBackups() async {
    if (_cloudProvider == null) return [];

    try {
      final folderId = await _getOrCreateCloudBackupFolder();
      if (folderId == null) return [];

      final files = await _cloudProvider.listFiles(
        folderId: folderId,
        namePattern: 'submersion_backup_',
      );

      // Sort newest first
      files.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      return files;
    } catch (e, stack) {
      _log.error('Failed to list cloud backups', e, stack);
      return [];
    }
  }

  // ===========================================================================
  // File System Helpers
  // ===========================================================================

  /// Get the local backups directory, creating it if needed.
  Future<String> getLocalBackupsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, _localBackupFolder));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  String _generateFilename() {
    final dateFormat = DateFormat('yyyy-MM-dd_HHmmss');
    final timestamp = dateFormat.format(DateTime.now());
    return 'submersion_backup_$timestamp.sqlite';
  }

  Future<({int diveCount, int siteCount})> _getDiveSiteCounts() async {
    try {
      final db = _dbAdapter.database;
      final diveResult = await db
          .customSelect('SELECT COUNT(*) AS c FROM dives')
          .getSingle();
      final siteResult = await db
          .customSelect('SELECT COUNT(*) AS c FROM dive_sites')
          .getSingle();
      return (
        diveCount: diveResult.read<int>('c'),
        siteCount: siteResult.read<int>('c'),
      );
    } catch (e) {
      _log.error('Failed to get counts, using 0', e);
      return (diveCount: 0, siteCount: 0);
    }
  }

  Future<String?> _uploadToCloud(String localPath, String filename) async {
    if (_cloudProvider == null) return null;

    final folderId = await _getOrCreateCloudBackupFolder();
    if (folderId == null) return null;

    final bytes = await File(localPath).readAsBytes();
    final result = await _cloudProvider.uploadFile(
      Uint8List.fromList(bytes),
      filename,
      folderId: folderId,
    );
    return result.fileId;
  }

  Future<String> _downloadFromCloud(String cloudFileId, String filename) async {
    if (_cloudProvider == null) {
      throw const BackupException('No cloud provider available for download');
    }

    final bytes = await _cloudProvider.downloadFile(cloudFileId);
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, filename);
    await File(tempPath).writeAsBytes(bytes);
    return tempPath;
  }

  Future<String?> _getOrCreateCloudBackupFolder() async {
    if (_cloudProvider == null) return null;

    try {
      return await _cloudProvider.createFolder(_cloudBackupFolder);
    } catch (e, stack) {
      _log.error('Failed to get/create cloud backup folder', e, stack);
      return null;
    }
  }
}

/// Exception thrown by backup operations
class BackupException implements Exception {
  final String message;

  const BackupException(this.message);

  @override
  String toString() => 'BackupException: $message';
}
