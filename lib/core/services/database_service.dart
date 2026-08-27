import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_connection_setup.dart';
import 'package:submersion/core/database/database_snapshot.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/database/sqlcipher_setup.dart'
    as sqlcipher_setup;
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/security/database_locked_exception.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';

/// Which executor path [DatabaseService] used for the most recent open.
enum DatabaseOpenMode {
  /// Straight to the background-isolate executor (no migration pending).
  background,

  /// A pending upgrade ladder ran on the synchronous main-isolate executor
  /// first, then the database reopened on the background executor.
  migrationThenBackground,
}

/// drift setup callback for a main-database connection: keys SQLCipher before
/// any other statement, then applies the busy timeout and the WAL journal
/// mode. Never null -- neither of those is conditional on encryption.
///
/// The single place WAL is turned on. Every other opener of a database file
/// (the raw probes in [DatabaseService.openRaw], the backup exporters) is
/// deliberately journal-mode-neutral.
void Function(sqlite3.Database) _connectionSetup(String? keyHex) {
  return (db) => applyMainDatabaseSetup(db, keyHex: keyHex);
}

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  final _log = LoggerService.forClass(DatabaseService);

  AppDatabase? _database;

  /// The worker isolate behind [_database], when it was opened on one. Held so
  /// [close] can wait for SQLite to actually finish closing rather than just
  /// for drift's acknowledgement — see [BackgroundDatabaseConnection].
  BackgroundDatabaseConnection? _background;

  DatabaseLocationService? _locationService;
  String? _currentDatabasePath;
  bool _isMigrating = false;

  /// SQLCipher raw key (64 lowercase hex chars) for the main database, set by
  /// DatabaseSecurityService BEFORE initialize()/reinitializeAtPath() when
  /// encryption is enabled. Null = open without a key (plaintext database).
  String? databaseKeyHex;

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

  /// Test seam for the sqlcipher export used by portable backup/restore.
  @visibleForTesting
  SqlcipherExporter? debugExporterOverride;

  @visibleForTesting
  void setCurrentPathForTesting(String path) {
    _currentDatabasePath = path;
  }

  /// For testing only: resets the database instance
  @visibleForTesting
  void resetForTesting() {
    _database = null;
    _background = null;
    _locationService = null;
    _currentDatabasePath = null;
    databaseKeyHex = null;
    debugExporterOverride = null;
    debugSnapshotterOverride = null;
    lastOpenMode = null;
    // The service is a singleton, so a restore seam set by one test would
    // otherwise leak into the next and fire unexpectedly.
    debugOnRestoreWindowOpen = null;
  }

  /// Registers [locationService] without opening anything.
  ///
  /// [restore] resolves its destination through the location service, but the
  /// startup failure screen can offer a restore on a launch where [initialize]
  /// never got far enough to register one. Without this, a restore attempted
  /// from that screen would target the DEFAULT database path and quietly write
  /// past a diver's custom database location.
  ///
  /// Does not overwrite a service already registered by [initialize].
  void adoptLocationService(DatabaseLocationService locationService) {
    _locationService ??= locationService;
  }

  /// Initialize the database with optional location service for custom paths.
  ///
  /// [allowSchemaUpgrade] false makes a pending upgrade a hard stop: no drift
  /// connection is created and [SchemaUpgradePendingException] is thrown
  /// instead. The version probe still opens and closes the file to read
  /// `PRAGMA user_version`, but nothing writes to it. Headless callers pass
  /// false -- see [SchemaUpgradePendingException] for why the background
  /// isolate must never run the ladder.
  Future<void> initialize({
    DatabaseLocationService? locationService,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
    bool allowSchemaUpgrade = true,
  }) async {
    if (_database != null) return;

    // Keep an already-registered service when called without one. [restore]
    // reopens via a bare `initialize()`, and clearing the location service
    // there would make the reopen resolve the DEFAULT path, silently
    // abandoning a custom database location on every restore.
    _locationService = locationService ?? _locationService;
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
      allowSchemaUpgrade: allowSchemaUpgrade,
    );

    await _assertCipherAvailable(_database!);
  }

  /// Fails loudly if the native library behind the OPEN connection is not
  /// SQLCipher (e.g. the dynamic linker resolved sqlite3 symbols to a
  /// system/plugin copy on iOS/macOS). Encrypted databases would be unopenable
  /// and enabling encryption would corrupt silently, so this must be caught on
  /// day one.
  ///
  /// The first line of defence is now `assertDatabaseEngineAvailable`, which
  /// checks the same invariant on an in-memory handle BEFORE any user file is
  /// touched. This stays as the check on the real connection.
  ///
  /// Skipped under `flutter test`, where a suite may legitimately be running
  /// against an injected in-memory database. (The host runner itself does link
  /// SQLCipher through the sqlite3 build hook; see sqlcipher_setup_test.dart,
  /// which asserts exactly that.)
  Future<void> _assertCipherAvailable(AppDatabase db) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final rows = await db.customSelect('PRAGMA cipher_version').get();
    if (rows.isEmpty) {
      throw StateError(
        'SQLCipher is not linked: PRAGMA cipher_version returned nothing. '
        'The app was built against a non-SQLCipher sqlite3 library.',
      );
    }
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
  /// 2. Open with [BackgroundDatabaseConnection.open] (a
  ///    [NativeDatabase.createInBackground] equivalent that owns the worker
  ///    isolate, so [close] can wait for SQLite to actually finish closing):
  ///    every statement executes on drift's worker isolate. Migration
  ///    callbacks (onCreate for fresh files, the beforeOpen re-asserts)
  ///    still run on the main isolate and issue their statements through
  ///    the remote executor, so their semantics are unchanged.
  ///
  /// A single synchronous `PRAGMA user_version` read (via
  /// [getStoredSchemaVersion]) drives BOTH the newer-than-app guard and
  /// the migration-pending decision, so the file is opened synchronously
  /// on the UI isolate at most once per open — the rest is executor work.
  Future<AppDatabase> _openDatabase(
    String dbPath, {
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
    bool allowSchemaUpgrade = true,
  }) async {
    final file = File(dbPath);
    final keyHex = databaseKeyHex;
    final stored = getStoredSchemaVersion(dbPath, keyHex: keyHex);

    // Guard: reject databases created by a newer version of the app.
    if (stored != null && stored > AppDatabase.currentSchemaVersion) {
      throw DatabaseVersionMismatchException(
        storedSchemaVersion: stored,
        supportedSchemaVersion: AppDatabase.currentSchemaVersion,
      );
    }

    final migrationPending =
        stored != null &&
        stored > 0 &&
        stored < AppDatabase.currentSchemaVersion;

    // Refused before any drift connection exists: drift runs the ladder on
    // the first statement, so a caller barred from upgrading must never be
    // handed a connection at all.
    //
    // The FILE has been opened by this point -- [getStoredSchemaVersion] a
    // few lines up opens it read-write and closes it again, which is also
    // what rolls back a hot journal (see StartupPhase.preflight, which
    // documents the same distinction). What the guard promises is narrower
    // and is what the tests assert: nothing wrote to it, so the stored
    // version is exactly as the foreground will find it.
    //
    // A missing file is not a pending upgrade -- creation is onCreate, which
    // a headless first run may legitimately do.
    if (migrationPending && !allowSchemaUpgrade) {
      throw SchemaUpgradePendingException(
        storedSchemaVersion: stored,
        supportedSchemaVersion: AppDatabase.currentSchemaVersion,
      );
    }

    if (migrationPending) {
      // Each retry re-runs the ladder from the top on a brand new connection.
      // That is safe -- every step is idempotent by contract -- but it does
      // mean onMigrationProgress can restart at step 1, so a progress bar may
      // visibly rewind. A rewinding bar beats a bricked launch.
      await retryWhileDatabaseBusy(
        () => _runUpgradeLadder(file, keyHex, onMigrationProgress),
      );
      lastOpenMode = DatabaseOpenMode.migrationThenBackground;
    } else {
      lastOpenMode = DatabaseOpenMode.background;
    }

    return retryWhileDatabaseBusy(
      () => _openOnBackgroundExecutor(file, keyHex, onMigrationProgress),
    );
  }

  /// Runs the pending upgrade ladder to completion on a synchronous
  /// main-isolate connection, then closes it.
  ///
  /// Self-contained so [retryWhileDatabaseBusy] can simply call it again: a
  /// drift executor caches the error from a failed migration and rethrows it
  /// on every later use, so a retry has to start from a new connection, and
  /// the old one's locks have to be gone before the next attempt takes any.
  Future<void> _runUpgradeLadder(
    File file,
    String? keyHex,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  ) async {
    final migrator = AppDatabase(
      NativeDatabase(file, setup: _connectionSetup(keyHex)),
      onMigrationProgress: onMigrationProgress,
    );
    try {
      // Force the upgrade ladder to completion before switching executors.
      await migrator.customSelect('SELECT 1').get();
    } catch (_) {
      // Best-effort close so we don't leak the connection (or its locks, which
      // would defeat the retry), then let the original error surface.
      await migrator
          .close()
          .timeout(const Duration(seconds: 5), onTimeout: () {})
          .catchError((_) {});
      rethrow;
    }
    // The synchronous connection MUST fully close (releasing its file locks)
    // before the background executor reopens the same file. A timed-out close
    // would leave locks held and risk "database is locked"/corruption on the
    // reopen, so fail fast rather than silently proceed.
    await migrator.close().timeout(const Duration(seconds: 5));
  }

  /// Opens on the worker isolate and forces the connection all the way open
  /// before returning it.
  ///
  /// The forcing statement is the point. Drift opens lazily, so without it
  /// `beforeOpen` -- which re-asserts schema and re-seeds reference data with
  /// dozens of writes -- would not run until some unrelated screen happened to
  /// issue the first query. That put a lock failure an arbitrary distance away
  /// from the open that caused it: too late for the retry here, too late for
  /// the startup screen to classify it, and reported against whatever feature
  /// asked first. (It also silently made `flutter test` opens do nothing,
  /// because the one statement that used to force them,
  /// [_assertCipherAvailable]'s `PRAGMA cipher_version`, short-circuits under
  /// FLUTTER_TEST.)
  Future<AppDatabase> _openOnBackgroundExecutor(
    File file,
    String? keyHex,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  ) async {
    final background = await BackgroundDatabaseConnection.open(
      file,
      keyHex: keyHex,
    );
    final database = AppDatabase(
      background.connection,
      onMigrationProgress: onMigrationProgress,
    );
    try {
      await database.customSelect('SELECT 1').get();
    } catch (_) {
      // Tear the whole attempt down, worker isolate included, so a retry does
      // not race this connection's locks.
      await closeDatabaseForAppShutdown(database, background: background);
      rethrow;
    }
    _background = background;
    return database;
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
      // Graceful close first, but only briefly: GeneratedDatabase.close()
      // awaits streamQueries.close(), which hangs for as long as ANY watch()
      // subscription is paused — and Riverpod 3 auto-pauses the streams of
      // providers nobody is currently listening to, so a mid-session restore
      // almost always has one. Trusting the graceful close with a throwing
      // timeout here made large-DB restores fail with TimeoutException until
      // retried. On a hang, fall through and close the executor directly:
      // idempotent when the graceful close got that far, and it sends the
      // shutdown request the hung close never reached. Skipping the
      // stream-store cleanup is safe on this path — the connection is being
      // replaced, and the old stream subscriptions die with it.
      final graceful = _database!.close();
      try {
        await graceful.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        graceful.ignore();
        // No onTimeout swallow: if even the direct executor close cannot get
        // an acknowledgment, the connection is genuinely stuck and the caller
        // must not race the file swap. Clear the reference only after the
        // close actually completed — on failure we keep it so the connection
        // (and its locks) is not leaked and a retry can re-attempt the close
        // before reopening.
        await _database!.executor.close().timeout(const Duration(seconds: 5));
      }
      // Drift acknowledges the shutdown request before the worker isolate
      // runs sqlite3_close_v2, so the await above does NOT mean the file is
      // closed. A caller about to reopen the same file must wait for the
      // real close, and a stuck worker throws rather than being killed:
      // killing it would strand an open handle holding the file locks.
      //
      // The budget here is deliberately much longer than the 5s ack wait:
      // the worker's sqlite3_close_v2 is where a WAL checkpoint-on-close
      // runs, which on a multi-hundred-MB database can take tens of
      // seconds. Restore/move callers strongly prefer a slow success over
      // a fast TimeoutException that aborts the whole operation.
      await _background?.awaitWorkerShutdown(
        timeout: const Duration(seconds: 60),
        killIfStuck: false,
      );
      _background = null;
      _database = null;
      return;
    }

    // Shutdown/abandon path. Two traps make a plain close() unsafe here:
    // paused watch() subscriptions (Riverpod 3 auto-pause) hang the graceful
    // close before it ever reaches the executor, and the background worker
    // acknowledges the executor close before SQLite is actually closed. If
    // the app then terminates, the worker's sqlite3_close_v2 calls back into
    // Dart (drift's SQL function destructors) after the VM tore down its FFI
    // callback metadata, aborting with "GetFfiCallbackMetadata called after
    // shutdown" and hanging the app in the Dock. See
    // closeDatabaseForAppShutdown for how each is handled.
    try {
      await closeDatabaseForAppShutdown(_database!, background: _background);
    } finally {
      _background = null;
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
  static int? getStoredSchemaVersion(String dbPath, {String? keyHex}) {
    final file = File(dbPath);
    if (!file.existsSync()) return null;

    final db = openRaw(dbPath, keyHex: keyHex);
    try {
      final result = db.select('PRAGMA user_version');
      if (result.isEmpty) return null;
      return result.first.values.first as int;
    } on sqlite3.SqliteException catch (e) {
      // An encrypted file read without (or with the wrong) key surfaces as
      // NOTADB on the first real page read — but so does a CORRUPT plaintext
      // database, since the header probe alone cannot tell the two apart
      // (both simply fail to start with the SQLite magic).
      //
      // So require corroboration before routing to the unlock flow, the same
      // rule the startup gate applies: either a key was supplied (we already
      // believed the file was encrypted and it was rejected) or the keyslot
      // sidecar exists (this install has security material). With neither,
      // let the SqliteException through to the corruption-recovery flow —
      // sending corruption to the lock screen would strand the user there,
      // because no password can unwrap a sidecar that does not exist.
      if (_isNotADatabaseError(e) &&
          isEncryptedDatabaseFile(dbPath) &&
          (keyHex != null || DatabaseSecuritySidecar.existsFor(dbPath))) {
        throw DatabaseLockedException(dbPath, wrongKey: keyHex != null);
      }
      rethrow;
    } finally {
      db.close();
    }
  }

  /// The PRAGMA that keys a SQLCipher connection with a raw key. Delegate to
  /// the single definition in sqlcipher_setup.dart.
  static String cipherKeyPragma(String keyHex) =>
      sqlcipher_setup.cipherKeyPragma(keyHex);

  /// Single choke point for raw (non-drift) opens of the main database.
  /// Applies the cipher key and busy timeout, and disposes the handle on
  /// failure.
  ///
  /// The busy timeout matters as much here as on the drift connections: the
  /// version probe and the pre-migration WAL checkpoint both run at startup,
  /// the very moment a headless isolate is most likely to be holding a lock.
  static sqlite3.Database openRaw(
    String path, {
    sqlite3.OpenMode mode = sqlite3.OpenMode.readWrite,
    String? keyHex,
  }) {
    final db = sqlite3.sqlite3.open(path, mode: mode);
    try {
      // Basics only, never the journal mode: this opens backup artifacts and
      // candidate files at other locations as well as the live database, and
      // a probe has no business rewriting the header of a file it is only
      // looking at. WAL is set by _connectionSetup, on the real connection.
      applyConnectionBasics(db, keyHex: keyHex);
    } catch (_) {
      db.close();
      rethrow;
    }
    return db;
  }

  /// True when [error] is SQLite's NOTADB ("file is not a database", primary
  /// result code 26) — what SQLCipher raises when reading an encrypted file
  /// with a missing or wrong key.
  static bool _isNotADatabaseError(Object error) =>
      error is sqlite3.SqliteException && error.resultCode == 26;

  /// Force SQLite to complete any pending hot-journal rollback on [dbPath].
  ///
  /// Opens the file in read-write mode — the very act of opening triggers
  /// SQLite's automatic recovery of a hot journal. Returns true if the file
  /// opened cleanly (recovery either wasn't needed or succeeded), false if
  /// the journal could not be rolled back (file still read-only, on a
  /// read-only volume, etc.).
  ///
  /// Safe to call on a file without a hot journal: it simply no-ops.
  static bool recoverHotJournal(String dbPath, {String? keyHex}) {
    final file = File(dbPath);
    if (!file.existsSync()) return true;
    try {
      final db = openRaw(dbPath, keyHex: keyHex);
      try {
        db.select('PRAGMA user_version');
      } finally {
        db.close();
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

  /// Copies the live database to [destinationPath] as a PLAINTEXT SQLite
  /// file — always. Backups are portable by design: they must restore on a
  /// device where the DB password is unknown, and the existing SBE1 backup
  /// encryption remains the (orthogonal) way to protect backup artifacts.
  ///
  /// Plaintext live DB: plain file copy, as before. Encrypted live DB:
  /// decrypt-export through a staging file, then rename into place.
  Future<void> backup(String destinationPath) async {
    final sourcePath = await databasePath;
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return;

    // Ensure the destination directory exists
    final destDir = Directory(p.dirname(destinationPath));
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final keyHex = databaseKeyHex;
    if (keyHex != null && isEncryptedDatabaseFile(sourcePath)) {
      final exporter = debugExporterOverride ?? sqlcipherExport;
      final staging = '$destinationPath.export-staging';
      await _deleteIfExists(staging);
      try {
        await exporter(
          sourcePath: sourcePath,
          targetPath: staging,
          sourceKeyHex: keyHex,
          targetKeyHex: null,
        );
        await _deleteIfExists(destinationPath);
        await File(staging).rename(destinationPath);
      } catch (_) {
        await _bestEffortDelete(staging);
        rethrow;
      }
      return;
    }

    // Plaintext live DB. Export through SQLite rather than copying bytes: the
    // database is OPEN and serving while this runs (no caller closes it), so a
    // byte copy would miss every committed row still in `<db>-wal` under WAL,
    // and could capture a torn mid-transaction state under DELETE.
    final snapshotter = debugSnapshotterOverride ?? vacuumIntoSnapshot;
    final staging = '$destinationPath.export-staging';
    await _deleteIfExists(staging);
    var exported = false;
    try {
      await snapshotter(sourcePath: sourcePath, targetPath: staging);
      exported = true;
    } catch (e, stack) {
      await _bestEffortDelete(staging);
      // Degraded fallback, deliberately not a rethrow -- and scoped to the
      // EXPORT alone. A source SQLite cannot open (corrupt, truncated, a
      // foreign file at the database path) has no SQL-level export, but its
      // bytes are still the only copy of whatever survives in it and may be
      // all a recovery has to work with. The pre-migration backup makes the
      // same trade for the same reason.
      _log.warning(
        'Database export for the backup failed; falling back to a raw file '
        'copy, which may omit WAL-resident rows',
        error: e,
        stackTrace: stack,
      );
    }

    if (exported) {
      // Past this point the artifact is good and only its PLACEMENT can fail
      // (an unwritable destination, a cross-device rename). Falling back to a
      // byte copy there would swap a correct backup for a lossy one over a
      // problem the copy would hit as well, so these errors surface.
      try {
        await _deleteIfExists(destinationPath);
        await File(staging).rename(destinationPath);
      } catch (_) {
        await _bestEffortDelete(staging);
        rethrow;
      }
      return;
    }

    await sourceFile.copy(destinationPath);
  }

  /// Test seam for the SQL-level export used by [backup] on a plaintext
  /// database. Mirrors [debugExporterOverride], which covers the encrypted
  /// branch.
  @visibleForTesting
  DatabaseSnapshotter? debugSnapshotterOverride;

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

  /// Swap the live database for [backupPath].
  ///
  /// [onMigrationProgress] is forwarded to the post-swap [initialize]: when
  /// the restored file carries an older schema, the reopen runs the upgrade
  /// ladder, and this callback is the only feedback the user gets during it.
  Future<void> restore(
    String backupPath, {
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
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
      // The old WAL/SHM sidecars belong to the pre-restore database and must
      // not be next to the swapped-in file: SQLite would replay them into it
      // and corrupt it. They travel WITH the file they belong to rather than
      // being deleted, because the rollback below has to put back a complete
      // database. A clean close normally checkpoints the -wal away, but not
      // when another isolate still holds the database open -- and that is
      // exactly when a restore is most likely to fail its swap.
      await _moveIfExists('$destinationPath-wal', '$asidePath-wal');
      await _moveIfExists('$destinationPath-shm', '$asidePath-shm');
      await File(stagingPath).rename(destinationPath);
    } catch (_) {
      // The swap failed with the database closed. Roll the original file and
      // its sidecars back into place, drop the orphaned staging copy, and
      // reopen so the app is never left with a dead (null) database, then
      // surface the error.
      if (hadDest &&
          !await destFile.exists() &&
          await File(asidePath).exists()) {
        await File(asidePath).rename(destinationPath);
        await _moveIfExists('$asidePath-wal', '$destinationPath-wal');
        await _moveIfExists('$asidePath-shm', '$destinationPath-shm');
      }
      await _deleteIfExists(stagingPath);
      await initialize();
      rethrow;
    }

    // A restored backup is plaintext (portable-backup hard rule). When the
    // live database is protected, re-encrypt the swapped-in file before the
    // reopen so protection survives a restore without user action.
    final keyHex = databaseKeyHex;
    if (keyHex != null && !isEncryptedDatabaseFile(destinationPath)) {
      await DatabaseEncryptionMigrator(
        exporter: debugExporterOverride ?? sqlcipherExport,
      ).encryptInPlace(dbPath: destinationPath, keyHex: keyHex);
    }

    // Reopen on the swapped-in file BEFORE dropping the pre-restore copy, so a
    // cleanup hiccup can never prevent the reopen. An older-schema backup runs
    // its migration ladder here; surface its progress to the caller.
    try {
      await initialize(onMigrationProgress: onMigrationProgress);
    } on DatabaseVersionMismatchException {
      // The restored file needs a newer app than this one. The backup layer
      // pre-checks make this near-unreachable, but a raced or hand-placed
      // file can still reach here, and by now the newer file is already live.
      // Put the pre-restore database back and reopen so the app keeps a
      // working library, then surface the error (issue #1089).
      //
      // Scoped to this one exception on purpose: every other reopen failure
      // (corruption, a locked file) is the restored file's own problem and
      // keeps its existing handling, which may legitimately want the
      // swapped-in file left in place for recovery.
      await _deleteIfExists(destinationPath);
      await _deleteIfExists('$destinationPath-wal');
      await _deleteIfExists('$destinationPath-shm');
      if (hadDest && await File(asidePath).exists()) {
        await File(asidePath).rename(destinationPath);
        await _moveIfExists('$asidePath-wal', '$destinationPath-wal');
        await _moveIfExists('$asidePath-shm', '$destinationPath-shm');
      }
      await initialize();
      rethrow;
    }

    // The database is open again on the restored file; the pre-restore copy is
    // no longer needed. Its deletion is best-effort — a transient failure (e.g.
    // a Windows file lock) must NOT fail a restore that already succeeded and
    // leave the app with a closed database despite a valid file on disk. A
    // leftover copy is harmless and is swept by the next restore (including a
    // no-op one).
    await _bestEffortDelete(asidePath);
    await _bestEffortDelete('$asidePath-wal');
    await _bestEffortDelete('$asidePath-shm');
  }

  /// Renames [from] onto [to] when [from] exists, replacing [to].
  Future<void> _moveIfExists(String from, String to) async {
    final source = File(from);
    if (!await source.exists()) return;
    await _deleteIfExists(to);
    await source.rename(to);
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
    // The aside copy carries its sidecars now, so they can be stranded too.
    await _bestEffortDelete('$destinationPath.pre-restore-wal');
    await _bestEffortDelete('$destinationPath.pre-restore-shm');
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
