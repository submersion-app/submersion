import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

/// What a folder turned out to hold when the diver offered it as a dive log.
sealed class FolderInspection {
  const FolderInspection();
}

/// The folder holds no `submersion.db` at all.
class NoDiveLogInFolder extends FolderInspection {
  const NoDiveLogInFolder();
}

/// The folder holds a `submersion.db` that Submersion cannot use: damaged,
/// not a database, or a database belonging to something else.
class UnusableDiveLogInFolder extends FolderInspection {
  const UnusableDiveLogInFolder();
}

/// A readable dive log the app could switch to, with enough of its contents
/// to let the diver recognise it before they commit.
class AdoptableDiveLog extends FolderInspection {
  const AdoptableDiveLog({
    required this.path,
    required this.diveCount,
    required this.siteCount,
    required this.sizeBytes,
    required this.lastModified,
  });

  final String path;
  final int diveCount;
  final int siteCount;
  final int sizeBytes;
  final DateTime lastModified;

  /// The folder the storage config points at, which is what gets adopted.
  String get folderPath => p.dirname(path);
}

/// What a file the diver picked turned out to be.
sealed class BackupFileChoice {
  const BackupFileChoice();
}

/// The file is a backup this screen can swap in.
class RestorableBackupFile extends BackupFileChoice {
  const RestorableBackupFile(this.path);

  final String path;
}

/// The file is an encrypted backup. It cannot be restored from here: the
/// passphrase prompt that unlocks one lives behind the router.
class EncryptedBackupFile extends BackupFileChoice {
  const EncryptedBackupFile();
}

/// The file is not a backup Submersion can use. [reason] is the validator's
/// own words, which name the actual problem better than a paraphrase would.
class UnusableBackupFile extends BackupFileChoice {
  const UnusableBackupFile(this.path, this.reason);

  final String path;
  final String? reason;
}

/// The ways out of the terminal startup screen.
///
/// Everything here runs with NO open database and NO router, because that
/// screen is reached precisely when the database would not open. Settings >
/// Database Storage already offers all three of these operations, and every
/// one of them sits behind the router, behind the database that just failed.
/// Issue #2139 is a diver on a fresh macOS install whose only remaining
/// actions were "show me an empty backups folder" and "quit", while a perfectly
/// good dive log sat in their iCloud Drive folder.
class StartupRecoveryService {
  StartupRecoveryService(this._locationService);

  final DatabaseLocationService _locationService;
  final _log = LoggerService.forClass(StartupRecoveryService);

  /// Tables a file must have before it is treated as a Submersion dive log.
  ///
  /// A plain integrity check is not enough. Any valid SQLite file named
  /// `submersion.db` would pass it, and adopting one hands it to the schema
  /// ladder, which writes Submersion's tables into somebody else's database.
  static const String _diveLogMarkerTable = 'dives';

  /// Describes the dive log in [folderPath], if there is one worth offering.
  ///
  /// Never throws: this runs on a screen the diver reached because something
  /// already went wrong, so every failure has to come back as a result they
  /// can read rather than a second terminal state.
  Future<FolderInspection> inspectFolder(String folderPath) async {
    final dbPath = p.join(folderPath, DatabaseLocationService.databaseFilename);
    final file = File(dbPath);
    if (!await file.exists()) return const NoDiveLogInFolder();

    try {
      final stat = await file.stat();
      final db = DatabaseService.openRaw(
        dbPath,
        keyHex: DatabaseService.instance.databaseKeyHex,
      );
      try {
        if (!_passesIntegrityCheck(db)) return const UnusableDiveLogInFolder();
        if (!_hasTable(db, _diveLogMarkerTable)) {
          return const UnusableDiveLogInFolder();
        }
        return AdoptableDiveLog(
          path: dbPath,
          diveCount: _countRows(db, 'dives'),
          siteCount: _countRows(db, 'dive_sites'),
          sizeBytes: stat.size,
          lastModified: stat.modified,
        );
      } finally {
        db.close();
      }
    } catch (e) {
      _log.warning('Could not read a dive log at $dbPath: $e');
      return const UnusableDiveLogInFolder();
    }
  }

