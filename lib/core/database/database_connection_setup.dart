import 'dart:async';

import 'package:sqlite3/sqlite3.dart' show Database, SqliteException;

import 'package:submersion/core/database/sqlcipher_setup.dart';

/// How long a connection waits for a lock another connection holds before it
/// gives up with SQLITE_BUSY ("database is locked", result code 5).
///
/// SQLite's default is ZERO: without this, the first statement to meet a lock
/// fails instantly rather than waiting for the microseconds-to-milliseconds
/// the holder actually needs. That is not hypothetical here -- the main
/// database is opened from two isolates (the UI isolate and the Workmanager
/// headless isolate), and `beforeOpen` re-asserts schema and re-seeds the
/// built-in reference data on EVERY open, so both isolates write the moment
/// they connect.
///
/// Five seconds is a deliberate middle: comfortably longer than the open-time
/// re-assert an overlapping isolate is doing, and short enough that a lock
/// that is genuinely stuck still surfaces as an error instead of presenting
/// as a hung launch.
const Duration kDatabaseBusyTimeout = Duration(seconds: 5);

/// Applies the settings every connection to the MAIN database needs, in the
/// order SQLite requires them, and returns the journal mode the connection
/// ended up in.
///
/// The order is not cosmetic:
///
/// 1. [keyHex] when present. SQLCipher's key pragma must be the first
///    statement executed on a connection, before anything (the busy timeout
///    included) touches a page.
/// 2. The busy timeout, BEFORE the journal mode. Converting a database to WAL
///    takes a brief exclusive lock, so on a file another isolate already has
///    open the conversion is exactly the kind of statement the timeout exists
///    to let wait rather than fail.
/// 3. WAL. See [_applyWalJournalMode].
///
/// Deliberately lives next to [cipherKeyPragma] rather than on
/// `DatabaseService`, so the drift worker isolate can call it without
/// importing `database_service.dart` -- that file imports this one.
String applyMainDatabaseSetup(Database db, {String? keyHex}) {
  applyConnectionBasics(db, keyHex: keyHex);
  return _applyWalJournalMode(db);
}

/// The part of [applyMainDatabaseSetup] that is safe on ANY database file:
/// the key and the busy timeout, both of which are per-connection settings
/// that leave no trace in the file.
///
/// The journal mode is deliberately not here. It is written into the database
/// header and outlives the connection, so a short-lived probe -- a schema
/// version read, an integrity check, a look at what a folder holds -- must not
/// impose it. Several of those probes run against BACKUP ARTIFACTS, which have
/// to stay single self-contained files: converting one to WAL would leave
/// `-wal`/`-shm` next to it and make the next read-only open (a file the
/// picker handed us out of a read-only directory) need an `-shm` it cannot
/// create.
void applyConnectionBasics(Database db, {String? keyHex}) {
  if (keyHex != null) {
    db.execute(cipherKeyPragma(keyHex));
  }
  db.execute('PRAGMA busy_timeout = ${kDatabaseBusyTimeout.inMilliseconds}');
}

/// Asks for WAL and reports what SQLite actually settled on.
///
/// Why WAL: in the default rollback-journal (`DELETE`) mode a reader blocks a
/// writer and a writer blocks everything. The main database is opened from two
/// isolates (the UI isolate and the Workmanager headless isolate) and
/// `beforeOpen` re-asserts schema and re-seeds reference data on EVERY open,
/// so both write the moment they connect. Under WAL readers and a writer no
/// longer exclude each other, which removes most of that contention instead of
/// waiting it out with [kDatabaseBusyTimeout].
///
/// Never fatal. WAL needs to place `-wal` and `-shm` next to the database and
/// needs real shared memory, which some filesystems cannot provide -- a
/// network mount, or an in-memory database. SQLite's own answer there is to
/// keep the existing mode and report it rather than to fail, and an
/// unavailable optimisation must not cost a diver their launch, so a hard
/// error is caught and answered the same way.
///
/// That swallowing includes SQLITE_BUSY, so a conversion that loses a race
/// with another isolate is NOT retried by [retryWhileDatabaseBusy] even though
/// it wraps the open. Deliberate: journal mode is persistent and re-asserted
/// on every open, so the cost of losing that race is one session running in
/// the previous mode, against the alternative of failing an open over a
/// setting the database does not need to function.
///
/// Anything that copies the database file must be WAL-aware once this is on:
/// committed data lives in `<db>-wal` until a checkpoint folds it back, so a
/// byte copy of `<db>` alone is missing the newest rows. See
/// `vacuumIntoSnapshot`, which is how backups avoid that.
String _applyWalJournalMode(Database db) {
  try {
    // Returns one row holding the resulting mode -- 'wal' on success, the
    // unchanged previous mode when SQLite declines.
    final result = db.select('PRAGMA journal_mode = WAL');
    if (result.isNotEmpty) {
      return result.first.values.first as String? ?? '';
    }
  } catch (_) {
    // Fall through to reporting whatever mode the connection is in.
  }
  try {
    return db.select('PRAGMA journal_mode').first.values.first as String? ?? '';
  } catch (_) {
    return '';
  }
}

