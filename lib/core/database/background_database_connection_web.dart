import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database_engine_preflight.dart';
import 'package:submersion/core/platform/web_database_status.dart';

/// Closes [db] for page unload.
///
/// A browser connection has no worker isolate to wait for, so the graceful
/// close and the executor close are the whole story; both are bounded so a
/// paused stream subscription cannot hang the unload.
Future<bool> closeDatabaseForAppShutdown(
  GeneratedDatabase db, {
  BackgroundDatabaseConnection? background,
  Duration gracefulTimeout = const Duration(seconds: 1),
  Duration executorTimeout = const Duration(seconds: 2),
  Duration workerTimeout = const Duration(seconds: 5),
}) async {
  try {
    await db.close().timeout(gracefulTimeout, onTimeout: () {});
  } catch (_) {
    // Abandoning this connection; errors are irrelevant at exit.
  }
  try {
    await db.executor.close().timeout(executorTimeout, onTimeout: () {});
  } catch (_) {
    // Same: exit path, nothing to do about a failed close.
  }
  return true;
}

/// Opens the main database on the calling isolate.
///
/// Not available in a browser: SQLite runs in drift's worker, and there is
/// no synchronous handle to run the upgrade ladder on. The browser open runs
/// drift's migrations on the first statement instead.
DatabaseConnection openMainIsolateConnection(String path, {String? keyHex}) =>
    throw UnsupportedError('a browser has no synchronous SQLite connection');

/// The browser's database connection: drift's [WasmDatabase] running
/// `sqlite3.wasm` in the compiled `drift_worker.js`, stored in the origin
/// private file system where the browser allows it.
///
/// The database is named after the path's file name, so the main database
/// and the local cache keep their names across platforms while the path
/// itself stays a virtual `/opfs/...` string. What drift chose for storage is
/// recorded in [WebDatabaseStatusHolder] for the Settings page.
class BackgroundDatabaseConnection {
  BackgroundDatabaseConnection._(this.connection);

  /// The executor to hand to a generated drift database.
  final DatabaseConnection connection;

  /// Where `sqlite3.wasm` and `drift_worker.js` are served from, relative to
  /// the page. Empty in the app, where they sit next to `main.dart.js`; the
  /// browser tests point it at the served test assets.
  @visibleForTesting
  static String assetBase = '';

  static Uri get sqlite3Uri => Uri.parse('${assetBase}sqlite3.wasm');
  static Uri get driftWorkerUri => Uri.parse('${assetBase}drift_worker.js');

  /// drift's name for the database at [path]: the file name without its
  /// extension (`submersion`, `submersion_local`).
  static String databaseNameFor(String path) =>
      p.basenameWithoutExtension(path);

  /// Opens the database at [path].
  ///
  /// [keyHex] must be null: encryption at rest is not offered in a browser,
  /// and a key would be a promise the storage cannot keep. [debugOpener]
  /// replaces the connection for tests, as on native.
  static Future<BackgroundDatabaseConnection> open(
    String path, {
    String? keyHex,
    @visibleForTesting DatabaseConnection Function()? debugOpener,
  }) async {
    if (keyHex != null) {
      throw ArgumentError.value(
        keyHex,
        'keyHex',
        'encryption at rest is not offered in a browser',
      );
    }
    if (debugOpener != null) {
      return BackgroundDatabaseConnection._(debugOpener());
    }
    final result = await _openWasm(path, enableMigrations: true);
    WebDatabaseStatusHolder.record(
      WebDatabaseStatus(
        storage: WebDatabaseStorage.fromName(result.chosenImplementation.name),
        missingFeatures: {for (final f in result.missingFeatures) f.name},
      ),
    );
    return BackgroundDatabaseConnection._(result.resolvedExecutor);
  }

  /// Opens the database at [path] with no main-database setup. In a browser
  /// the two opens are the same: there is no cipher and no journal mode to
  /// choose.
  static Future<BackgroundDatabaseConnection> openPlain(String path) =>
      open(path);

  /// The `PRAGMA user_version` of the database at [path], read through a
  /// probe connection with drift's migrations switched off so nothing is
  /// created or upgraded by the look. Zero for a database drift has not yet
  /// created.
  static Future<int> readStoredSchemaVersion(String path) async {
    final result = await _openWasm(path, enableMigrations: false);
    final probe = _ProbeDatabase(result.resolvedExecutor);
    try {
      final row = await probe.customSelect('PRAGMA user_version').getSingle();
      return row.read<int>('user_version');
    } finally {
      await probe.close();
    }
  }

  /// Nothing to wait for: a browser connection owns no worker isolate.
  /// Deletes every stored copy of the database at [path], in whichever
  /// browser storage drift put it (OPFS or IndexedDB), through drift's own
  /// probe, and throws when a copy is still there afterwards: Forget this
  /// device must not reload over a surviving logbook (issue #4121).
  static Future<void> deleteStoredDatabases(String path) async {
    final name = databaseNameFor(path);
    final probe = await WasmDatabase.probe(
      sqlite3Uri: sqlite3Uri,
      driftWorkerUri: driftWorkerUri,
      databaseName: name,
    );
    for (final existing in probe.existingDatabases) {
      if (existing.$2 == name) await probe.deleteDatabase(existing);
    }
    final after = await WasmDatabase.probe(
      sqlite3Uri: sqlite3Uri,
      driftWorkerUri: driftWorkerUri,
      databaseName: name,
    );
    final kept = [
      for (final existing in after.existingDatabases)
        if (existing.$2 == name) existing.$1.name,
    ];
    if (kept.isNotEmpty) {
      throw StateError('the browser kept the database in ${kept.join(', ')}');
    }
  }

  Future<bool> awaitWorkerShutdown({
    required Duration timeout,
    required bool killIfStuck,
  }) async => true;

  static Future<WasmDatabaseResult> _openWasm(
    String path, {
    required bool enableMigrations,
  }) async {
    try {
      return await WasmDatabase.open(
        databaseName: databaseNameFor(path),
        sqlite3Uri: sqlite3Uri,
        driftWorkerUri: driftWorkerUri,
        localSetup: registerAppSqlFunctions,
        enableMigrations: enableMigrations,
      );
    } catch (e) {
      // No user file has been touched: the engine or its worker did not
      // load, so the startup failure screen says the build is broken rather
      // than blaming the diver's data.
      throw DatabaseEngineUnavailableException(
        'The browser could not load the SQLite engine (sqlite3.wasm or '
        'drift_worker.js).',
        cause: e,
      );
    }
  }
}

/// A schema-less database for reading pragmas over a probe connection.
class _ProbeDatabase extends GeneratedDatabase {
  _ProbeDatabase(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}
