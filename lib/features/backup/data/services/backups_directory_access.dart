import 'package:submersion/core/platform/host_platform.dart';
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
    bool defaultIsAppPrivate = false,
  }) : _configuredLocation = configuredLocation,
       _acquireLease = acquireLease,
       _defaultIsAppPrivate = defaultIsAppPrivate;

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
    // The default folder is the app's documents directory. On Android and
    // iOS that is sandboxed: no file manager reaches it (iOS does not opt in
    // to Files sharing) and no other device or sync client can write to it.
    // On desktop the user can browse it and a sync client can mirror it, so
    // it is treated like any folder the diver picked.
    defaultIsAppPrivate: HostPlatform.isMobile,
  );

  final Future<String?> Function() _configuredLocation;
  final Future<BackupDirLease> Function() _acquireLease;
  final bool _defaultIsAppPrivate;

  /// Runs [body] with a directory `dart:io` can list, or null when there is
  /// none.
  ///
  /// Null rather than the sandbox default for a SAF location, deliberately.
  /// `resolveBackupsDirectoryLeased` substitutes the default there because its
  /// caller needs somewhere writable, but this caller is looking for files the
  /// backup history has lost track of, and the sandbox default is not where a
  /// SAF-configured device keeps its backups. Scanning it would offer a
  /// different directory's files for deletion under a heading about this one.
  ///
  /// Path only. A caller that deletes, or decides what may be deleted, must use
  /// [useFolder] instead, so that it sees whether the folder is private to the
  /// app rather than assuming either answer.
  Future<T> use<T>(Future<T> Function(String? directoryPath) body) =>
      useFolder((folder) => body(folder?.path));

  /// [use], with the verdict on whether the folder is private to this app.
  ///
  /// Decided within the same operation that chose the path, so a diver
  /// switching to a custom folder between a listing and a delete gets a delete
  /// judged by the new folder.
  ///
  /// Only the default folder on a sandboxed platform is private. Anything the
  /// diver chose may be synced or shared, whatever platform it is on.
  Future<T> useFolder<T>(Future<T> Function(BackupsFolder? folder) body) async {
    final configured = await _configuredLocation();
    final isCustom = _isSet(configured);
    if (isCustom && isSafRef(configured!)) return body(null);

    final lease = await _acquireLease();
    try {
      // The lease reads the location again on its own, so a change landing
      // between the two reads could pair a custom path with the default's
      // verdict. Reading once more after the lease brackets that read: the
      // folder counts as private only when the location was the default both
      // before and after the lease chose its path.
      final stillDefault = !isCustom && !_isSet(await _configuredLocation());
      return await body(
        BackupsFolder(
          path: lease.path,
          isAppPrivate: stillDefault && _defaultIsAppPrivate,
        ),
      );
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

  /// Whether [location] names a custom folder rather than the default.
  static bool _isSet(String? location) =>
      location != null && location.isNotEmpty;
}

/// The backups directory as one operation sees it.
class BackupsFolder {
  const BackupsFolder({required this.path, required this.isAppPrivate});

  final String path;

  /// True when only this app on this device can have put files here: the
  /// default folder inside an Android or iOS sandbox.
  ///
  /// A backup from "another device" in such a folder cannot be anyone else's
  /// copy. It is this device under an earlier identity, typically a reinstall
  /// whose restored app data kept the files but not the device id, and the
  /// diver has no other way to remove it.
  final bool isAppPrivate;
}
