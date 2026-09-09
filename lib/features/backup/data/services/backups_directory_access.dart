import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';

/// Holds the backups directory open for the length of one operation.
///
/// Slice A's [backupsPathToMeasure] answers a narrower question: which path to
/// measure, once. Listing files and then deleting some of them needs the
/// directory reachable for the whole sequence, and on Apple platforms a custom
/// location is reachable only while its security-scoped bookmark lease is held.
/// A lease that outlives the work leaks a scoped resource, so the release is in
/// a `finally` rather than after the body.
///
/// The two callbacks are injected because the alternative is a test that needs
/// SharedPreferences and a native bookmark channel to assert something as small
/// as "a content:// location takes no lease".
class BackupsDirectoryAccess {
  BackupsDirectoryAccess({
    required Future<String?> Function() configuredLocation,
    required Future<BackupDirLease> Function() acquireLease,
  }) : _configuredLocation = configuredLocation,
       _acquireLease = acquireLease;

  /// Wired to the live preferences and the leased resolver.
  factory BackupsDirectoryAccess.live(BackupPreferences preferences) =>
      BackupsDirectoryAccess(
        configuredLocation: () async =>
            preferences.getSettings().backupLocation,
        acquireLease: () =>
            BackupService.resolveBackupsDirectoryLeased(preferences),
      );

  final Future<String?> Function() _configuredLocation;
  final Future<BackupDirLease> Function() _acquireLease;

  /// Runs [body] with a directory `dart:io` can list, or null when there is
  /// none.
  ///
  /// Null rather than the sandbox default for a SAF location, deliberately.
  /// `resolveBackupsDirectoryLeased` substitutes the default there because its
  /// caller needs somewhere writable, but this caller is looking for files the
  /// backup history has lost track of, and the sandbox default is not where a
  /// SAF-configured device keeps its backups. Scanning it would offer a
  /// different directory's files for deletion under a heading about this one.
  Future<T> use<T>(Future<T> Function(String? directoryPath) body) async {
    final configured = await _configuredLocation();
    if (configured != null && configured.isNotEmpty && isSafRef(configured)) {
      return body(null);
    }

    final lease = await _acquireLease();
    try {
      return await body(lease.path);
    } finally {
      await lease.release();
    }
  }
}
