import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';

/// Result of a database migration operation
class MigrationResult {
  final bool success;
  final String? errorMessage;
  final String? oldPath;
  final String? newPath;
  final String? backupPath;

  const MigrationResult._({
    required this.success,
    this.errorMessage,
    this.oldPath,
    this.newPath,
    this.backupPath,
  });

  factory MigrationResult.success({
    required String oldPath,
    required String newPath,
    String? backupPath,
  }) {
    return MigrationResult._(
      success: true,
      oldPath: oldPath,
      newPath: newPath,
      backupPath: backupPath,
    );
  }

  factory MigrationResult.failure(String errorMessage) {
    return MigrationResult._(success: false, errorMessage: errorMessage);
  }
}

/// Information about an existing database found at a location
class ExistingDatabaseInfo {
  final String path;
  final int userCount;
  final int diveCount;
  final int siteCount;
  final int tripCount;
  final int buddyCount;
  final int fileSize;
  final DateTime? lastModified;

  const ExistingDatabaseInfo({
    required this.path,
    required this.userCount,
    required this.diveCount,
    required this.siteCount,
    required this.tripCount,
    required this.buddyCount,
    required this.fileSize,
    this.lastModified,
  });

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service for safely migrating the database between storage locations
class DatabaseMigrationService {
  final DatabaseService _dbService;
  final DatabaseLocationService _locationService;

  DatabaseMigrationService(this._dbService, this._locationService);

  static const Duration _functionalCheckTimeout = Duration(seconds: 10);
  static const Duration _infoQueryTimeout = Duration(seconds: 5);
  static const Duration _checkpointTimeout = Duration(seconds: 10);

