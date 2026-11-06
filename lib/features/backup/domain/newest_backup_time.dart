import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

/// When this device last made a copy of the library the diver could restore,
/// counting the copy taken before an upgrade (issue #4204).
///
/// The last backup time is set only by backups the diver or the scheduler
/// makes. The copy taken before a schema migration is in history, labelled
/// automatic, yet never set that time, so a diver who upgraded the day after a
/// week without a backup was told the backup was a week old.
///
/// For display only. The scheduler and Data health keep reading the last
/// backup time: an upgrade copy is a local byte copy, so letting it stand in
/// for the next scheduled backup would hold back that backup's cloud or folder
/// copy for a full period.
///
/// A pre-downgrade copy does not count: it holds a schema newer than the
/// build that took it can open.
DateTime? newestBackupTime({
  required DateTime? lastBackupTime,
  required Iterable<BackupRecord> history,
}) {
  var newest = lastBackupTime;
  for (final record in history) {
    if (record.type != BackupType.preMigration) continue;
    if (newest == null || record.timestamp.isAfter(newest)) {
      newest = record.timestamp;
    }
  }
  return newest;
}
