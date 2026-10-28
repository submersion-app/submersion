import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/storage/scratch_sweep.dart';

/// Reclaims backup files a restore left in the app temp folder.
///
/// Restoring from a cloud backup or a SAF document copies the whole database
/// to `<temp>/<backup filename>` first. Restores now delete that copy when
/// they finish, but copies made before that change, or by a restore that was
/// killed part way, stay there forever (storage GC design, leak 1).
///
/// Deliberately narrow, like [StorageScratchSweep]: only regular files
/// directly in the temp folder whose names are this app's backup names, and
/// only once they are a day old. The age guard matters because the share
/// sheet's export writes the same names into the same folder.
class RestoreTempSweep {
  RestoreTempSweep({
    required Future<Directory> Function() temporaryDirectory,
    DateTime Function(FileStat stat) touchedAt = lastTouched,
  }) : _temporaryDirectory = temporaryDirectory,
       _touchedAt = touchedAt;

  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function(FileStat stat) _touchedAt;
  final _log = LoggerService.forClass(RestoreTempSweep);

  static const Duration minAge = Duration(hours: 24);

  /// The temp names backups and restores write, each deleted only in a
  /// finally block that a killed app never reaches:
  /// - a backup name (`submersion_backup_...`, plain or encrypted), bare (a
  ///   share-sheet export, an older restore copy) or behind the
  ///   `restore-<uuid>-` restore-copy or `<uuid>-` staging prefix;
  /// - a pre-migration copy (`<yyyyMMdd>-<HHmmssSSS>-v<n>-v<m>.db`) or a
  ///   pre-downgrade copy (`<yyyyMMdd>-<HHmmssSSS>-v<n>-newer.db`), either
  ///   possibly wrapped as `.sbe`, bare (one shared from the history) or
  ///   behind the restore-copy prefix;
  /// - the decrypted plaintext copy of an encrypted backup
  ///   (`restore_<uuid>.db`), and the export and re-encryption copies
  ///   (`export_<uuid>.db`, `reenc_<uuid>.sbe`).
  static final _backupName = RegExp(
    r'^(?:'
    r'(?:restore-)?(?:[0-9a-f-]{36}-)?submersion_backup_.+\.(?:db|sbe)'
    r'|(?:restore-[0-9a-f-]{36}-)?\d{8}-\d{9}-v\d+-(?:v\d+|newer)\.(?:db|sbe)'
    r'|restore_[0-9a-f-]{36}\.db'
    r'|export_[0-9a-f-]{36}\.db'
    r'|reenc_[0-9a-f-]{36}\.sbe'
    r')$',
  );

  /// A [dryRun] counts what the pass would reclaim and deletes nothing.
  Future<ScratchSweepReport> run({DateTime? now, bool dryRun = false}) async {
    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    final temp = await _temporaryDirectory();
    if (!await temp.exists()) return ScratchSweepReport.empty;

    var files = 0;
    var bytes = 0;
    await for (final entity in temp.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!_backupName.hasMatch(name)) continue;
      try {
        final stat = await entity.stat();
        if (!_touchedAt(stat).isBefore(cutoff)) continue;
        if (!dryRun) await entity.delete();
        files++;
        bytes += stat.size;
      } on FileSystemException {
        // Vanished or unreadable: leave it for the next pass.
        continue;
      }
    }
    if (files > 0 && !dryRun) {
      _log.info('Restore temp sweep reclaimed $bytes bytes in $files files');
    }
    return ScratchSweepReport(filesDeleted: files, bytesReclaimed: bytes);
  }
}
