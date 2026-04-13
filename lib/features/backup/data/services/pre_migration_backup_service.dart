import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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
  final BackupPreferences _preferences;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final _log = LoggerService.forClass(PreMigrationBackupService);

  PreMigrationBackupService({
    required AsyncPathResolver livePathProvider,
    required AsyncPathResolver backupsDirProvider,
    required BackupPreferences preferences,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _livePathProvider = livePathProvider,
       _backupsDirProvider = backupsDirProvider,
       _preferences = preferences,
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? (() => const Uuid().v4());

  Future<void> backupIfMigrationPending({
    required int stored,
    required int target,
    required String appVersion,
  }) async {
    if (stored >= target) return;

    late final String livePath;
    late final String backupsDir;
    try {
      livePath = await _livePathProvider();
      if (!await File(livePath).exists()) return;

      backupsDir = await _backupsDirProvider();
      await Directory(backupsDir).create(recursive: true);
    } on BackupFailedException {
      rethrow;
    } catch (e, stack) {
      throw BackupFailedException.fromError(e, stack);
    }

    await _sweepTempFiles(backupsDir);

    final now = _clock().toUtc();
    final ts = _formatTimestamp(now);
    final filename = '$ts-v$stored-v$target.db';
    final tempPath = p.join(backupsDir, '.$filename.tmp');
    final finalPath = p.join(backupsDir, filename);

    try {
      await File(livePath).copy(tempPath);
      await File(tempPath).rename(finalPath);
    } catch (e, stack) {
      await _safeDelete(tempPath);
      throw BackupFailedException.fromError(e, stack);
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
