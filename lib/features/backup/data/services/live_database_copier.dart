import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

typedef AsyncPathResolver = Future<String> Function();

/// Byte-copies a CLOSED live database into a backups directory.
///
/// Shared by every safety copy startup takes of a database it is about to
/// swap or migrate: the pre-migration copy
/// ([PreMigrationBackupService]) and the copy of a newer-schema database made
/// before a downgrade restore ([PreDowngradeBackupService]). Both run on the
/// same file in the same state (closed, possibly mid-WAL) and need the same
/// three guarantees, so they share one implementation rather than two that
/// can drift.
class LiveDatabaseCopier {
  static final _log = LoggerService.forClass(LiveDatabaseCopier);

  /// Takes the closed database out of WAL so the byte copy below is a
  /// complete, self-contained snapshot.
  ///
  /// A SQLite database is not one file. In WAL mode committed transactions
  /// live in `<db>-wal` until a checkpoint folds them back, and a crash or
  /// force-kill leaves them there, so a copy of `<db>` alone is missing the
  /// tail of the user's data: precisely the data a safety copy exists to
  /// protect. Copying the sidecar alongside would not help:
  /// `DatabaseService.restore` stages only the single backup file and deletes
  /// the destination's sidecars before the swap, so a `-wal` next to the
  /// backup would never travel.
  ///
  /// `journal_mode = DELETE` settles both halves of the problem in one
  /// statement. It checkpoints and removes the `-wal`, AND it clears the WAL
  /// flag from the header -- which a checkpoint alone does not. That second
  /// half matters because the flag is what a byte copy inherits: a WAL-mode
  /// artifact makes SQLite create an `-shm` beside it on the next READ-ONLY
  /// open, which is how `BackupService.validateBackupFile` and the schema
  /// probe read backups, and which fails outright on a file the picker handed
  /// over from a read-only directory.
  ///
  /// Opened through [DatabaseService.openRaw], which is schema-blind: it is
  /// the only way to touch a database whose `user_version` is ahead of this
  /// build, and the downgrade path depends on that.
  ///
  /// Best-effort by contract. A database that cannot be opened read-write
  /// (ejected volume, read-only mount, missing or wrong key) still gets its
  /// plain copy: an incomplete safety net beats a bricked startup.
  static Future<void> settleJournalMode(
    String livePath, {
    String? keyHex,
  }) async {
    try {
      final db = DatabaseService.openRaw(livePath, keyHex: keyHex);
      try {
        // Returns one row holding the resulting mode. Anything other than
        // 'delete' means frames may have been left behind, so say so rather
        // than implying a clean snapshot.
        final result = db.select('PRAGMA journal_mode = DELETE');
        final mode = result.isEmpty ? null : result.first.values.first;
        if (mode != 'delete') {
          _log.warning(
            'Could not take the database out of WAL before copying it '
            '(mode=$mode); the copy may omit WAL-resident rows',
          );
        }
      } finally {
        db.close();
      }
    } catch (e, stack) {
      _log.warning(
        'Settling the journal mode before copying the database failed; '
        'copying the file as-is',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Resolves + creates [provider]'s directory, sweeps stale temp files, and
  /// atomically copies the live DB into it. Returns the final path.
  ///
  /// Wrapping the WHOLE attempt -- not just directory creation -- means an
  /// existing but unwritable preferred location (e.g. an iOS iCloud folder
  /// whose write scope was lost, where create() is a no-op but the copy is
  /// denied) still degrades to the caller's fallback instead of bricking
  /// startup. Throws if any step fails; the caller decides whether to retry.
  static Future<String> copyInto(
    AsyncPathResolver provider,
    String livePath,
    String filename,
  ) async {
    final dir = await provider();
    await Directory(dir).create(recursive: true);
    await sweepTempFiles(dir);
    final tempPath = p.join(dir, '.$filename.tmp');
    final finalPath = p.join(dir, filename);
    try {
      await File(livePath).copy(tempPath);
      await File(tempPath).rename(finalPath);
    } catch (e) {
      await safeDelete(tempPath);
      rethrow;
    }
    return finalPath;
  }

  /// Filename stem shared by every safety copy: `YYYYMMDD-HHMMSSmmm`, UTC at
  /// millisecond resolution.
  ///
  /// Fixed-width throughout, so a lexical sort of the backups directory is
  /// also a chronological one. The milliseconds are what keep two copies
  /// taken within the same second from colliding on a name.
  static String formatTimestamp(DateTime utc) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    final d = utc;
    return '${d.year}${two(d.month)}${two(d.day)}-'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}'
        '${three(d.millisecond)}';
  }

  static Future<void> safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e, stack) {
      _log.warning(
        'Failed to delete backup file at $path (continuing)',
        error: e,
        stackTrace: stack,
      );
    }
  }

  static Future<void> sweepTempFiles(String backupsDir) async {
    try {
      final dir = Directory(backupsDir);
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.') && name.endsWith('.db.tmp')) {
          await safeDelete(entity.path);
        }
      }
    } catch (e, stack) {
      _log.warning(
        'Failed sweeping .tmp files in $backupsDir',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
