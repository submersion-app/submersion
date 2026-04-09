import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/services/database_location_service.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  AppDatabase? _database;
  DatabaseLocationService? _locationService;
  String? _currentDatabasePath;
  bool _isMigrating = false;

  /// Whether a database migration is currently in progress
  /// During migration, database access should be avoided
  bool get isMigrating => _isMigrating;

  AppDatabase get database {
    if (_isMigrating) {
      throw StateError('Database migration in progress. Please wait.');
    }
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  /// Returns the database or null if not available (during migration or before init)
  /// Use this for safe access that won't throw during migration
  AppDatabase? get databaseOrNull => _isMigrating ? null : _database;

  /// Unsafe access for internal migration checks.
  /// Avoid using this outside migration code.
  AppDatabase get databaseForMigration {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  /// Call before starting a migration to prevent database access
  void beginMigration() {
    _isMigrating = true;
  }

  /// Call after migration completes to restore database access
  void endMigration() {
    _isMigrating = false;
  }

  /// The current database file path (set after initialization)
  String? get currentPath => _currentDatabasePath;

  /// For testing only: allows injecting a test database
  @visibleForTesting
  void setTestDatabase(AppDatabase db) {
    _database = db;
  }

  /// For testing only: resets the database instance
  @visibleForTesting
  void resetForTesting() {
    _database = null;
    _locationService = null;
    _currentDatabasePath = null;
  }

  /// Initialize the database with optional location service for custom paths
  Future<void> initialize({
    DatabaseLocationService? locationService,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    if (_database != null) return;

    _locationService = locationService;
    final dbPath = await _resolveDatabasePath();
    _currentDatabasePath = dbPath;

    // Ensure directory exists
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // Guard: reject databases created by a newer version of the app
    _assertSchemaVersionCompatible(dbPath);

    final file = File(dbPath);
    // Use synchronous NativeDatabase instead of createInBackground to avoid
    // isolate communication issues during migration. Background isolates can
    // cause close() to hang indefinitely if called mid-migration.
    // Progress bar updates still render between migration steps via the
    // Future.delayed(Duration.zero) yield in reportProgress().
    _database = AppDatabase(
      NativeDatabase(file),
      onMigrationProgress: onMigrationProgress,
    );
  }

  /// Reinitialize the database at a specific path (used during migration)
  Future<void> reinitializeAtPath(String newPath) async {
    await close();

    _currentDatabasePath = newPath;

    // Ensure directory exists
    final dbDir = Directory(p.dirname(newPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // Guard: reject databases created by a newer version of the app
    _assertSchemaVersionCompatible(newPath);

    // Small delay to ensure any previous database connections are fully released
    // This helps prevent SQLite file locking issues, especially with WAL mode
    await Future.delayed(const Duration(milliseconds: 100));

    final file = File(newPath);
    // Use synchronous NativeDatabase instead of createInBackground to avoid
    // isolate communication issues during migration
    _database = AppDatabase(NativeDatabase(file));

    // Verify the database is ready by running a simple query
    // This ensures the connection is fully established before returning
    try {
      await _database!
          .customSelect('SELECT 1')
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // If verification fails, close and rethrow
      await close();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_database == null) return;

    try {
      // Add timeout to prevent hanging indefinitely
      await _database!.close().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // If close times out, just abandon the connection
          // The OS will clean up the file handles when the app exits
        },
      );
    } catch (e) {
      // Ignore close errors - we're abandoning this connection anyway
    } finally {
      _database = null;
    }
  }

  /// Throws [DatabaseVersionMismatchException] if the database file's schema
  /// version is newer than what this build of the app supports.
  ///
  /// Uses raw sqlite3 to read PRAGMA user_version before Drift opens the
  /// database, ensuring the file is never modified by a stale migration.
  void _assertSchemaVersionCompatible(String dbPath) {
    final file = File(dbPath);
    if (!file.existsSync()) return;

    // Open in read-write mode so SQLite can recover any hot journal/WAL
    // from a previous crash. Opening read-only would fail with
    // SQLITE_READONLY_ROLLBACK (code 776) if recovery is needed.
    final db = sqlite3.sqlite3.open(dbPath);
    try {
      final result = db.select('PRAGMA user_version');
      if (result.isEmpty) return;

      final storedVersion = result.first.values.first;
      if (storedVersion is int &&
          storedVersion > AppDatabase.currentSchemaVersion) {
        throw DatabaseVersionMismatchException(
          databaseVersion: storedVersion,
          appVersion: AppDatabase.currentSchemaVersion,
        );
      }
    } finally {
      db.dispose();
    }
  }

  /// Reads the stored schema version from a database file without opening it
  /// through Drift. Returns null if the file does not exist, or the integer
  /// PRAGMA user_version value otherwise.
  static int? getStoredSchemaVersion(String dbPath) {
    final file = File(dbPath);
    if (!file.existsSync()) return null;

    final db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readOnly);
    try {
      final result = db.select('PRAGMA user_version');
      if (result.isEmpty) return null;
      return result.first.values.first as int;
    } finally {
      db.dispose();
    }
  }

  /// Resolve the database path using location service or default
  Future<String> _resolveDatabasePath() async {
    if (_locationService != null) {
      return _locationService!.getDatabasePath();
    }
    return _getDefaultPath();
  }

  /// Get the default database path
  Future<String> _getDefaultPath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'Submersion', 'submersion.db');
  }

  /// Get the current database path (async version for external use)
  Future<String> get databasePath async {
    if (_currentDatabasePath != null) {
      return _currentDatabasePath!;
    }
    return _resolveDatabasePath();
  }

  Future<void> backup(String destinationPath) async {
    final sourcePath = await databasePath;
    final sourceFile = File(sourcePath);

    if (await sourceFile.exists()) {
      // Ensure the destination directory exists
      final destDir = Directory(p.dirname(destinationPath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      await sourceFile.copy(destinationPath);
    }
  }

  Future<void> restore(String backupPath) async {
    await close();

    final backupFile = File(backupPath);
    final destinationPath = await databasePath;

    if (await backupFile.exists()) {
      await backupFile.copy(destinationPath);
    }

    await initialize();
  }

  /// Delete all data and recreate a fresh empty database.
  ///
  /// 1. Backs up the current database to [backupPath]
  /// 2. Closes the database connection
  /// 3. Deletes the .db, .db-wal, and .db-shm files
  /// 4. Reinitializes a fresh database at the same path
  ///
  /// Throws if the backup step fails (reset is aborted to protect data).
  /// If file deletion or reinitialize fails after backup succeeds,
  /// the error propagates and the caller should handle recovery.
  Future<void> resetDatabase({required String backupPath}) async {
    final dbPath = await databasePath;

    // Step 1: Backup first (throws on failure, aborting the reset)
    await backup(backupPath);

    // Step 2: Close the connection
    await close();

    // Step 3: Delete database files
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Step 4: Reinitialize fresh database (Drift auto-creates tables)
    await reinitializeAtPath(dbPath);
  }
}
