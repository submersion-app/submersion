import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/live_database_copier.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

/// Copies the live sqlite database before Drift runs a schema migration.
///
/// Operates on the closed database file. Registers the copy via the
/// existing BackupPreferences registry so it appears alongside manual
/// backups in the backup list UI.
class PreMigrationBackupService {
  /// How many unpinned pre-migration copies survive a prune. Each one is a
  /// full database, so this stays small; see [_pruneExcess] for which of
  /// them are kept.
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

    await LiveDatabaseCopier.settleJournalMode(
      livePath,
      keyHex: _databaseKeyHexProvider?.call(),
    );

    final now = _clock().toUtc();
    final filename =
        '${LiveDatabaseCopier.formatTimestamp(now)}-v$stored-v$target.db';

    late final String finalPath;
    try {
      finalPath = await LiveDatabaseCopier.copyInto(
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
        'app location for the pre-migration backup.',
        error: preferredError,
        stackTrace: preferredStack,
      );
      try {
        finalPath = await LiveDatabaseCopier.copyInto(
          fallbackProvider,
          livePath,
          filename,
        );
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

  /// Keeps [_retainN] pre-migration copies: the recovery floor, plus the
  /// newest of the rest.
  ///
  /// Retention here is not "the last few backups". These copies exist for one
  /// job: to be opened by a build that refuses the live database because the
  /// schema has moved past what that build understands. Only a copy whose
  /// [BackupRecord.fromSchemaVersion] is at or below that build's own version
  /// can do that job, so the single most valuable record is the one with the
  /// LOWEST `fromSchemaVersion` -- and pruning newest-first is precisely the
  /// order that deletes it first. A diver crossing several schema rungs would
  /// otherwise end up holding three copies, none of which the build in front
  /// of them can open, having deleted the one that it could.
  ///
  /// The floor is therefore retained in place of the third-newest rather than
  /// in addition to it: which copies are kept changes, how many does not.
  Future<void> _pruneExcess() async {
    final all = _preferences.getHistory();
    final candidates =
        all
            .where((r) => r.type == BackupType.preMigration && !r.pinned)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (candidates.length <= _retainN) return;

    final keep = <String>{};
    final floor = _recoveryFloor(candidates);
    if (floor != null) keep.add(floor.id);
    for (final record in candidates) {
      if (keep.length >= _retainN) break;
      keep.add(record.id);
    }

    for (final record in candidates) {
      if (keep.contains(record.id)) continue;
      final path = record.localPath;
      if (path != null) {
        await LiveDatabaseCopier.safeDelete(path);
      }
      await _preferences.removeRecord(record.id);
    }
  }

  /// The copy the oldest build could still open: the lowest
  /// [BackupRecord.fromSchemaVersion] among [candidates], ties going to the
  /// newer copy since both open in the same builds and the newer one holds
  /// more of the diver's data.
  ///
  /// A record with no recorded `fromSchemaVersion` was written before the
  /// schema pair existed, so there is nothing to show it opens anywhere; it
  /// never claims the floor slot and competes on recency like any other copy.
  /// Returns null when no candidate records a version, which leaves retention
  /// purely newest-first.
  ///
  /// [candidates] must already be ordered newest-first, which is what makes
  /// the strict `<` below resolve ties toward the newer copy.
  BackupRecord? _recoveryFloor(List<BackupRecord> candidates) {
    BackupRecord? floor;
    for (final record in candidates) {
      final version = record.fromSchemaVersion;
      if (version == null) continue;
      final lowest = floor?.fromSchemaVersion;
      if (lowest == null || version < lowest) floor = record;
    }
    return floor;
  }
}
