import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/services/database_location_service.dart';

/// Which executor path [DatabaseService] used for the most recent open.
enum DatabaseOpenMode {
  /// Straight to the background-isolate executor (no migration pending).
  background,

  /// A pending upgrade ladder ran on the synchronous main-isolate executor
  /// first, then the database reopened on the background executor.
  migrationThenBackground,
}

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
    lastOpenMode = null;
    // The service is a singleton, so a restore seam set by one test would
    // otherwise leak into the next and fire unexpectedly.
    debugOnRestoreWindowOpen = null;
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

    _database = await _openDatabase(
      dbPath,
      onMigrationProgress: onMigrationProgress,
    );
  }

  /// Which executor path [_openDatabase] took on the most recent open.
  @visibleForTesting
  DatabaseOpenMode? lastOpenMode;

  /// Opens [dbPath] with SQLite execution OFF the UI isolate (WS5,
  /// large-DB performance), while keeping the battle-tested migration
  /// semantics on the synchronous executor.
  ///
  /// Two phases:
  /// 1. If an upgrade ladder is PENDING, run it to completion on the
  ///    synchronous main-isolate [NativeDatabase] exactly as before —
  ///    progress callbacks, pre-migration backup close/reopen, and
  ///    hot-journal recovery are proven there, and closing a background
  ///    executor MID-migration has historically hung. The close happens
  ///    strictly after the ladder finishes.
  /// 2. Open with [NativeDatabase.createInBackground]: every statement
  ///    executes on drift's worker isolate. Migration callbacks (onCreate
  ///    for fresh files, the beforeOpen re-asserts) still run on the main
  ///    isolate and issue their statements through the remote executor,
  ///    so their semantics are unchanged.
  ///
  /// A single synchronous `PRAGMA user_version` read (via
  /// [getStoredSchemaVersion]) drives BOTH the newer-than-app guard and
  /// the migration-pending decision, so the file is opened synchronously
  /// on the UI isolate at most once per open — the rest is executor work.
  Future<AppDatabase> _openDatabase(
    String dbPath, {
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    final file = File(dbPath);
    final stored = getStoredSchemaVersion(dbPath);

    // Guard: reject databases created by a newer version of the app.
    if (stored != null && stored > AppDatabase.currentSchemaVersion) {
      throw DatabaseVersionMismatchException(
        databaseVersion: stored,
        appVersion: AppDatabase.currentSchemaVersion,
      );
    }

    final migrationPending =
        stored != null &&
        stored > 0 &&
        stored < AppDatabase.currentSchemaVersion;

    if (migrationPending) {
      final migrator = AppDatabase(
        NativeDatabase(file),
        onMigrationProgress: onMigrationProgress,
      );
      try {
        // Force the upgrade ladder to completion before switching
        // executors.
        await migrator.customSelect('SELECT 1').get();
      } catch (_) {
        // Migration failed: best-effort close so we don't leak the
        // connection, then let the original error surface.
        await migrator
            .close()
            .timeout(const Duration(seconds: 5), onTimeout: () {})
            .catchError((_) {});
        rethrow;
      }
      // The synchronous connection MUST fully close (releasing its file
      // locks) before the background executor reopens the same file.
      // A timed-out close would leave locks held and risk "database is
      // locked"/corruption on the reopen, so fail fast rather than
      // silently proceed.
      await migrator.close().timeout(const Duration(seconds: 5));
      lastOpenMode = DatabaseOpenMode.migrationThenBackground;
    } else {
      lastOpenMode = DatabaseOpenMode.background;
    }

    return AppDatabase(
      NativeDatabase.createInBackground(file),
      onMigrationProgress: onMigrationProgress,
    );
  }

  /// Reinitialize the database at a specific path (used during migration)
  Future<void> reinitializeAtPath(String newPath) async {
    // Strict close: this method reopens immediately, so it must not race a
    // background connection that timed out mid-close and is still holding
    // file locks. A stuck close throws here rather than being abandoned.
    await close(strict: true);

    // Ensure directory exists
    final dbDir = Directory(p.dirname(newPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // Small delay to ensure any previous database connections are fully released
    // This helps prevent SQLite file locking issues, especially with WAL mode
    await Future.delayed(const Duration(milliseconds: 100));

    _database = await _openDatabase(newPath);

    // Verify the database is ready by running a simple query
    // This ensures the connection is fully established before returning
    try {
      await _database!
          .customSelect('SELECT 1')
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Verification failed: close the just-opened connection before
      // rethrowing. Strict close so a timed-out close does NOT null
      // _database and orphan a still-open background connection whose locks
      // would block a rollback/retry. If the strict close itself throws,
      // the reference is intentionally kept (strict contract) and we still
      // surface the ORIGINAL verification error rather than masking it.
      try {
        await close(strict: true);
      } catch (_) {}
      rethrow;
    }

    // Commit the new path ONLY after a verified open. Setting it earlier
    // would leave the service pointing at newPath even when _openDatabase
    // threw (version mismatch / corrupt file) and nothing is open there,
    // confusing later recovery/rollback code that reads databasePath.
    _currentDatabasePath = newPath;
  }

  /// Closes the active database connection.
  ///
  /// Default (shutdown/abandon) behavior: a timed-out or failed close is
  /// swallowed and the connection is dropped — the OS reclaims the file
  /// handles when the app exits.
  ///
  /// [strict] is for reopen-after-close paths (storage move / restore):
  /// they immediately reopen the same file, so a half-closed background
  /// connection still holding locks would race the reopen and surface as
  /// "database is locked"/corruption. In strict mode a timed-out or failed
  /// close THROWS instead of being abandoned, and [_database] is left
  /// non-null so the still-open connection is not orphaned and the caller
  /// can retry — [_database] is cleared ONLY on a clean close.
  Future<void> close({bool strict = false}) async {
    if (_database == null) return;

    if (strict) {
      // No onTimeout swallow: a timeout throws TimeoutException. Clear the
      // reference only after the close actually completed — on failure we
      // keep it so the connection (and its locks) is not leaked and a
      // retry can re-attempt the close before reopening.
      await _database!.close().timeout(const Duration(seconds: 5));
      _database = null;
      return;
    }

    try {
      // Shutdown/abandon path: if close times out, drop the connection and
      // let the OS reclaim the file handles when the app exits.
      await _database!.close().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    } catch (e) {
      // Ignore close errors - we're abandoning this connection anyway.
    } finally {
      _database = null;
    }
  }

  /// Reads the stored schema version from a database file without opening it
  /// through Drift. Returns null if the file does not exist, or the integer
  /// PRAGMA user_version value otherwise.
  ///
  /// Opens in read-write mode (not read-only) so SQLite can automatically
  /// roll back any hot journal left behind by a previous crash. A read-only
  /// open on a db with a pending rollback throws SQLITE_READONLY_ROLLBACK
  /// (extended code 776) before even the first PRAGMA can execute.
  static int? getStoredSchemaVersion(String dbPath) {
    final file = File(dbPath);
    if (!file.existsSync()) return null;

    final db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readWrite);
    try {
      final result = db.select('PRAGMA user_version');
      if (result.isEmpty) return null;
      return result.first.values.first as int;
    } finally {
      db.dispose();
    }
  }

  /// Force SQLite to complete any pending hot-journal rollback on [dbPath].
  ///
  /// Opens the file in read-write mode — the very act of opening triggers
  /// SQLite's automatic recovery of a hot journal. Returns true if the file
  /// opened cleanly (recovery either wasn't needed or succeeded), false if
  /// the journal could not be rolled back (file still read-only, on a
  /// read-only volume, etc.).
  ///
  /// Safe to call on a file without a hot journal: it simply no-ops.
  static bool recoverHotJournal(String dbPath) {
    final file = File(dbPath);
    if (!file.existsSync()) return true;
    try {
      final db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readWrite);
      try {
        db.select('PRAGMA user_version');
      } finally {
        db.dispose();
      }
      return true;
    } on sqlite3.SqliteException {
      return false;
    }
  }

  /// True if [error] is a [sqlite3.SqliteException] in the SQLITE_READONLY
  /// family (primary result code 8) — typically SQLITE_READONLY_ROLLBACK
  /// (776) after a cancelled transaction left a hot journal behind.
  static bool isRecoverableReadonlyError(Object error) {
    return error is sqlite3.SqliteException && error.resultCode == 8;
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

  /// Test seam: invoked synchronously the instant the live database has been
  /// closed during [restore] — i.e. when the "database unavailable" window
  /// opens — with the staging path. Lets tests assert the backup was fully
  /// staged BEFORE the window opened.
  ///
  /// One-shot: [restore] captures and clears it before firing, and
  /// [resetForTesting] also clears it, so a callback never leaks across tests
  /// (the service is a singleton).
  @visibleForTesting
  void Function(String stagingPath)? debugOnRestoreWindowOpen;

  Future<void> restore(String backupPath) async {
    final backupFile = File(backupPath);
    final destinationPath = await databasePath;

    // No backup to swap in: leave the live database exactly as it is. The old
    // implementation closed and reopened the same file here, which was an
    // effective no-op that still opened a needless "database unavailable"
    // window — during which a provider rebuild caches a fatal
    // "Database not initialized" error.
    if (!await backupFile.exists()) {
      // Still sweep any temp files a prior restore may have stranded (e.g. a
      // large .pre-restore copy left by a best-effort cleanup that failed), so
      // they don't accumulate on disk. Best-effort; the live DB is untouched.
      await _sweepRestoreTempFiles(destinationPath);
      return;
    }

    // Copy the backup to a staging file NEXT TO the destination while the live
    // database stays open and keeps serving reads. This keeps the database
    // available during the slow part of a restore (copying a potentially large
    // backup), so provider rebuilds never observe a null database and cache a
    // fatal error. Same-directory staging also keeps the later rename on one
    // filesystem, so the swap is an atomic metadata operation rather than a
    // cross-device copy.
    final stagingPath = '$destinationPath.restore-staging';
    await _deleteIfExists(stagingPath);
    try {
      await backupFile.copy(stagingPath);
    } catch (_) {
      await _deleteIfExists(stagingPath);
      rethrow;
    }

    // The ONLY window where the database is unavailable: close, swap the file,
    // reopen. Its duration is a rename + open, not the backup copy.
    //
    // Strict close: the swap+reopen immediately follows, so a connection that
    // timed out mid-close and still holds the file must throw here rather than
    // race the rename.
    await close(strict: true);
    // Fire the test seam one-shot: capture and clear it before invoking so a
    // callback set by one test cannot leak into a later restore (the service is
    // a singleton).
    final onWindowOpen = debugOnRestoreWindowOpen;
    debugOnRestoreWindowOpen = null;
    onWindowOpen?.call(stagingPath);

    // Safe swap: move the live file ASIDE (never delete it before the new file
    // is in place), move the staged file IN, and only then drop the old copy.
    // If the move-in fails, roll the old file back so the app is never left
    // with no database and no data. Renaming into a non-existent destination
    // works identically on POSIX and Windows, so no per-platform branching.
    final asidePath = '$destinationPath.pre-restore';
    await _deleteIfExists(asidePath);
    final destFile = File(destinationPath);
    final hadDest = await destFile.exists();
    try {
      if (hadDest) await destFile.rename(asidePath);
      // The old WAL/SHM sidecars belong to the pre-restore database. Left in
      // place, SQLite would replay them into the swapped-in file and corrupt
      // it, so they must go before the new file is opened.
      await _deleteIfExists('$destinationPath-wal');
      await _deleteIfExists('$destinationPath-shm');
      await File(stagingPath).rename(destinationPath);
    } catch (_) {
      // The swap failed with the database closed. Roll the original file back
      // into place, drop the orphaned staging copy, and reopen so the app is
      // never left with a dead (null) database, then surface the error.
      if (hadDest &&
          !await destFile.exists() &&
          await File(asidePath).exists()) {
        await File(asidePath).rename(destinationPath);
      }
      await _deleteIfExists(stagingPath);
      await initialize();
      rethrow;
    }

    // Reopen on the swapped-in file BEFORE dropping the pre-restore copy, so a
    // cleanup hiccup can never prevent the reopen.
    await initialize();

    // The database is open again on the restored file; the pre-restore copy is
    // no longer needed. Its deletion is best-effort — a transient failure (e.g.
    // a Windows file lock) must NOT fail a restore that already succeeded and
    // leave the app with a closed database despite a valid file on disk. A
    // leftover copy is harmless and is swept by the next restore (including a
    // no-op one).
    await _bestEffortDelete(asidePath);
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Delete [path] if present, swallowing any error. For cleanup that must not
  /// abort the caller (a transient file lock on a stale temp file is harmless).
  Future<void> _bestEffortDelete(String path) async {
    try {
      await _deleteIfExists(path);
    } catch (_) {
      // Best-effort: a stranded temp file is harmless and swept on a later run.
    }
  }

  /// Best-effort removal of the temp files a [restore] may leave behind
  /// (`.restore-staging`, `.pre-restore`). Safe to call while the live database
  /// is open — it touches only the sidecar temp files, never the live DB.
  Future<void> _sweepRestoreTempFiles(String destinationPath) async {
    await _bestEffortDelete('$destinationPath.restore-staging');
    await _bestEffortDelete('$destinationPath.pre-restore');
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

    // Step 2: Close the connection (strict: the files are about to be
    // deleted and the path reopened, so a still-open connection must throw
    // rather than be abandoned — deleting an open file fails on Windows).
    await close(strict: true);

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