/// SQLite primary result code 5, SQLITE_BUSY: another connection holds the
/// lock. 6, SQLITE_LOCKED, is the same story inside one connection.
const int _sqliteBusy = 5;
const int _sqliteLocked = 6;

/// SQLite's exact `errmsg` texts for a lock, matched when the result code is
/// out of reach: drift's remote executor and the isolate boundary can both
/// re-wrap a failure into a plainer error type.
const List<String> _busyMessages = [
  'database is locked',
  'database table is locked',
  'database schema is locked',
];

/// True when [error] is SQLite refusing to proceed because something else
/// holds a lock.
///
/// Deliberately shared: the startup screen classifies on it to decide what to
/// tell the diver, and the open path retries on it. One definition means the
/// two can never disagree about what counts as a lock.
bool isDatabaseBusyError(Object error) {
  if (error is SqliteException &&
      (error.resultCode == _sqliteBusy || error.resultCode == _sqliteLocked)) {
    return true;
  }
  final message = error.toString().toLowerCase();
  return _busyMessages.any(message.contains);
}

/// How many times an open is attempted before a lock is allowed to fail it.
const int kDatabaseBusyOpenAttempts = 4;

/// Base delay between those attempts; the wait grows linearly with the
/// attempt number, so four attempts span roughly 1.5 seconds of backoff on
/// top of whatever [kDatabaseBusyTimeout] already absorbed.
const Duration kDatabaseBusyOpenBackoff = Duration(milliseconds: 250);

/// Runs [attempt], retrying while SQLite reports the database is locked.
///
/// [kDatabaseBusyTimeout] is not enough on its own, and the gap is not an
/// edge case. A busy timeout only helps when SQLite is willing to WAIT, and
/// it refuses to wait for one specific conflict: a connection that already
/// holds a SHARED (read) lock and needs to promote it to RESERVED while
/// another connection holds RESERVED. Waiting there could deadlock, so SQLite
/// returns SQLITE_BUSY immediately without ever consulting the busy handler.
///
/// That conflict is reachable on every open, because `beforeOpen` re-seeds the
/// built-in reference data with read-then-write statements -- `INSERT OR
/// IGNORE INTO service_kinds ... SELECT ...` takes the read lock for its
/// SELECT and then needs the write lock. Measured: it fails in 0ms, not after
/// the 5s timeout.
///
/// SQLite's own prescription for that case is for the caller to drop its read
/// lock and try again, which is exactly what closing and reopening does. So
/// [attempt] must be self-contained: it has to build its own connection and
/// dispose of it on failure, both because a drift executor caches its
/// migration error and rethrows it forever after, and because the retry only
/// helps if the previous attempt's read lock is gone.
Future<T> retryWhileDatabaseBusy<T>(
  Future<T> Function() attempt, {
  int attempts = kDatabaseBusyOpenAttempts,
  Duration backoff = kDatabaseBusyOpenBackoff,
  Future<void> Function(Duration)? delay,
}) async {
  final sleep = delay ?? (d) => Future<void>.delayed(d);
  for (var tries = 1; ; tries++) {
    try {
      return await attempt();
    } catch (error) {
      if (tries >= attempts || !isDatabaseBusyError(error)) rethrow;
      await sleep(backoff * tries);
    }
  }
}
