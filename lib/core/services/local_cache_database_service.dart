import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// Singleton service managing the local-only cache database.
///
/// This database is stored in getApplicationSupportDirectory() and is
/// never synced between devices. It holds per-device asset ID mappings
/// for cross-device photo resolution.
class LocalCacheDatabaseService {
  LocalCacheDatabaseService._();

  static final LocalCacheDatabaseService instance =
      LocalCacheDatabaseService._();

  LocalCacheDatabase? _database;

  LocalCacheDatabase get database {
    if (_database == null) {
      throw StateError(
        'Local cache database not initialized. Call initialize() first.',
      );
    }
    return _database!;
  }

  /// For testing only: allows injecting a test database
  @visibleForTesting
  void setTestDatabase(LocalCacheDatabase db) {
    _database = db;
  }

  /// For testing only: resets the database instance
  @visibleForTesting
  void resetForTesting() {
    _database = null;
  }

  Future<void> initialize() async {
    if (_database != null) return;

    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'Submersion', 'submersion_local.db');

    // Ensure directory exists
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final file = File(dbPath);
    _database = LocalCacheDatabase(NativeDatabase(file));
  }

  Future<void> close() async {
    if (_database == null) return;
    try {
      // Shutdown path: a plain close() hangs while any watch() subscription
      // is paused (Riverpod 3 pauses the streams of unlistened providers),
      // because drift awaits the stream store before closing the executor.
      // This helper falls back to closing the executor directly, which for
      // this main-isolate database is the real sqlite3 close.
      await closeDatabaseForAppShutdown(_database!);
    } finally {
      _database = null;
    }
  }

  /// On both iOS and macOS, getApplicationSupportDirectory() returns a
  /// path inside ~/Library/Application Support/ (macOS) or
  /// <sandbox>/Library/Application Support/ (iOS). Neither location is
  /// synced by iCloud Drive — iCloud only syncs the iCloud Drive folder
  /// and app-specific iCloud containers. No explicit
  /// NSURLIsExcludedFromBackupKey is needed for Application Support.
}
