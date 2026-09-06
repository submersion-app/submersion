import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/live_database_copier.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

/// Preserves a newer-schema database before an older build restores over it.
///
/// The mirror image of [PreMigrationBackupService]. That one saves the file
/// an upgrade is about to change; this one saves the file a DOWNGRADE restore
/// is about to displace (issue #1589).
///
/// It exists because `DatabaseService.restore` deletes its `.pre-restore`
/// copy once the swap succeeds. Without this, accepting the restore offered
/// by the schema-mismatch screen would be the moment every dive logged in the
/// newer build stopped existing. With it, that database becomes an ordinary
/// entry in the backup list which the newer build can open again.
///
/// Two properties follow from the file being unopenable by the build taking
/// the copy:
///
/// - The copy is `pinned`, so no retention path ever prunes it. That includes
///   an older build's manual retention, which is where the record lands after
///   `BackupRecord._parseType` fails to recognise [BackupType.preDowngrade].
/// - [BackupRecord.fromSchemaVersion] records the schema the copy holds, so
///   `downgradeRestoreCandidates` correctly refuses to offer it back on a
///   later mismatch: this build still cannot open it.
class PreDowngradeBackupService {
  final AsyncPathResolver _livePathProvider;
  final AsyncPathResolver _backupsDirProvider;
  final AsyncPathResolver? _fallbackBackupsDirProvider;
  final BackupPreferences _preferences;

  /// The live database's SQLCipher key when protection is on, else null.
  /// Only used to take the database out of WAL before the copy.
  final String? Function()? _databaseKeyHexProvider;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  /// Reads the size of the copy on disk. Injectable so a test can drive the
  /// stat failure below, which no real filesystem offers on demand.
  final Future<int> Function(String path) _sizeReader;
  final _log = LoggerService.forClass(PreDowngradeBackupService);

  PreDowngradeBackupService({
    required AsyncPathResolver livePathProvider,
    required AsyncPathResolver backupsDirProvider,
    AsyncPathResolver? fallbackBackupsDirProvider,
    required BackupPreferences preferences,
    String? Function()? databaseKeyHexProvider,
    DateTime Function()? clock,
    String Function()? idGenerator,
    Future<int> Function(String path)? sizeReader,
  }) : _livePathProvider = livePathProvider,
       _backupsDirProvider = backupsDirProvider,
       _fallbackBackupsDirProvider = fallbackBackupsDirProvider,
       _preferences = preferences,
       _databaseKeyHexProvider = databaseKeyHexProvider,
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? (() => const Uuid().v4()),
       _sizeReader = sizeReader ?? ((path) => File(path).length());

  /// Copies the live database aside and registers it, returning the record.
  ///
  /// Throws [BackupFailedException] if the copy cannot be made. That throw is
  /// load-bearing: the caller must abandon the restore rather than proceed,
  /// because proceeding is what would destroy the newer database. Failing
  /// here costs the diver nothing they had a moment ago.
  Future<BackupRecord> preserve({
    required int storedSchemaVersion,
    required String appVersion,
  }) async {
    final String livePath;
    try {
      livePath = await _livePathProvider();
    } catch (e, stack) {
      throw BackupFailedException.fromError(e, stack);
    }

    if (!await File(livePath).exists()) {
      // Nothing on disk to preserve. Reported as a failure rather than
      // silently skipped: the caller is about to restore over this path, and
      // a missing live database means its picture of the world is wrong.
      throw BackupFailedException.fromError(
        FileSystemException('No database to preserve', livePath),
        StackTrace.current,
      );
    }

    await LiveDatabaseCopier.settleJournalMode(
      livePath,
      keyHex: _databaseKeyHexProvider?.call(),
    );

    final now = _clock().toUtc();
    final filename =
        '${LiveDatabaseCopier.formatTimestamp(now)}-v$storedSchemaVersion'
        '-newer.db';

    final finalPath = await _copyAside(livePath, filename);

    return _registerCopy(
      finalPath,
      filename: filename,
      now: now,
      storedSchemaVersion: storedSchemaVersion,
      appVersion: appVersion,
    );
  }

  /// Copies into the diver's configured backups location, falling back to the
  /// app's default one when that location is unusable (an ejected volume, a
  /// lost iCloud write scope). Every failure surfaces as a
  /// [BackupFailedException] so the caller has one thing to catch.
  Future<String> _copyAside(String livePath, String filename) async {
    try {
      return await LiveDatabaseCopier.copyInto(
        _backupsDirProvider,
        livePath,
        filename,
      );
    } catch (preferredError, preferredStack) {
      final fallbackProvider = _fallbackBackupsDirProvider;
      if (fallbackProvider == null) {
        if (preferredError is BackupFailedException) rethrow;
        throw BackupFailedException.fromError(preferredError, preferredStack);
      }
      _log.warning(
        'Preferred backups location is unusable; falling back to the default '
        'app location to preserve the newer database.',
        error: preferredError,
        stackTrace: preferredStack,
      );
      try {
        return await LiveDatabaseCopier.copyInto(
          fallbackProvider,
          livePath,
          filename,
        );
      } catch (e, stack) {
        if (e is BackupFailedException) rethrow;
        throw BackupFailedException.fromError(e, stack);
      }
    }
  }

  Future<BackupRecord> _registerCopy(
    String finalPath, {
    required String filename,
    required DateTime now,
    required int storedSchemaVersion,
    required String appVersion,
  }) async {
    // Everything past this point is bookkeeping about a copy that already
    // exists. Nothing here may throw: the bytes are safe, and the caller is
    // holding a restore open waiting on this. See the sibling reasoning on
    // the registration failure below.
    //
    // Deliberately unlike PreMigrationBackupService, which throws on the same
    // stat. There the throw blocks an UPGRADE, and refusing to migrate
    // without a confirmed safety copy is the conservative direction. Here it
    // would block a RESTORE and strand the diver on the mismatch screen next
    // to a copy that is already on disk.
    // Recorded as 0, which the backup list renders as "0 B" via
    // BackupRecord.formattedSize. Named here rather than left implicit: 0 is
    // the only value the non-nullable field can carry for "not measured", so
    // the size shown against this record can be wrong while the record itself
    // is correct, and this log line is what explains that to whoever chases
    // it. Adding a nullable sentinel would change the persisted shape of
    // every BackupRecord for a diagnostic edge case.
    var sizeBytes = 0;
    try {
      sizeBytes = await _sizeReader(finalPath);
    } catch (e, stack) {
      _log.warning(
        'Could not read the size of the preserved newer database at '
        '$finalPath; recording it as 0 bytes, which the backup list shows as '
        '"0 B". The copy itself is intact.',
        error: e,
        stackTrace: stack,
      );
    }

    final record = BackupRecord(
      id: _idGenerator(),
      filename: filename,
      timestamp: now,
      sizeBytes: sizeBytes,
      location: BackupLocation.local,
      localPath: finalPath,
      isAutomatic: true,
      type: BackupType.preDowngrade,
      appVersion: appVersion,
      fromSchemaVersion: storedSchemaVersion,
      pinned: true,
    );

    try {
      await _preferences.addRecord(record);
    } catch (e, stack) {
      // The bytes are what matter and they are already on disk. An
      // unregistered copy is recoverable by hand from the backups folder,
      // whereas failing the restore here would leave the diver stuck on the
      // mismatch screen with a copy they cannot see.
      _log.warning(
        'Could not register the preserved newer database; the .db is on disk '
        'at $finalPath',
        error: e,
        stackTrace: stack,
      );
    }
    return record;
  }
}
