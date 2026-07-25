import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Builds the worker's database opener in its own scope.
///
/// Dart closures capture the whole enclosing scope rather than just the
/// variables they reference, so a closure created next to an unsendable local
/// (a [ReceivePort], for instance) cannot be sent to an isolate. Minting it
/// here keeps the capture context down to [path].
DatabaseConnection Function() _openerFor(String path) {
  return () => DatabaseConnection(NativeDatabase(File(path)));
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

  final Isolate _worker;
  final ReceivePort _exitPort;
  final Future<void> _workerExited;

  /// Opens [file] on a dedicated worker isolate.
  ///
  /// [debugOpener] replaces what the worker opens. It exists so tests can give
  /// the worker a deliberately slow-closing executor; it must be a closure
  /// that can be sent to an isolate (see [_openerFor]).
  static Future<BackgroundDatabaseConnection> open(
    File file, {
    @visibleForTesting DatabaseConnection Function()? debugOpener,
  }) async {
    final exitPort = ReceivePort('submersion drift worker exit');
    final exited = Completer<void>();
    exitPort.listen((_) {
      if (!exited.isCompleted) exited.complete();
    });

    Isolate? worker;
    try {
      final driftIsolate = await DriftIsolate.spawn(
        debugOpener ?? _openerFor(file.absolute.path),
        isolateSpawn: <T>(entrypoint, message) async {
          final isolate = await Isolate.spawn(
            entrypoint,
            message,
            debugName: 'Submersion drift worker for ${file.path}',
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
