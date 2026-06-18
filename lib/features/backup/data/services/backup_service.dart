import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';

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
  final SyncRepository _syncRepository;

  /// Library epoch persistence for restore Replace mode. Nullable so existing
  /// constructions keep working; Replace mode is a no-op without it.
  final LibraryEpochStore? _epochStore;

  /// Set on a Merge restore so the next launch forces one reconciling sync.
  /// Nullable so existing constructions keep working.
  final PostRestoreSyncStore? _postRestoreSyncStore;
  final _log = LoggerService.forClass(BackupService);
  final _uuid = const Uuid();

  static const String _localBackupFolder = 'Submersion/Backups';
  static const String _cloudBackupFolder = 'Submersion Backups';

  BackupService({
    required BackupDatabaseAdapter dbAdapter,
    required BackupPreferences preferences,
    CloudStorageProvider? cloudProvider,
    SyncRepository? syncRepository,
    LibraryEpochStore? epochStore,
    PostRestoreSyncStore? postRestoreSyncStore,
  }) : _dbAdapter = dbAdapter,
       _preferences = preferences,
       _cloudProvider = cloudProvider,
       _syncRepository = syncRepository ?? SyncRepository(),
       _epochStore = epochStore,
       _postRestoreSyncStore = postRestoreSyncStore;

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
    final localDir = await getBackupsDirectory();
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
        _log.error(
          'Cloud upload failed, backup is local-only',
          error: e,
          stackTrace: stack,
        );
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

  /// Export a backup to a user-specified file path.
  ///
  /// Records the export in backup history with the actual destination path.
  Future<BackupRecord> exportBackupToPath(String destinationPath) async {
    _log.info('Exporting backup to: $destinationPath');

    await _dbAdapter.backup(destinationPath);

    final filename = p.basename(destinationPath);
    final counts = await _getDiveSiteCounts();

    // Get size of the backup file
    final backupFile = File(destinationPath);
    final sizeBytes = await backupFile.exists() ? await backupFile.length() : 0;

    final record = BackupRecord(
      id: _uuid.v4(),
      filename: filename,
      timestamp: DateTime.now(),
      sizeBytes: sizeBytes,
      location: BackupLocation.local,
      diveCount: counts.diveCount,
      siteCount: counts.siteCount,
      localPath: destinationPath,
    );

    await _preferences.addRecord(record);
    await _preferences.setLastBackupTime(record.timestamp);

    _log.info('Export completed: $filename');
    return record;
  }

  /// Export a backup to a temporary file for sharing.
  ///
  /// The file is NOT recorded in backup history since its destination
  /// is ephemeral (share sheet, AirDrop, email, etc.).
  /// Returns the temporary [File] for use with share sheet.
  Future<File> exportBackupToTemp() async {
    _log.info('Exporting backup to temp for sharing');

    final filename = _generateFilename();
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, filename);

    await _dbAdapter.backup(tempPath);

    _log.info('Temp export completed: $filename');
    return File(tempPath);
  }

  /// Validate whether a file is a valid Submersion backup.
  ///
  /// Checks: file exists, has correct extension, is a valid SQLite database,
  /// and contains expected Submersion tables.
  Future<BackupValidationResult> validateBackupFile(String filePath) async {
    final file = File(filePath);

    // Check file exists
    if (!await file.exists()) {
      return const BackupValidationResult.invalid('File not found');
    }

    // Check extension
    final ext = p.extension(filePath).toLowerCase();
    if (ext != '.sqlite' && ext != '.db') {
      return BackupValidationResult.invalid(
        'Invalid file extension "$ext". Expected .db or .sqlite',
      );
    }

    // Check file size
    final sizeBytes = await file.length();
    if (sizeBytes == 0) {
      return const BackupValidationResult.invalid('File is empty');
    }

    // Use sqlite3 directly in read-only mode to avoid Drift's migration
    // system triggering ALTER TABLE on older-schema backups. The backup file
    // may also be in a read-only sandboxed directory (iOS/macOS file picker).
    try {
      final testDb = sqlite3.sqlite3.open(
        filePath,
        mode: sqlite3.OpenMode.readOnly,
      );
      try {
        // Verify it's a valid SQLite database
        testDb.execute('SELECT 1');

        // Check for expected Submersion tables
        final tables = testDb.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('dives', 'dive_sites')",
        );

        if (tables.isEmpty) {
          return const BackupValidationResult.invalid(
            'File does not appear to be a Submersion backup (missing expected tables)',
          );
        }

        return BackupValidationResult.valid(sizeBytes: sizeBytes);
      } finally {
        testDb.dispose();
      }
    } catch (e) {
      return BackupValidationResult.invalid('File is not a valid database: $e');
    }
  }

  // ===========================================================================
  // Restore
  // ===========================================================================

  /// Restore the database from a backup record.
  ///
  /// Creates a full backup of the current database first (saved to the
  /// configured backup location with a history entry), then replaces
  /// the database with the backup. [RestoreMode.replace] additionally mints
  /// a pending replace intent (see [RestoreMode]).
  Future<void> restoreFromBackup(
    BackupRecord record, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    _log.info('Starting restore from: ${record.filename} (mode: $mode)');

    // Create a proper backup before restoring so the user can find it
    // in their configured backup location and in the history list.
    await performBackup();

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

    // Parity with the file-picker path: the file on disk (or the fresh
    // download) may have been corrupted since the record was written.
    final validation = await validateBackupFile(sourcePath);
    if (!validation.isValid) {
      throw BackupException(
        validation.error ?? 'Backup file failed validation',
      );
    }

    // Restore using DatabaseService (handles close/copy/reinitialize), then
    // re-baseline sync so the restored data syncs cleanly instead of replaying
    // the backup's stale sync position.
    await _replaceDatabaseAndRebaselineSync(sourcePath);
    if (mode == RestoreMode.replace) {
      await _mintPendingReplace();
    } else {
      // Merge: the restore dialog's choice is the consent. Arm a one-shot
      // intent so the next launch forces a gate-bypassing reconciling sync.
      await _postRestoreSyncStore?.setPending();
    }

    _log.info('Restore completed from: ${record.filename}');
  }

  /// Restore the database from an arbitrary file path.
  ///
  /// Creates a full backup of the current database first (saved to the
  /// configured backup location with a history entry), then replaces
  /// the database with the specified file. [RestoreMode.replace] additionally
  /// mints a pending replace intent (see [RestoreMode]).
  /// Throws [BackupException] if the file is not found.
  Future<void> restoreFromFile(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    _log.info('Starting restore from file: $filePath (mode: $mode)');

    final file = File(filePath);
    if (!await file.exists()) {
      throw const BackupException('Backup file not found');
    }

    // Create a proper backup before restoring so the user can find it
    // in their configured backup location and in the history list.
    await performBackup();

    // Restore using DatabaseService, then re-baseline sync (see
    // _replaceDatabaseAndRebaselineSync).
    await _replaceDatabaseAndRebaselineSync(filePath);
    if (mode == RestoreMode.replace) {
      await _mintPendingReplace();
    } else {
      // Merge: the restore dialog's choice is the consent. Arm a one-shot
      // intent so the next launch forces a gate-bypassing reconciling sync.
      await _postRestoreSyncStore?.setPending();
    }

    _log.info('Restore from file completed: ${p.basename(filePath)}');
  }

  /// Replace the database with [sourcePath], then re-baseline sync.
  ///
  /// A restore swaps in the backup's entire database — including its stale sync
  /// metadata (device id, HLC clock, last-sync timestamp, cursors) and deletion
  /// log. Without re-baselining, the rewound `lastSync` makes the merge treat
  /// almost every restored row as a conflict, so sync stalls and deletes
  /// resurrect from a peer's still-live copy. This preserves the live device
  /// identity (captured before the swap) and clears the sync position so the
  /// next sync cleanly reconciles the restored data.
  Future<void> _replaceDatabaseAndRebaselineSync(String sourcePath) async {
    String liveDeviceId;
    try {
      liveDeviceId = await _syncRepository.getDeviceId();
    } catch (e, st) {
      // Fall back to a fresh device id rather than letting the restore adopt
      // the backup's id. Adopting it would make this install impersonate the
      // device that produced the backup (colliding per-device sync file and
      // HLC node identity). A fresh id keeps this install distinct; the
      // launch-time reconcile realigns it to the mirrored identity if one
      // exists.
      liveDeviceId = const Uuid().v4();
      _log.warning(
        "Could not capture device id before restore; preserving a fresh "
        "device id instead of adopting the backup's",
        error: e,
        stackTrace: st,
      );
    }

    // Capture the live library epoch alongside the device id: the restored
    // DB carries the backup's stale epoch, which without this would wrongly
    // re-prompt this device to adopt its own current library.
    String? liveEpochId;
    try {
      liveEpochId =
          await _syncRepository.getLastAcceptedEpochId() ??
          _epochStore?.lastAcceptedEpochId;
    } catch (_) {
      liveEpochId = _epochStore?.lastAcceptedEpochId;
    }

    await _dbAdapter.restore(sourcePath);

    try {
      await _syncRepository.rebaselineAfterRestore(
        preserveDeviceId: liveDeviceId,
        preserveEpochId: liveEpochId,
      );
    } catch (e, st) {
      // Non-fatal: the data restore itself succeeded. If re-baselining failed,
      // the user can recover by running "Reset Sync State" manually.
      _log.error(
        'Failed to re-baseline sync after restore',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Mint and persist the pending-replace intent. The cloud side executes on
  /// the next sync (typically the post-restart launch sync); until it lands,
  /// the intent fences off merging.
  Future<void> _mintPendingReplace() async {
    final store = _epochStore;
    if (store == null) {
      _log.warning('Replace mode requested but no epoch store is configured');
      return;
    }
    String deviceId;
    try {
      deviceId = await _syncRepository.getDeviceId();
    } catch (_) {
      // Non-empty sentinel: the marker's origin is shown in peer banners
      // and dialogs, so it must always be displayable.
      deviceId = 'unknown';
    }
    String? deviceName;
    try {
      deviceName = Platform.localHostname;
    } catch (_) {
      deviceName = null;
    }
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = null;
    }
    final marker = LibraryEpochMarker(
      epochId: _uuid.v4(),
      replacedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      deviceName: deviceName,
      appVersion: appVersion,
    );
    await store.setPendingReplace(marker);
    _log.info('Minted pending library replace (epoch ${marker.epochId})');
  }

  // ===========================================================================
  // History & Management
  // ===========================================================================

  /// Get all backup records sorted by timestamp descending.
  List<BackupRecord> getBackupHistory() {
    final history = _preferences.getHistory();
    return [...history]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get backup history with stale entry pruning.
  ///
  /// Checks each record's local file existence. Removes records where:
  /// - localPath is set but file no longer exists
  /// - AND there is no cloud backup (cloudFileId is null)
  ///
  /// Records with no localPath (legacy) or with cloud backups are kept.
  Future<List<BackupRecord>> getValidatedBackupHistory() async {
    final history = _preferences.getHistory();
    final validRecords = <BackupRecord>[];
    var pruned = false;

    for (final record in history) {
      if (record.localPath != null && record.cloudFileId == null) {
        final file = File(record.localPath!);
        if (!await file.exists()) {
          _log.info('Pruning stale backup record: ${record.filename}');
          pruned = true;
          continue;
        }
      }
      validRecords.add(record);
    }

    if (pruned) {
      await _preferences.setHistory(validRecords);
    }

    return [...validRecords]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
        _log.error('Failed to delete cloud file', error: e, stackTrace: stack);
        // Continue with removing the record even if cloud delete fails
      }
    }

    // Remove from history
    await _preferences.removeRecord(record.id);
    _log.info('Backup deleted: ${record.filename}');
  }

  /// Pin a backup record so it is excluded from automatic pruning.
  Future<void> pinBackup(String id) => _setPinned(id, true);

  /// Unpin a backup record so it is subject to automatic pruning again.
  Future<void> unpinBackup(String id) => _setPinned(id, false);

  Future<void> _setPinned(String id, bool pinned) async {
    final history = _preferences.getHistory();
    BackupRecord? match;
    for (final r in history) {
      if (r.id == id) {
        match = r;
        break;
      }
    }
    if (match == null) return;
    await _preferences.updateRecord(match.copyWith(pinned: pinned));
  }

  /// Remove old backups beyond the retention count.
  ///
  /// Only prunes manual, unpinned records. Pre-migration records have their
  /// own retention managed by PreMigrationBackupService. Pinned records are
  /// exempt from all automatic retention.
  ///
  /// Keeps the [keepCount] most recent unpinned manual backups and deletes
  /// the rest.
  Future<void> pruneOldBackups(int keepCount) async {
    final history = getBackupHistory(); // Already sorted newest-first

    final eligible = history
        .where((r) => r.type == BackupType.manual && !r.pinned)
        .toList();
    if (eligible.length <= keepCount) return;

    final toDelete = eligible.sublist(keepCount);
    _log.info(
      'Pruning ${toDelete.length} old manual backups (keeping $keepCount)',
    );

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
      _log.error('Failed to list cloud backups', error: e, stackTrace: stack);
      return [];
    }
  }

  // ===========================================================================
  // File System Helpers
  // ===========================================================================

  /// Resolves the backups directory using the given preferences, without
  /// needing a full BackupService instance. Used by startup paths that
  /// run before Riverpod is established and before the DB is open.
  static Future<String> resolveBackupsDirectory(
    BackupPreferences preferences,
  ) async {
    final settings = preferences.getSettings();
    if (settings.backupLocation != null) {
      final customDir = Directory(settings.backupLocation!);
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }
      return customDir.path;
    }
    return resolveDefaultBackupsDirectory();
  }

  /// The default backups directory inside the app's sandbox documents dir.
  ///
  /// Always writable (it lives inside the app container), so it doubles as the
  /// safe fallback when a user-chosen custom location is unreachable -- see
  /// PreMigrationBackupService. Unlike [resolveBackupsDirectory] this ignores
  /// any configured custom location by design.
  static Future<String> resolveDefaultBackupsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, _localBackupFolder));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  /// Get the active backups directory (custom or default), creating it if needed.
  Future<String> getBackupsDirectory() =>
      BackupService.resolveBackupsDirectory(_preferences);

  /// Get the local backups directory, creating it if needed.
  ///
  /// Direct-path version bypassing the custom-location check; preserved for
  /// existing callers that want the default location specifically.
  Future<String> getLocalBackupsDirectory() =>
      BackupService.resolveDefaultBackupsDirectory();

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  String _generateFilename() {
    final dateFormat = DateFormat('yyyy-MM-dd_HHmmss');
    final timestamp = dateFormat.format(DateTime.now());
    return 'submersion_backup_$timestamp.db';
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
      _log.error('Failed to get counts, using 0', error: e);
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
      _log.error(
        'Failed to get/create cloud backup folder',
        error: e,
        stackTrace: stack,
      );
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

/// Result of validating a backup file
class BackupValidationResult {
  final bool isValid;
  final String? error;
  final int? sizeBytes;

  const BackupValidationResult({
    required this.isValid,
    this.error,
    this.sizeBytes,
  });

  const BackupValidationResult.valid({this.sizeBytes})
    : isValid = true,
      error = null;

  const BackupValidationResult.invalid(String this.error)
    : isValid = false,
      sizeBytes = null;
}