  /// Points the app at [found] for this and every later launch.
  ///
  /// Only an [AdoptableDiveLog] can be passed, so a folder is never adopted
  /// before it has been inspected. Nothing is copied and nothing at the old
  /// location is touched: the file that would not open stays exactly where it
  /// is, which is the whole reason this is safe to offer on a failure screen.
  Future<void> adopt(AdoptableDiveLog found) async {
    await _locationService.saveStorageConfig(
      StorageConfig(
        mode: StorageLocationMode.customFolder,
        customFolderPath: found.folderPath,
        lastVerified: DateTime.now(),
      ),
    );
    // Sandboxed macOS and iOS builds lose access to a picked folder when the
    // process exits. Without this the adoption works once and the next launch
    // fails the same way, one folder further along.
    //
    // Best-effort on purpose, matching how the in-app storage settings treat
    // it. The diver is on a screen whose only other action is to quit, so a
    // bookmark that could not be made must not undo an adoption that lets
    // them back into their dive log now.
    try {
      final bookmarked = await _locationService.createAndStoreBookmark(
        found.folderPath,
      );
      if (!bookmarked) {
        _log.warning(
          'Adopted ${found.folderPath} without a security-scoped bookmark; '
          'the next launch may not be able to reach it',
        );
      }
    } catch (e) {
      _log.warning('Could not bookmark ${found.folderPath}: $e');
    }
  }

  /// Decides what [path] is before anything is swapped in.
  ///
  /// The registry's own records were checked when they were written; a file
  /// the diver picked by hand has never been checked at all, and
  /// `DatabaseService.restore` leaves a file that fails its reopen in place.
  /// So the check has to happen here, before the swap, not after it.
  ///
  /// [prefs] only feeds `BackupPreferences`, which this validation path never
  /// reads; it is required because [BackupService] cannot be built without
  /// one. [validate] is a seam for tests.
  Future<BackupFileChoice> classifyBackupFile(
    String path,
    SharedPreferences prefs, {
    Future<BackupValidationResult> Function(String path)? validate,
  }) async {
    try {
      // Checked first and on its own: an encrypted backup is a VALID artifact
      // that simply cannot be opened here, and reporting it as damaged would
      // send a diver looking for a corruption that does not exist.
      if (await BackupCrypto.isEncryptedBackup(path)) {
        return const EncryptedBackupFile();
      }

      final validator =
          validate ??
          BackupService(
            dbAdapter: DefaultBackupDatabaseAdapter(DatabaseService.instance),
            preferences: BackupPreferences(prefs),
          ).validateBackupFile;
      final result = await validator(path);
      if (!result.isValid) return UnusableBackupFile(path, result.error);
      return RestorableBackupFile(path);
    } catch (e) {
      _log.warning('Could not check the backup file at $path: $e');
      return UnusableBackupFile(path, '$e');
    }
  }

  /// Moves the database that will not open into a folder of its own, so the
  /// next launch creates an empty one beside it.
  ///
  /// Returns the folder the files were moved into.
  ///
  /// A folder rather than a renamed file, because the keyslot sidecar is
  /// named after its DIRECTORY (`submersion.keys`) and not after the database.
  /// Renaming the database alone would strand an encrypted copy with no
  /// durable unlock, and leave the sidecar beside the new empty database where
  /// the startup security gate reads it as an interrupted encryption change.
  ///
  /// Moves, never deletes. This is offered to a diver whose only remaining
  /// choice was to quit, and the file is very often the only copy of their
  /// dive log left: it has to stay recoverable by hand, or by support.
  Future<String> setAsideUnreadableDatabase() async {
    final dbPath = await _locationService.getDatabasePath();
    final destination = await _createSetAsideFolder(p.dirname(dbPath));

    final movedName = p.join(
      destination,
      DatabaseLocationService.databaseFilename,
    );

    // `-journal` belongs here as much as the WAL sidecars do. WAL is not
    // guaranteed: `PRAGMA journal_mode = WAL` can be declined (a network
    // volume, a read-only mount) and `applyMainDatabaseSetup` then leaves the
    // connection in rollback-journal mode. A stale `-journal` left beside the
    // new empty database is replayed against it.
    final moves = <({String from, String to})>[
      (from: dbPath, to: movedName),
      (from: '$dbPath-wal', to: '$movedName-wal'),
      (from: '$dbPath-shm', to: '$movedName-shm'),
      (from: '$dbPath-journal', to: '$movedName-journal'),
      (
        from: DatabaseSecuritySidecar.pathFor(dbPath),
        to: DatabaseSecuritySidecar.pathFor(movedName),
      ),
    ];

    // All or nothing. A half-moved set is worse than not moving at all: the
    // canonical path is empty, so the next launch creates a fresh database,
    // and the diver's artifacts are split across two folders with no way to
    // pair them up again.
    final done = <({String from, String to})>[];
    try {
      for (final move in moves) {
        if (await _moveIfExists(move.from, move.to)) done.add(move);
      }
    } catch (e) {
      _log.warning('Could not set the dive log aside, putting it back: $e');
      await _undoMoves(done);
      await _deleteIfEmpty(destination);
      rethrow;
    }

    _log.info('Set the unreadable dive log aside in $destination');
    return destination;
  }

