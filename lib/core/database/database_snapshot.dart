import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database_connection_setup.dart';

/// Writes a consistent copy of one database file to another path. Test seam
/// for the callers that need to drive a failure; [vacuumIntoSnapshot] is the
/// real implementation.
typedef DatabaseSnapshotter =
    Future<void> Function({
      required String sourcePath,
      required String targetPath,
    });

/// Writes a consistent point-in-time copy of the database at [sourcePath] to
/// [targetPath], which must NOT already exist.
///
/// Goes through a SQLite connection rather than copying bytes, which is what
/// makes it correct in either journal mode. A byte copy takes no read lock and
/// sees only `<db>`, so under WAL it silently omits every committed row still
/// sitting in `<db>-wal`, and under DELETE it can capture a mid-transaction
/// state whose `-journal` sidecar does not travel with it. `VACUUM INTO` runs
/// inside a read transaction and writes a fresh, fully checkpointed,
/// self-contained database instead.
///
/// The result is a single file with no sidecars of its own, which is what
/// every consumer downstream assumes: `DatabaseService.restore` stages only
/// the one backup file and deletes the destination's sidecars before the swap,
/// and `BackupService.validateBackupFile` opens artifacts READ-ONLY, which a
/// WAL-mode file in a read-only picker directory could not satisfy (it would
/// need to create an `-shm` there).
///
/// Safe to run against a LIVE database. It never writes to the source, and
/// under WAL a reader does not block writers, so the app keeps serving during
/// what may be a slow export on a large library. In DELETE mode the read
/// transaction does hold writers off for the duration -- one more reason the
/// journal-mode switch and this belong in the same change.
///
/// Opens `package:sqlite3` directly rather than through
/// `DatabaseService.openRaw` so this file has no import of
/// `database_service.dart`: DatabaseService imports it for `backup`, and the
/// import has to stay one-way.
///
/// Throws if [sourcePath] cannot be opened as a database or the export fails;
/// callers decide what a failure is worth.
Future<void> vacuumIntoSnapshot({
  required String sourcePath,
  required String targetPath,
}) async {
  // readWrite, deliberately, and NOT the readWriteCreate that
  // `sqlite3.open` defaults to.
  //
  // Write, because a database left with a hot rollback journal is only
  // recoverable by a connection that can write and a read-only open would fail
  // outright on it. Same reasoning as
  // DatabaseService.getStoredSchemaVersion.
  //
  // Never create, because the caller checks the source exists and then opens
  // it, so arriving here with the file gone means it vanished in between (an
  // ejected volume, a raced delete). With the default, SQLite would CREATE an
  // empty database at the live path and export that: a backup reporting
  // success while holding nothing, which is the exact silent loss the SQL
  // export exists to prevent.
  final db = sqlite3.sqlite3.open(sourcePath, mode: sqlite3.OpenMode.readWrite);
  try {
    // Before anything else touches a page: the source may be open in another
    // isolate, and without this the first statement to meet a lock fails
    // instantly instead of waiting out the microseconds the holder needs.
    db.execute('PRAGMA busy_timeout = ${kDatabaseBusyTimeout.inMilliseconds}');
    // Single-quote escaped. VACUUM INTO takes a file path, not a bindable
    // parameter, and refuses to overwrite an existing file -- callers stage to
    // a fresh path and rename.
    final escapedTarget = targetPath.replaceAll("'", "''");
    db.execute("VACUUM INTO '$escapedTarget'");
  } finally {
    db.close();
  }
}
