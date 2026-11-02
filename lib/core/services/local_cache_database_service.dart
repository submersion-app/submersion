import 'dart:io';

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
///
/// SQLite runs on a worker isolate this service owns, like the main database,
/// so no query blocks the UI isolate. Grid writes run to 143 KB a row, and the
/// local cache sweep deletes megabytes and VACUUMs (issue #1929); on the UI
/// isolate each of those froze the frame for as long as it ran. One connection
/// on one isolate, so the lock contention that keeps VACUUM off the main
/// database's hot path does not arise here.
class LocalCacheDatabaseService {
  LocalCacheDatabaseService._();

  static final LocalCacheDatabaseService instance =
      LocalCacheDatabaseService._();

  LocalCacheDatabase? _database;

  /// The worker behind [_database], or null for an injected test database.
  BackgroundDatabaseConnection? _background;

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
    _background = null;
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

    final background = await BackgroundDatabaseConnection.openPlain(
      File(dbPath),
    );
    _background = background;
    _database = LocalCacheDatabase(background.connection);
  }

  Future<void> close() async {
    if (_database == null) return;
    try {
      // Shutdown path: a plain close() hangs while any watch() subscription
      // is paused (Riverpod 3 pauses the streams of unlistened providers),
      // because drift awaits the stream store before closing the executor.
      // The helper then closes the executor directly and waits for the worker
      // to exit, which happens only after SQLite has closed; letting the app
      // terminate first aborts the worker in drift's FFI callbacks, the same
      // trap the main database's close handles.
      await closeDatabaseForAppShutdown(_database!, background: _background);
    } finally {
      _database = null;
      _background = null;
    }
  }

  /// On iOS, getApplicationSupportDirectory() is included in device backups
  /// (iCloud and computer) unless a file is excluded, and on Android the files
  /// directory falls under Auto Backup. No exclusion is set on this database,
  /// which holds only per-device and derivable data. The media caches it
  /// indexes are in the OS cache directory, which neither platform backs up
  /// (issue #3341), so a restored index can name files that are not there; the
  /// media cache copes with that. See CacheLocation.
}
