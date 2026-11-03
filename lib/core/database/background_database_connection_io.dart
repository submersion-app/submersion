import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database_connection_setup.dart';

/// Builds the worker's database opener in its own scope.
///
/// Dart closures capture the whole enclosing scope rather than just the
/// variables they reference, so a closure created next to an unsendable local
/// (a [ReceivePort], for instance) cannot be sent to an isolate. Minting it
/// here keeps the capture context down to [path] and [keyHex] — both plain
/// Strings, so they cross the isolate boundary.
DatabaseConnection Function() _openerFor(String path, String? keyHex) {
  return () => openMainIsolateConnection(path, keyHex: keyHex);
}

/// Opens the main database at [path] on the calling isolate, with the
/// connection setup every main-database connection needs: the SQLCipher key
/// first, then the busy timeout and the WAL journal mode.
///
/// This is the synchronous executor the upgrade ladder runs on, and it is the
/// single place WAL is turned on. Every other opener of a database file (the
/// raw probes in `DatabaseService.openRaw`, the backup exporters) is
/// deliberately journal-mode-neutral.
DatabaseConnection openMainIsolateConnection(String path, {String? keyHex}) {
  return DatabaseConnection(
    NativeDatabase(
      File(path),
      setup: (db) => applyMainDatabaseSetup(db, keyHex: keyHex),
    ),
  );
}

/// The opener for [BackgroundDatabaseConnection.openPlain], minted in its own
/// scope for the same reason as [_openerFor].
DatabaseConnection Function() _plainOpenerFor(String path) {
  return () => DatabaseConnection(
    NativeDatabase(File(path), setup: registerAppSqlFunctions),
  );
}

/// Closes [db] for process shutdown, tolerating the two ways a plain
/// `db.close()` fails at exit:
///
/// 1. `GeneratedDatabase.close()` awaits `streamQueries.close()` before it
///    closes the executor, and that await hangs forever while any `watch()`
///    subscription is paused — which Riverpod 3 does to the streams of
///    providers nobody is currently listening to. A close that hangs there
///    never even *asks* SQLite to close.
/// 2. On a background connection, the executor close resolves when the worker
///    acknowledges the request, not when SQLite is actually closed.
///
/// So: try the graceful close briefly, then close the executor directly
/// (idempotent — a no-op when the graceful close already did it), then wait
/// for the worker isolate, killing it if stuck. Skipping the stream-store
/// cleanup is harmless here because the process is exiting.
///
/// Returns true when the database shut down cleanly, false when the worker
/// had to be killed.
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
    // For a main-isolate NativeDatabase this IS the real sqlite3 close; for a
    // background connection it sends the shutdown request the hung graceful
    // close never got to.
    await db.executor.close().timeout(executorTimeout, onTimeout: () {});
  } catch (_) {
    // Same: exit path, nothing to do about a failed close.
  }

  if (background == null) return true;
  try {
    return await background.awaitWorkerShutdown(
      timeout: workerTimeout,
      killIfStuck: true,
    );
  } catch (_) {
    return false;
  }
}

/// A drift connection whose SQLite work runs on a background isolate that this
/// class owns, so shutdown can wait for the worker to *actually* finish.
///
/// [NativeDatabase.createInBackground] is the stock way to get this, but it
/// keeps the spawned isolate private, and closing such a connection does not
/// wait for SQLite to close: drift's remote server answers the `terminateAll`
/// request before running `connection.close()`, so `AppDatabase.close()`
/// completes while the worker is still inside `sqlite3_close_v2`.
///
/// That is harmless mid-session but fatal at app exit. Drift registers Dart
/// implementations of SQL functions (`pow`, `regexp`, ...) on every native
/// connection, so closing the database calls back into Dart from C via
/// `functionDestroy`. If macOS has already been told the app may terminate,
/// the Dart VM tears down its FFI callback metadata first and the worker
/// aborts with `GetFfiCallbackMetadata called after shutdown`, leaving the
/// app hanging in the Dock.
///
/// Owning the isolate gives shutdown a signal it can trust: the worker exits
/// only once the drift server is done, which is strictly after SQLite has
/// been closed.
class BackgroundDatabaseConnection {
  BackgroundDatabaseConnection._(
    this.connection,
    this._worker,
    this._exitPort,
    this._workerExited,
  );

  /// The executor to hand to a generated drift database.
  final DatabaseConnection connection;

  /// Where the browser serves `sqlite3.wasm` and `drift_worker.js` from.
  /// Unused on a native build; here so the facade's two halves match.
  @visibleForTesting
  static String assetBase = '';

  final Isolate _worker;
  final ReceivePort _exitPort;
  final Future<void> _workerExited;

  /// Opens the database at [path] on a dedicated worker isolate.
  ///
  /// [keyHex] is the SQLCipher raw key for an encrypted database; the worker
  /// applies it as the first statement on its connection.
  ///
  /// [debugOpener] replaces what the worker opens. It exists so tests can give
  /// the worker a deliberately slow-closing executor; it must be a closure
  /// that can be sent to an isolate (see [_openerFor]).
  static Future<BackgroundDatabaseConnection> open(
    String path, {
    String? keyHex,
    @visibleForTesting DatabaseConnection Function()? debugOpener,
  }) =>
      _spawn(path, debugOpener ?? _openerFor(File(path).absolute.path, keyHex));

