import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

const String _pending = 'Plan 2 adds the browser database';

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
/// Not available in a browser: there is no synchronous SQLite handle there.
DatabaseConnection openMainIsolateConnection(String path, {String? keyHex}) =>
    throw UnsupportedError(_pending);

/// Browser placeholder for the background database connection.
///
/// Every open throws until the browser database lands; the class surface
/// matches the native file so callers compile unchanged.
class BackgroundDatabaseConnection {
  BackgroundDatabaseConnection._(this.connection);

  /// The executor to hand to a generated drift database.
  final DatabaseConnection connection;

  /// Throws [UnsupportedError] until the browser database lands.
  static Future<BackgroundDatabaseConnection> open(
    String path, {
    String? keyHex,
    @visibleForTesting DatabaseConnection Function()? debugOpener,
  }) async => throw UnsupportedError(_pending);

  /// Throws [UnsupportedError] until the browser database lands.
  static Future<BackgroundDatabaseConnection> openPlain(String path) async =>
      throw UnsupportedError(_pending);

  /// Nothing to wait for: a browser connection owns no worker isolate.
  Future<bool> awaitWorkerShutdown({
    required Duration timeout,
    required bool killIfStuck,
  }) async => true;
}
