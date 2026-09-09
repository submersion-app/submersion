import 'package:submersion/core/services/backup_bookmark_service.dart';
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

  /// Wired to the live preferences and a resolver that only reads.
  ///
  /// [bookmarks] exists only so a test can exercise the Apple branch without a
  /// native channel, mirroring the seam `resolveBackupsDirectoryLeased` already
  /// offers. Production passes nothing and gets the real port.
  factory BackupsDirectoryAccess.live(
    BackupPreferences preferences, {
    BackupBookmarkPort? bookmarks,
  }) => BackupsDirectoryAccess(
    configuredLocation: () async => preferences.getSettings().backupLocation,
    acquireLease: () => _leaseForReading(preferences, bookmarks: bookmarks),
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

  /// Resolves the backups directory for reading, changing nothing.
  ///
  /// Deliberately NOT `BackupService.resolveBackupsDirectoryLeased`, which
  /// mutates on three paths that are all correct for a writer and all wrong
  /// here. It creates the directory it returns, it creates a missing custom
  /// directory, and it self-heals an unreachable custom location by clearing
  /// it. A backup has to land somewhere, so a writer is right to insist; a scan
  /// that runs whenever the Storage usage page is opened is not.
  ///
  /// The clearing is the one that bites. An unmounted share is unreachable for
  /// as long as it is unmounted, and opening a settings page in that window
  /// would point every future backup at the sandbox instead of the folder the
  /// diver chose, silently and permanently.
  ///
  /// A SAF location never reaches here: [use] returns before taking a lease.
  static Future<BackupDirLease> _leaseForReading(
    BackupPreferences preferences, {
    BackupBookmarkPort? bookmarks,
  }) async {
    final custom = preferences.getSettings().backupLocation;
    if (custom == null || custom.isEmpty) {
      return BackupDirLease(
        await BackupService.defaultBackupsDirectoryPath(),
        _noRelease,
      );
    }
    if (!BackupBookmarkService.isSupported) {
      return BackupDirLease(custom, _noRelease);
    }

    // Apple: the folder is reachable only while its bookmark is armed. A
    // missing or unresolvable bookmark yields the bare path rather than a
    // reset; the listing then finds nothing, which is the honest outcome for a
    // folder this process cannot open.
    final bytes = preferences.getBackupLocationBookmark();
    if (bytes == null) return BackupDirLease(custom, _noRelease);

    final port = bookmarks ?? BackupService.defaultBookmarkPort;
    final lease = await port.resolve(bytes);
    if (lease == null) return BackupDirLease(custom, _noRelease);

    // A stale bookmark is used as resolved and not re-minted: re-minting is a
    // write, and the writer already re-mints it on its own next run.
    return BackupDirLease(lease.path, () => port.release(lease.ref));
  }

  static Future<void> _noRelease() async {}
}