  /// Returns every file in [done] to where it came from.
  ///
  /// Best-effort per file and deliberately silent: this runs while an error is
  /// already on its way up, and one file that will not go back must not stop
  /// the rest from being restored.
  static Future<void> _undoMoves(List<({String from, String to})> done) async {
    for (final move in done.reversed) {
      try {
        await File(move.to).rename(move.from);
      } catch (_) {
        // Nothing better is available here: the original error is the one
        // worth surfacing, and the files that did go back are still a strict
        // improvement over leaving the set split.
      }
    }
  }

  /// Removes the set-aside folder if nothing ended up in it.
  ///
  /// Guarded on emptiness, never recursive: this path exists to clean up
  /// after a rollback, and must not be capable of deleting a diver's data
  /// however it is reached.
  static Future<void> _deleteIfEmpty(String folder) async {
    try {
      final dir = Directory(folder);
      if (await dir.exists() && await dir.list().isEmpty) await dir.delete();
    } catch (_) {
      // An empty folder left behind is litter, not a failure.
    }
  }

  /// A folder that does not exist yet, named so a diver can tell what is in it.
  ///
  /// The counter matters: two attempts in the same second must not have the
  /// second one move files into the first one's folder, on top of the copy
  /// already there.
  Future<String> _createSetAsideFolder(String parent) async {
    final stamp = _timestamp(DateTime.now());
    for (var attempt = 0; ; attempt++) {
      final suffix = attempt == 0 ? '' : '-$attempt';
      final candidate = p.join(parent, 'unreadable-dive-log-$stamp$suffix');
      if (!await Directory(candidate).exists()) {
        await Directory(candidate).create(recursive: true);
        return candidate;
      }
    }
  }

  static String _timestamp(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// Test seam: makes the move of this exact path throw, so the rollback
  /// above can be proven. Production leaves it null.
  ///
  /// Mirrors `DatabaseService.debugFailDeleteFor`. A seam rather than a real
  /// filesystem failure because the conditions that cause one (a full disk, a
  /// revoked permission mid-operation) cannot be staged from a test.
  @visibleForTesting
  static String? debugFailMoveFor;

  /// Moves [from] to [to], reporting whether there was anything to move.
  static Future<bool> _moveIfExists(String from, String to) async {
    final file = File(from);
    if (!await file.exists()) return false;
    if (from == debugFailMoveFor) {
      throw FileSystemException('Simulated move failure', from);
    }
    await file.rename(to);
    return true;
  }

  /// True when `PRAGMA quick_check` answers a single `ok`.
  ///
  /// `quick_check` rather than `integrity_check`: it skips the index
  /// cross-checks, which is what keeps this fast enough to run while a diver
  /// waits on a failure screen.
  static bool _passesIntegrityCheck(sqlite3.Database db) {
    final result = db.select('PRAGMA quick_check');
    if (result.isEmpty) return false;
    final first = result.first.values;
    if (first.isEmpty) return false;
    return first.first?.toString().toLowerCase() == 'ok';
  }

  static bool _hasTable(sqlite3.Database db, String table) {
    final result = db.select(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return result.isNotEmpty;
  }

  /// Row count for [table], or 0 when this database has no such table.
  ///
  /// An older dive log legitimately lacks tables a current one has, and a
  /// count that cannot be read is not a reason to refuse a database the diver
  /// can plainly see is theirs.
  static int _countRows(sqlite3.Database db, String table) {
    try {
      final result = db.select('SELECT COUNT(*) AS count FROM $table');
      if (result.isEmpty) return 0;
      final value = result.first['count'];
      return value is int ? value : int.tryParse('$value') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
