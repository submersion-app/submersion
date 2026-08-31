import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';

/// A backup file on disk with no record in this device's history.
class UnrecognizedBackup {
  const UnrecognizedBackup({
    required this.path,
    required this.sizeBytes,
    required this.modified,
    required this.ownership,
  });

  final String path;
  final int sizeBytes;
  final DateTime modified;
  final BackupOwnership ownership;

  String get filename => p.basename(path);

  /// Only a file this device provably wrote may be deleted.
  ///
  /// A file from another device may be its only copy, and an unattributed one
  /// predates attribution entirely, so neither can be told apart from a
  /// forgotten local backup by anything but its name.
  bool get isReclaimable => ownership == BackupOwnership.thisDevice;
}

/// Finds backup files the history has lost track of, and reclaims the ones
/// that are provably this device's.
///
/// `pruneOldBackups` and the pre-migration prune both work off the
/// SharedPreferences history, and `getValidatedBackupHistory` drops records
/// whose file has vanished. Nothing removes a file whose record vanished, so a
/// prefs reset, a reinstall over a preserved Documents directory, or a crash
/// between writing the file and recording it leaves a full copy of the
/// database that is invisible to every existing path.
///
/// Listing them is always safe. Deleting them is not: the app tells users to
/// put the backup folder in Dropbox, Nextcloud or Google Drive, where every
/// other device's backups are equally absent from this device's history. That
/// is what [BackupOwnership] is for, and why [reclaim] re-checks rather than
/// trusting its caller.
class OrphanedBackupScan {
  OrphanedBackupScan({
    required Future<String?> Function() backupsDirectory,
    required Future<Set<String>> Function() knownPaths,
    required Future<String> Function() thisDeviceId,
  }) : _backupsDirectory = backupsDirectory,
       _knownPaths = knownPaths,
       _thisDeviceId = thisDeviceId;

  /// Null when the location cannot be enumerated: an Android SAF location is a
  /// content:// tree URI with no Directory behind it.
  final Future<String?> Function() _backupsDirectory;
  final Future<Set<String>> Function() _knownPaths;
  final Future<String> Function() _thisDeviceId;
  final _log = LoggerService.forClass(OrphanedBackupScan);

  static const String _prefix = 'submersion_backup_';

  Future<List<UnrecognizedBackup>> find() async {
    final directoryPath = await _backupsDirectory();
    if (directoryPath == null) return const [];

    final directory = Directory(directoryPath);
    if (!await directory.exists()) return const [];

    final known = await _knownPaths();
    final deviceId = await _thisDeviceId();
    final found = <UnrecognizedBackup>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!_isBackupFile(name)) continue;
      if (known.contains(entity.path)) continue;

      try {
        final stat = await entity.stat();
        found.add(
          UnrecognizedBackup(
            path: entity.path,
            sizeBytes: stat.size,
            modified: stat.modified,
            ownership: classifyBackupFile(
              filename: name,
              thisDeviceId: deviceId,
            ),
          ),
        );
      } on FileSystemException {
        continue;
      }
    }

    found.sort((a, b) => b.modified.compareTo(a.modified));
    return found;
  }

  /// Deletes the reclaimable entries in [candidates], returning bytes freed.
  ///
  /// Re-checks [UnrecognizedBackup.isReclaimable] rather than trusting the
  /// caller. This is the last gate before an irreversible delete of what may
  /// be another device's only backup, and a UI bug upstream must not be able
  /// to reach past it.
  Future<int> reclaim(Iterable<UnrecognizedBackup> candidates) async {
    var bytes = 0;
    for (final candidate in candidates) {
      if (!candidate.isReclaimable) continue;
      try {
        final file = File(candidate.path);
        if (!await file.exists()) continue;
        await file.delete();
        bytes += candidate.sizeBytes;
      } on FileSystemException catch (e) {
        _log.warning('Could not reclaim ${candidate.filename}: $e');
        continue;
      }
    }
    if (bytes > 0) _log.info('Reclaimed $bytes bytes of forgotten backups');
    return bytes;
  }

  /// A backup this app wrote: our prefix, and a plaintext or encrypted
  /// extension. The hidden `.db.tmp` in-progress files are already swept by
  /// the pre-migration service and must not be double-handled here.
  static bool _isBackupFile(String name) {
    if (!name.startsWith(_prefix)) return false;
    if (name.startsWith('.')) return false;
    final extension = p.extension(name);
    return extension == '.db' || extension == BackupCrypto.fileExtension;
  }
}