  Future<T> _withTimeout<T>(
    Future<T> future,
    String operation, {
    required Duration timeout,
  }) async {
    return future.timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('$operation timed out.');
      },
    );
  }

  /// Check if an existing Submersion database exists at the given folder
  Future<ExistingDatabaseInfo?> checkForExistingDatabase(
    String folderPath,
  ) async {
    final dbPath = p.join(folderPath, DatabaseLocationService.databaseFilename);
    final file = File(dbPath);

    if (!await file.exists()) {
      return null;
    }

    try {
      final currentPath = await _dbService.databasePath;
      if (currentPath == dbPath) {
        return await getCurrentDatabaseInfo();
      }

      final stat = await file.stat();
      final fileSize = stat.size;
      final lastModified = stat.modified;

      // Try to open the database and count records
      var counts = const _DatabaseCounts(
        userCount: 0,
        diveCount: 0,
        siteCount: 0,
        tripCount: 0,
        buddyCount: 0,
      );

      try {
        counts = await _fetchDatabaseCounts(dbPath);
      } catch (e) {
        // Could not read database, but file exists
      }

      return ExistingDatabaseInfo(
        path: dbPath,
        userCount: counts.userCount,
        diveCount: counts.diveCount,
        siteCount: counts.siteCount,
        tripCount: counts.tripCount,
        buddyCount: counts.buddyCount,
        fileSize: fileSize,
        lastModified: lastModified,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get info about the current database
  Future<ExistingDatabaseInfo?> getCurrentDatabaseInfo() async {
    final currentPath = await _dbService.databasePath;
    final file = File(currentPath);

    if (!await file.exists()) {
      return null;
    }

    try {
      final stat = await file.stat();
      final fileSize = stat.size;
      final lastModified = stat.modified;

      // Count from current open database
      int userCount = 0;
      int diveCount = 0;
      int siteCount = 0;
      int tripCount = 0;
      int buddyCount = 0;

      try {
        final db = _dbService.database;
        final row = await _withTimeout(
          db.customSelect('''
            SELECT
              (SELECT COUNT(*) FROM divers) AS user_count,
              (SELECT COUNT(*) FROM dives) AS dive_count,
              (SELECT COUNT(*) FROM dive_sites) AS site_count,
              (SELECT COUNT(*) FROM trips) AS trip_count,
              (SELECT COUNT(*) FROM buddies) AS buddy_count
          ''').getSingle(),
          'Database counts query',
          timeout: _infoQueryTimeout,
        );
        userCount = _parseCountValue(row.data['user_count']);
        diveCount = _parseCountValue(row.data['dive_count']);
        siteCount = _parseCountValue(row.data['site_count']);
        tripCount = _parseCountValue(row.data['trip_count']);
        buddyCount = _parseCountValue(row.data['buddy_count']);
      } catch (e) {
        // Could not read counts
      }

      return ExistingDatabaseInfo(
        path: currentPath,
        userCount: userCount,
        diveCount: diveCount,
        siteCount: siteCount,
        tripCount: tripCount,
        buddyCount: buddyCount,
        fileSize: fileSize,
        lastModified: lastModified,
      );
    } catch (e) {
      return null;
    }
  }

  /// Migrate the database to a new custom folder location
  ///
  /// This will:
  /// 1. Create a backup of the current database
  /// 2. Copy the database to the new location
  /// 3. Verify the copy's integrity
  /// 4. Update the storage configuration
  /// 5. Reinitialize the database from the new location
  Future<MigrationResult> migrateToCustomFolder(String folderPath) async {
    final currentPath = await _dbService.databasePath;
    final newPath = p.join(
      folderPath,
      DatabaseLocationService.databaseFilename,
    );

    // Don't migrate if paths are the same
    if (currentPath == newPath) {
      return MigrationResult.failure('Database is already at this location');
    }

    // Verify destination folder is writable
    if (!await _locationService.verifyFolderAccessible(folderPath)) {
      return MigrationResult.failure(
        'Cannot write to the selected folder. Please check permissions.',
      );
    }

    String? backupPath;

    // Mark migration in progress to prevent other code from accessing the database
    _dbService.beginMigration();

    try {
      // Ensure WAL is checkpointed before closing to avoid copying an
      // inconsistent database state.
      await _checkpointWal();

      // Step 1: Close the current database FIRST to release file locks
      // This is critical on macOS/iOS where WAL mode locks the -shm file
      await _dbService.close();

      // Small delay to ensure file locks are fully released
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 2: Create timestamped backup of current database (now that it's closed)
      backupPath = await _createBackup(currentPath);

      // Step 3: Copy database files to new location
      await _copyDatabaseFiles(currentPath, newPath);

      // Step 4: Verify the copy's integrity
      final debugInfo = StringBuffer();
      final isValid = await verifyDatabaseIntegrity(
        newPath,
        debugInfo: debugInfo,
      );
      if (!isValid) {
        // Rollback: reopen from original
        await _dbService.reinitializeAtPath(currentPath);
        _dbService.endMigration();
        return MigrationResult.failure(
          'Database integrity check failed after copy. Original database restored.\n${debugInfo.toString()}',
        );
      }

      // Step 5: Update storage configuration
      await _locationService.saveStorageConfig(
        StorageConfig(
          mode: StorageLocationMode.customFolder,
          customFolderPath: folderPath,
          lastVerified: DateTime.now(),
        ),
      );

      // Step 5b: Create security-scoped bookmark for persistent access (macOS)
      final bookmarkCreated = await _locationService.createAndStoreBookmark(
        folderPath,
      );
      if (!bookmarkCreated) {
        // Log warning but don't fail - bookmark is optional for persistence
        // Access will work during this session, but may fail after restart
      }

      // Step 6: Reinitialize from new location
      await _dbService.reinitializeAtPath(newPath);

      // Step 7: Verify database is functional
      final isWorking = await _verifyDatabaseFunctional();
      if (!isWorking) {
        // Rollback
        await _rollbackToOriginal(currentPath, backupPath);
        _dbService.endMigration();
        return MigrationResult.failure(
          'Database failed to initialize at new location. Original database restored.',
        );
      }

      _dbService.endMigration();
      return MigrationResult.success(
        oldPath: currentPath,
        newPath: newPath,
        backupPath: backupPath,
      );
    } catch (e) {
      // Rollback on any error
      try {
        await _rollbackToOriginal(currentPath, backupPath);
      } catch (_) {}
      _dbService.endMigration();
      return MigrationResult.failure('Migration failed: $e');
    }
  }

  /// Migrate the database back to the default app location
  Future<MigrationResult> migrateToDefault() async {
    final currentPath = await _dbService.databasePath;
    final defaultDir = await _locationService.getDefaultDatabaseDirectory();
    final newPath = p.join(
      defaultDir,
      DatabaseLocationService.databaseFilename,
    );

    // Don't migrate if already at default
    if (currentPath == newPath) {
      // Just update config
      await _locationService.saveStorageConfig(
        const StorageConfig(mode: StorageLocationMode.appDefault),
      );
      return MigrationResult.success(oldPath: currentPath, newPath: newPath);
    }

    String? backupPath;

    // Mark migration in progress to prevent other code from accessing the database
    _dbService.beginMigration();

    try {
      // Ensure WAL is checkpointed before closing to avoid copying an
      // inconsistent database state.
      await _checkpointWal();

      // Step 1: Close current database FIRST to release file locks
      await _dbService.close();

      // Small delay to ensure file locks are fully released
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 2: Create backup (now that DB is closed)
      backupPath = await _createBackup(currentPath);

      // Step 3: Ensure default directory exists
      final defaultDirObj = Directory(defaultDir);
      if (!await defaultDirObj.exists()) {
        await defaultDirObj.create(recursive: true);
      }

      // Step 4: Copy database files
      await _copyDatabaseFiles(currentPath, newPath);

      // Step 5: Verify integrity
      final debugInfo = StringBuffer();
      final isValid = await verifyDatabaseIntegrity(
        newPath,
        debugInfo: debugInfo,
      );
      if (!isValid) {
        await _dbService.reinitializeAtPath(currentPath);
        _dbService.endMigration();
        return MigrationResult.failure(
          'Database integrity check failed. Original database restored.\n${debugInfo.toString()}',
        );
      }

      // Step 6: Update configuration and clear any existing bookmark
      await _locationService.saveStorageConfig(
        const StorageConfig(mode: StorageLocationMode.appDefault),
      );
      await _locationService.clearStoredBookmark();

      // Step 7: Reinitialize
      await _dbService.reinitializeAtPath(newPath);

      // Step 8: Verify functional
      final isWorking = await _verifyDatabaseFunctional();
      if (!isWorking) {
        await _rollbackToOriginal(currentPath, backupPath);
        _dbService.endMigration();
        return MigrationResult.failure(
          'Database failed to initialize. Original database restored.',
        );
      }

      _dbService.endMigration();
      return MigrationResult.success(
        oldPath: currentPath,
        newPath: newPath,
        backupPath: backupPath,
      );
    } catch (e) {
      try {
        await _rollbackToOriginal(currentPath, backupPath);
      } catch (_) {}
      _dbService.endMigration();
      return MigrationResult.failure('Migration failed: $e');
    }
  }

  /// Switch to using an existing database at the given folder
  ///
  /// This does NOT copy the current database - it just switches to using
  /// the database that already exists at the target location.
  Future<MigrationResult> switchToExistingDatabase(String folderPath) async {
    final currentPath = await _dbService.databasePath;
    final newPath = p.join(
      folderPath,
      DatabaseLocationService.databaseFilename,
    );

    // Verify the target database exists
    if (!await File(newPath).exists()) {
      return MigrationResult.failure(
        'No database found at the selected location',
      );
    }

    String? backupPath;

    // Mark migration in progress to prevent other code from accessing the database
    _dbService.beginMigration();

    try {
      // Ensure WAL is checkpointed before closing to avoid copying an
      // inconsistent database state.
      await _checkpointWal();

      // Close current database FIRST to release file locks
      // This is critical on macOS/iOS where WAL mode locks the -shm file
      await _dbService.close();

      // Small delay to ensure file locks are fully released
      await Future.delayed(const Duration(milliseconds: 100));

      // Create backup of current database (now that it's closed)
      backupPath = await _createBackup(currentPath);

      // Verify target database integrity
      final isValid = await verifyDatabaseIntegrity(newPath);
      if (!isValid) {
        await _dbService.reinitializeAtPath(currentPath);
        _dbService.endMigration();
        return MigrationResult.failure(
          'The database at the selected location appears to be corrupted.',
        );
      }

      // Update configuration
      await _locationService.saveStorageConfig(
        StorageConfig(
          mode: StorageLocationMode.customFolder,
          customFolderPath: folderPath,
          lastVerified: DateTime.now(),
        ),
      );

      // Create security-scoped bookmark for persistent access (macOS)
      await _locationService.createAndStoreBookmark(folderPath);

      // Open the new database
      await _dbService.reinitializeAtPath(newPath);

      // Verify functional
      final isWorking = await _verifyDatabaseFunctional();
      if (!isWorking) {
        await _rollbackToOriginal(currentPath, backupPath);
        _dbService.endMigration();
        return MigrationResult.failure(
          'Failed to open database at new location. Original database restored.',
        );
      }

      _dbService.endMigration();
      return MigrationResult.success(
        oldPath: currentPath,
        newPath: newPath,
        backupPath: backupPath,
      );
    } catch (e) {
      try {
        await _rollbackToOriginal(currentPath, backupPath);
      } catch (_) {}
      _dbService.endMigration();
      return MigrationResult.failure('Switch failed: $e');
    }
  }

  /// Replace an existing database with the current database
  Future<MigrationResult> replaceExistingDatabase(String folderPath) async {
    // This is essentially the same as migrateToCustomFolder,
    // but it will overwrite the existing database
    final newPath = p.join(
      folderPath,
      DatabaseLocationService.databaseFilename,
    );

    // Create backup of the existing database at target before overwriting
    final existingFile = File(newPath);
    if (await existingFile.exists()) {
      final existingBackupPath = _generateBackupPath(newPath);
      await existingFile.copy(existingBackupPath);
    }

    return migrateToCustomFolder(folderPath);
  }

  /// Verify database integrity using SQLite PRAGMA
  ///
  /// If [debugInfo] is provided, diagnostic information will be added to it.
  Future<bool> verifyDatabaseIntegrity(
    String dbPath, {
    StringBuffer? debugInfo,
  }) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) {
        debugInfo?.writeln('DEBUG: File does not exist at $dbPath');
        return false;
      }

      final fileSize = await file.length();
      debugInfo?.writeln('DEBUG: File exists, size: $fileSize bytes');

      // Use sqlite3 directly to avoid Drift's migration system triggering
      // when opening a database with a different schema version
      final db = sqlite3.sqlite3.open(dbPath);
      try {
        // Run integrity check (quick_check is faster and avoids long stalls)
        final result = db.select('PRAGMA quick_check');

        debugInfo?.writeln(
          'DEBUG: PRAGMA quick_check returned ${result.length} rows',
        );
        if (result.isNotEmpty) {
          debugInfo?.writeln('DEBUG: First row: ${result.first}');
        }

        // Result should be a single row with 'ok'
        if (result.isEmpty) {
          debugInfo?.writeln('DEBUG: Result was empty');
          return false;
        }

        // Get the first column value (column name varies by SQLite version)
        final firstRow = result.first;
        final status = firstRow.values.isNotEmpty
            ? firstRow.values.first?.toString().toLowerCase()
            : null;
        debugInfo?.writeln('DEBUG: Parsed status: "$status"');
        return status == 'ok';
      } finally {
        db.dispose();
        // Small delay to ensure SQLite fully releases the file lock
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e, stack) {
      debugInfo?.writeln('DEBUG: Exception during integrity check: $e');
      debugInfo?.writeln('DEBUG: Stack trace: $stack');
      return false;
    }
  }

  /// Create a timestamped backup of the database
  Future<String> _createBackup(String sourcePath) async {
    final backupPath = _generateBackupPath(sourcePath);
    final sourceFile = File(sourcePath);

    if (await sourceFile.exists()) {
      await sourceFile.copy(backupPath);
    }

    // Also backup WAL and SHM if they exist
    final walFile = File('$sourcePath-wal');
    if (await walFile.exists()) {
      await walFile.copy('$backupPath-wal');
    }

    return backupPath;
  }

  /// Generate a timestamped backup path
  String _generateBackupPath(String originalPath) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = p.dirname(originalPath);
    final basename = p.basenameWithoutExtension(originalPath);
    final ext = p.extension(originalPath);
    return p.join(dir, '${basename}_backup_$timestamp$ext');
  }

  /// Copy database files to a new location
  Future<void> _copyDatabaseFiles(String sourcePath, String destPath) async {
    await _deleteIfExists('$destPath-wal');
    await _deleteIfExists('$destPath-shm');

    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(destPath);
    }

    // Copy WAL file if exists
    final walSource = File('$sourcePath-wal');
    if (await walSource.exists()) {
      await walSource.copy('$destPath-wal');
    }
  }

  /// Verify that the database is functional by running a simple query
  Future<bool> _verifyDatabaseFunctional() async {
    try {
      final db = _dbService.databaseForMigration;
      // Try to count dives as a simple test
      await _withTimeout(
        db.select(db.dives).get(),
        'Database functional check',
        timeout: _functionalCheckTimeout,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkpointWal() async {
    try {
      final db = _dbService.databaseForMigration;
      await _withTimeout(
        db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get(),
        'WAL checkpoint',
        timeout: _checkpointTimeout,
      );
    } catch (_) {
      // Ignore checkpoint failures; migration will validate by integrity check.
    }
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Rollback to the original database location
  Future<void> _rollbackToOriginal(
    String originalPath,
    String? backupPath,
  ) async {
    // Close any open connection
    await _dbService.close();

    // Reset configuration to default or previous
    await _locationService.resetToDefault();

    // Reinitialize from original
    await _dbService.reinitializeAtPath(originalPath);
  }

  Future<_DatabaseCounts> _fetchDatabaseCounts(String dbPath) async {
    // Use sqlite3 directly to avoid Drift's migration system triggering
    // when opening a database with a different schema version
    final db = sqlite3.sqlite3.open(dbPath);
    try {
      // Query each table individually to handle missing tables gracefully
      // (older database versions may not have all tables)
      final userCount = _safeTableCount(db, 'divers');
      final diveCount = _safeTableCount(db, 'dives');
      final siteCount = _safeTableCount(db, 'dive_sites');
      final tripCount = _safeTableCount(db, 'trips');
      final buddyCount = _safeTableCount(db, 'buddies');

      return _DatabaseCounts(
        userCount: userCount,
        diveCount: diveCount,
        siteCount: siteCount,
        tripCount: tripCount,
        buddyCount: buddyCount,
      );
    } finally {
      db.dispose();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Safely count rows in a table, returning 0 if the table doesn't exist
  int _safeTableCount(sqlite3.Database db, String tableName) {
    try {
      final result = db.select('SELECT COUNT(*) AS count FROM $tableName');
      if (result.isEmpty) return 0;
      final value = result.first['count'];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    } catch (e) {
      // Table might not exist in older database versions
      return 0;
    }
  }

  int _parseCountValue(Object? value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }
}

class _DatabaseCounts {
  final int userCount;
  final int diveCount;
  final int siteCount;
  final int tripCount;
  final int buddyCount;

  const _DatabaseCounts({
    required this.userCount,
    required this.diveCount,
    required this.siteCount,
    required this.tripCount,
    required this.buddyCount,
  });
}
