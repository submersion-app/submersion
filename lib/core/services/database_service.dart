import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';
import 'database_location_service.dart';

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
  Future<void> initialize({DatabaseLocationService? locationService}) async {
    if (_database != null) return;

    _locationService = locationService;
    final dbPath = await _resolveDatabasePath();
    _currentDatabasePath = dbPath;

    // Ensure directory exists
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final file = File(dbPath);
    // Use synchronous NativeDatabase instead of createInBackground
    // Background isolates can cause close() to hang indefinitely during migration
    // For a dive log app, synchronous DB operations are fast enough
    _database = AppDatabase(NativeDatabase(file));
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
}