  /// Opens the database at [path] on a dedicated worker isolate with none of
  /// the main
  /// database's connection setup: no SQLCipher key, no busy timeout, and no
  /// switch to WAL, so the file keeps whatever journal mode it already has.
  ///
  /// For the per-device local cache database, which is never encrypted and has
  /// a single connection. WAL would buy it nothing, and under WAL a VACUUM does
  /// not shrink the file until a checkpoint.
  static Future<BackgroundDatabaseConnection> openPlain(String path) =>
      _spawn(path, _plainOpenerFor(File(path).absolute.path));

  /// The browser reads the stored schema version through a probe
  /// connection; a native build reads it synchronously through
  /// `DatabaseService.getStoredSchemaVersion`, so this is never called.
  static Future<int> readStoredSchemaVersion(String path) =>
      throw UnsupportedError(
        'native builds read the stored version through DatabaseService',
      );

  /// The browser's wipe for Forget this device; a native build deletes
  /// its file through `DatabaseService`, so this is never called.
  static Future<void> deleteStoredDatabases(String path) async {
    throw UnsupportedError('native builds delete the database file');
  }

  /// drift's name for a browser database at [path]; the same rule as the
  /// browser file, so code built for both can name one.
  static String databaseNameFor(String path) =>
      p.basenameWithoutExtension(path);

  /// The databases a browser stores; a native build lists files instead,
  /// so this is never called.
  static Future<Set<String>> storedDatabaseNames({
    Iterable<String> alsoCheck = const [],
  }) async {
    throw UnsupportedError('native builds keep database files');
  }

  /// Whether a browser database is stored under [path]'s name; a native
  /// build looks for the file instead, so this is never called.
  static Future<bool> storedDatabaseExists(String path) async {
    throw UnsupportedError('native builds keep database files');
  }

  /// The browser's wipe of every database it stores; a native build deletes
  /// its files through `DatabaseService`, so this is never called.
  static Future<void> deleteAllStoredDatabases({
    Iterable<String> alsoCheck = const [],
  }) async {
    throw UnsupportedError('native builds delete the database files');
  }

  /// The browser's install of a database from bytes; a native build copies
  /// a file into place through `DatabaseService`, so this is never called.
  static Future<void> installImage(String path, Uint8List image) async {
    throw UnsupportedError('native builds copy the database file');
  }

  static Future<BackgroundDatabaseConnection> _spawn(
    String path,
    DatabaseConnection Function() opener,
  ) async {
    final exitPort = ReceivePort('submersion drift worker exit');
    final exited = Completer<void>();
    exitPort.listen((_) {
      if (!exited.isCompleted) exited.complete();
    });

    Isolate? worker;
    try {
      final driftIsolate = await DriftIsolate.spawn(
        opener,
        isolateSpawn: <T>(entrypoint, message) async {
          final isolate = await Isolate.spawn(
            entrypoint,
            message,
            debugName: 'Submersion drift worker for $path',
          );
          // Registered before the worker can finish any work, so the exit
          // event cannot be missed.
          isolate.addOnExitListener(exitPort.sendPort);
          worker = isolate;
          return isolate;
        },
      );

      final connection = await driftIsolate.connect(singleClientMode: true);
      return BackgroundDatabaseConnection._(
        connection,
        worker!,
        exitPort,
        exited.future,
      );
    } catch (_) {
      exitPort.close();
      worker?.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  /// Waits for the worker isolate to exit, which happens only after it has
  /// closed SQLite. Call this *after* closing the drift database.
  ///
  /// Returns true when the worker exited on its own. When it does not exit
  /// within [timeout]:
  ///
  /// * with [killIfStuck] (app shutdown), the worker is killed so it cannot
  ///   run FFI callbacks while the VM is tearing down, and false is returned.
  ///   The database file is left to SQLite's own crash recovery, which is
  ///   safe: committed data is already durable in the WAL.
  /// * without it (close-then-reopen paths such as a storage move or a
  ///   restore), a [TimeoutException] is thrown instead, because killing the
  ///   worker would strand an open SQLite handle — and its file locks — in a
  ///   process that is about to reopen the same file.
  ///
  /// Safe to call more than once: every call genuinely waits for the exit
  /// event (awaiting the already-completed future is a no-op after the worker
  /// has exited, and closing the port or killing the isolate again does
  /// nothing).
  Future<bool> awaitWorkerShutdown({
    required Duration timeout,
    required bool killIfStuck,
  }) async {
    try {
      await _workerExited.timeout(timeout);
      _exitPort.close();
      return true;
    } on TimeoutException {
      if (!killIfStuck) rethrow;
      _worker.kill(priority: Isolate.immediate);
      try {
        await _workerExited.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Nothing further to do: the process is exiting either way.
      }
      _exitPort.close();
      return false;
    }
  }
}
