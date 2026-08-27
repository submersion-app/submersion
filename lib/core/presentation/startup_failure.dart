import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database_connection_setup.dart';
import 'package:submersion/core/database/database_engine_preflight.dart';

/// How far startup had got when it failed.
///
/// Classification cannot come from the exception alone: "database or disk is
/// full" thrown while the upgrade ladder is running genuinely is a failed
/// upgrade, and the same exception thrown while services are starting is not.
/// Issue #1134 is exactly that conflation: every terminal failure was
/// reported under the fixed title "Database upgrade failed".
enum StartupPhase {
  /// Before any migration could have begun: the engine preflight, the
  /// security gate and the schema-version probe all run here.
  ///
  /// Note this does NOT mean the database file is untouched. The security
  /// gate reads its header and the schema probe opens it read-write to read
  /// `PRAGMA user_version`. Only the engine preflight, which runs first
  /// against an in-memory database, can guarantee the file was never reached.
  preflight,

  /// No schema upgrade was pending, or the ladder has already finished. The
  /// database is opening and the remaining services are starting.
  opening,

  /// The schema-upgrade ladder is in flight. A pre-migration safety copy has
  /// already been taken by this point, and the phase returns to [opening] as
  /// soon as the ladder finishes, so ordinary service failures after a
  /// SUCCESSFUL upgrade are not reported as upgrade failures.
  upgrading,
}

/// The distinct terminal startup failures, each of which answers the question
/// a diver actually has ("is my data at risk?") differently.
enum StartupFailureKind {
  /// The database engine itself is unusable: a missing or non-SQLCipher native
  /// library. The database was never opened, so nothing is at risk and neither
  /// a reinstall nor a restore can help. Only a working build can.
  engineUnavailable,

  /// The schema-upgrade ladder failed part way. The pre-migration safety copy
  /// is the route back.
  migrationFailed,

  /// The database file was reached but cannot be read: corrupt, truncated, or
  /// not a database at all. Restoring a backup is the fastest way back.
  dataUnreadable,

  /// Another connection held a lock the whole time SQLite was willing to wait
  /// for it. Nothing is damaged and nothing was changed -- SQLITE_BUSY is a
  /// refusal to START the statement, so the transaction rolled back intact.
  /// Closing Submersion fully and reopening is the whole fix.
  databaseBusy,

  /// Nothing more specific could be established. Treated conservatively: the
  /// failure is assumed to have reached the database, so the recovery routes
  /// stay on offer, but the app does not claim an upgrade failed.
  unknown;

  /// Whether the diver's database could plausibly have been touched.
  ///
  /// Drives both the reassurance wording and whether restore is offered.
  /// [engineUnavailable] promises the file was never opened; [databaseBusy]
  /// promises it was opened but never written. Offering a restore for a lock
  /// would invite a diver to overwrite a perfectly intact database.
  bool get dataIsAtRisk =>
      this != StartupFailureKind.engineUnavailable &&
      this != StartupFailureKind.databaseBusy;
}

/// SQLite primary result code 11, SQLITE_CORRUPT.
const int _sqliteCorrupt = 11;

/// SQLite primary result code 26, SQLITE_NOTADB. Also what SQLCipher answers
/// when reading an encrypted file with a missing or wrong key. The startup
/// gate resolves that case into [DatabaseLockedException] long before
/// anything reaches here, so at this point it means unreadable data.
const int _sqliteNotADatabase = 26;

/// Substrings that identify a native-library failure rather than a database
/// problem.
///
/// Matching on message text is unavoidable: `dart:ffi` reports an unresolved
/// symbol as a plain [ArgumentError] with no distinguishing type, which is
/// precisely why #1129 fell through to the generic handler. The list is
/// deliberately specific enough that no ordinary database error matches.
const List<String> _engineFailureMarkers = [
  "couldn't resolve native function",
  'could not resolve native function',
  'failed to load dynamic library',
  'failed to lookup symbol',
  'sqlcipher is not linked',
];

/// Substrings that identify an unreadable database file where the SQLite
/// result code is not reachable (drift and the isolate boundary both wrap
/// some failures into plainer error types).
const List<String> _unreadableDataMarkers = [
  'database disk image is malformed',
  'file is not a database',
];

/// Classifies a terminal startup failure into the class whose title and body
/// tell the diver the truth about their data.
///
/// Order matters. An engine failure is recognised first and overrides the
/// phase entirely: #1129 died at the security gate while the app believed a
/// migration was underway, and calling that a failed upgrade pointed diagnosis
/// at migration code when the defect was in Windows packaging.
StartupFailureKind classifyStartupFailure(Object error, StartupPhase phase) {
  if (error is DatabaseEngineUnavailableException) {
    return StartupFailureKind.engineUnavailable;
  }

  final message = error.toString().toLowerCase();

  if (_engineFailureMarkers.any(message.contains)) {
    return StartupFailureKind.engineUnavailable;
  }

  if (error is sqlite3.SqliteException &&
      (error.resultCode == _sqliteCorrupt ||
          error.resultCode == _sqliteNotADatabase)) {
    return StartupFailureKind.dataUnreadable;
  }

  if (_unreadableDataMarkers.any(message.contains)) {
    return StartupFailureKind.dataUnreadable;
  }

  // Before the phase check: a lock met while the ladder ran is NOT a failed
  // upgrade. SQLite refused to start the write, so the ladder changed
  // nothing, and reporting it as a failed migration told the diver their data
  // was at risk and offered to restore an older backup over an intact file.
  //
  // Shares [isDatabaseBusyError] with the open path that RETRIES on a lock,
  // so what the screen calls a lock and what the retry gives up on can never
  // drift apart. By the time a lock reaches here the retries are exhausted.
  if (isDatabaseBusyError(error)) {
    return StartupFailureKind.databaseBusy;
  }

  if (phase == StartupPhase.upgrading) {
    return StartupFailureKind.migrationFailed;
  }

  return StartupFailureKind.unknown;
}
