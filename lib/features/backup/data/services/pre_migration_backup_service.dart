import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

typedef AsyncPathResolver = Future<String> Function();

/// Copies the live sqlite database before Drift runs a schema migration.
///
/// Operates on the closed database file. Registers the copy via the
/// existing BackupPreferences registry so it appears alongside manual
/// backups in the backup list UI.
class PreMigrationBackupService {
  static const int _retainN = 3;
  final AsyncPathResolver _livePathProvider;
  final AsyncPathResolver _backupsDirProvider;
  final AsyncPathResolver? _fallbackBackupsDirProvider;
  final BackupPreferences _preferences;

  /// The live database's SQLCipher key when protection is on, else null.
  /// Only used to open the database for the pre-copy journal-mode settle.
  final String? Function()? _databaseKeyHexProvider;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final _log = LoggerService.forClass(PreMigrationBackupService);

  PreMigrationBackupService({
    required AsyncPathResolver livePathProvider,
    required AsyncPathResolver backupsDirProvider,
    AsyncPathResolver? fallbackBackupsDirProvider,
    required BackupPreferences preferences,
    String? Function()? databaseKeyHexProvider,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _livePathProvider = livePathProvider,
       _backupsDirProvider = backupsDirProvider,
       _fallbackBackupsDirProvider = fallbackBackupsDirProvider,
       _preferences = preferences,
       _databaseKeyHexProvider = databaseKeyHexProvider,
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? (() => const Uuid().v4());

  Future<void> backupIfMigrationPending({
    required int stored,
    required int target,
    required String appVersion,
  }) async {
    if (stored >= target) return;

    late final String livePath;
    try {
      livePath = await _livePathProvider();
      if (!await File(livePath).exists()) return;
    } catch (e, stack) {
      throw BackupFailedException.fromError(e, stack);
    }

    await _settleJournalMode(livePath);

    final now = _clock().toUtc();
    final filename = '${_formatTimestamp(now)}-v$stored-v$target.db';

    late final String finalPath;
    try {
      finalPath = await _backupInto(_backupsDirProvider, livePath, filename);
    } catch (preferredError, preferredStack) {
      final fallbackProvider = _fallbackBackupsDirProvider;
      if (fallbackProvider == null) {
        if (preferredError is BackupFailedException) rethrow;
        throw BackupFailedException.fromError(preferredError, preferredStack);
      }
      _log.warning(
        'Preferred backups location is unusable; falling back to the default '
        'app location for the pre-migration backup.',
        error: preferredError,
        stackTrace: preferredStack,
      );
      try {
        finalPath = await _backupInto(fallbackProvider, livePath, filename);
      } catch (e, stack) {
        if (e is BackupFailedException) rethrow;
        throw BackupFailedException.fromError(e, stack);
      }
    }

    late final int sizeBytes;
    try {
      sizeBytes = await File(finalPath).length();
    } catch (e, stack) {
      throw BackupFailedException.fromError(e, stack);
    }

    try {
      await _preferences.addRecord(
        BackupRecord(
          id: _idGenerator(),
          filename: filename,
          timestamp: now,
          sizeBytes: sizeBytes,
          location: BackupLocation.local,
          localPath: finalPath,
          isAutomatic: true,
          type: BackupType.preMigration,
          appVersion: appVersion,
          fromSchemaVersion: stored,
          toSchemaVersion: target,
        ),
      );
    } catch (e, stack) {
      _log.warning(
        'Pre-migration backup registration failed; .db is on disk at $finalPath',
        error: e,
        stackTrace: stack,
      );
      return;
    }

    try {
      await _pruneExcess();
    } catch (e, stack) {
      _log.warning(
        'Pre-migration prune failed (backup kept)',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Takes the closed database out of WAL so the byte copy below is a
  /// complete, self-contained snapshot of what the migration is about to
  /// touch.
  ///
  /// A SQLite database is not one file. In WAL mode committed transactions
  /// live in `<db>-wal` until a checkpoint folds them back, and a crash or
  /// force-kill leaves them there; the migration replays them when it opens
  /// the database, so a copy of `<db>` alone is missing the tail of the user's
  /// data: precisely the data a safety copy exists to protect. Copying the
  /// sidecar alongside would not help: `DatabaseService.restore` stages only
  /// the single backup file and deletes the destination's sidecars before the
  /// swap, so a `-wal` next to the backup would never travel.
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
  /// The live database goes straight back to WAL the next time
  /// `applyMainDatabaseSetup` opens it, which on this path is the migration
  /// itself, moments later.
  ///
  /// Best-effort by contract. A database that cannot be opened read-write
  /// (ejected volume, read-only mount, missing or wrong key) still gets its
  /// plain copy: an incomplete safety net beats a bricked startup, and the
  /// migration that follows will surface the real problem itself.
  Future<void> _settleJournalMode(String livePath) async {
    try {
      final db = DatabaseService.openRaw(
        livePath,
        keyHex: _databaseKeyHexProvider?.call(),
      );
      try {
        // Returns one row holding the resulting mode. Anything other than
        // 'delete' means frames may have been left behind, so say so rather
        // than implying a clean snapshot.
        final result = db.select('PRAGMA journal_mode = DELETE');
        final mode = result.isEmpty ? null : result.first.values.first;
        if (mode != 'delete') {
          _log.warning(
            'Could not take the database out of WAL before the pre-migration '
            'backup (mode=$mode); the copy may omit WAL-resident rows',
          );
        }
      } finally {
        db.close();
      }
    } catch (e, stack) {
      _log.warning(
        'Settling the journal mode before the pre-migration backup failed; '
        'copying the database file as-is',
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
  Future<String> _backupInto(
    AsyncPathResolver provider,
    String livePath,
    String filename,
  ) async {
    final dir = await provider();
    await Directory(dir).create(recursive: true);
    await _sweepTempFiles(dir);
    final tempPath = p.join(dir, '.$filename.tmp');
    final finalPath = p.join(dir, filename);
    try {
      await File(livePath).copy(tempPath);
      await File(tempPath).rename(finalPath);
    } catch (e) {
      await _safeDelete(tempPath);
      rethrow;
    }
    return finalPath;
  }

  String _formatTimestamp(DateTime utc) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    final d = utc;
    return '${d.year}${two(d.month)}${two(d.day)}-'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}'
        '${three(d.millisecond)}';
  }

  Future<void> _safeDelete(String path) async {
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

  Future<void> _pruneExcess() async {
    final all = _preferences.getHistory();
    final preMigration = all
        .where((r) => r.type == BackupType.preMigration)
        .toList();
    final unpinned = preMigration.where((r) => !r.pinned).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (unpinned.length <= _retainN) return;
    final toDelete = unpinned.sublist(_retainN);
    for (final record in toDelete) {
      final path = record.localPath;
      if (path != null) {
        await _safeDelete(path);
      }
      await _preferences.removeRecord(record.id);
    }
  }

  Future<void> _sweepTempFiles(String backupsDir) async {
    try {
      final dir = Directory(backupsDir);
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.') && name.endsWith('.db.tmp')) {
          await _safeDelete(entity.path);
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
