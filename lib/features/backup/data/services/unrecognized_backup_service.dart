import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backups_directory_access.dart';
import 'package:submersion/features/backup/data/services/orphaned_backup_scan.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

/// The paths the scan must treat as accounted for.
///
/// Reads the RAW history, deliberately, not
/// `BackupService.getValidatedBackupHistory`. That method drops records whose
/// file is missing and rewrites preferences to match, which is two problems
/// here. A measurement surface must not mutate stored state as a side effect of
/// being opened, the lesson slice A learned when a directory resolver passed by
/// value silently created a Backups folder. And a backups folder on an
/// unmounted share or an unsynced cloud folder is momentarily "missing": pruned
/// there, its files come back with no record, attributable to this device, and
/// this page would offer them for deletion.
///
/// The raw history is a superset of the validated one, so every difference
/// between them can only mean fewer files offered for deletion.
Future<Set<String>> knownPathsFromPreferences(
  BackupPreferences preferences,
) async => knownBackupPaths(preferences.getHistory());

/// The local files [history] still accounts for.
///
/// Everything the scan does hangs off this set being complete: a live backup
/// whose path is missing here is reported as forgotten, and if this device
/// wrote it, offered for deletion. Cloud-only records contribute nothing
/// because they have no file in this directory to account for.
Set<String> knownBackupPaths(Iterable<BackupRecord> history) => {
  for (final record in history) ?record.localPath,
};

/// Runs [OrphanedBackupScan] against the directory the app is actually using.
///
/// The scan takes its inputs as callbacks so it can be tested without
/// SharedPreferences or a sync database. This is where those callbacks are
/// bound to the real sources, and where both operations are wrapped in the
/// directory lease.
///
/// [reclaim] takes the lease even though it deletes by absolute path and has no
/// use for the directory: on Apple platforms a custom location is only
/// reachable while its security-scoped bookmark is held, so deleting outside
/// the lease would fail on exactly the configuration the lease exists for.
class UnrecognizedBackupService {
  UnrecognizedBackupService({
    required BackupsDirectoryAccess access,
    required Future<Set<String>> Function() knownPaths,
    required Future<String> Function() thisDeviceId,
  }) : _access = access,
       _knownPaths = knownPaths,
       _thisDeviceId = thisDeviceId;

  final BackupsDirectoryAccess _access;
  final Future<Set<String>> Function() _knownPaths;
  final Future<String> Function() _thisDeviceId;

  /// The forgotten files, or null when the directory cannot be enumerated.
  ///
  /// Null is not an empty list, the same distinction `StorageCategory.measure`
  /// draws for the same reason: an Android SAF location is a content:// tree
  /// URI with no directory behind it, and reporting it as clean would tell the
  /// user there is nothing to reclaim when nothing was ever looked at.
  Future<List<UnrecognizedBackup>?> find() => _access.use((path) async {
    if (path == null) return null;
    return _scanIn(path).find();
  });

  /// Deletes the reclaimable entries in [selection], returning bytes freed.
  ///
  /// The scan re-checks every entry, so a selection that has gone stale (the
  /// user leaving the page open while a backup runs) cannot delete anything it
  /// was not entitled to delete when it was built.
  Future<int> reclaim(Iterable<UnrecognizedBackup> selection) =>
      _access.use((path) => _scanIn(path).reclaim(selection));

  OrphanedBackupScan _scanIn(String? directoryPath) => OrphanedBackupScan(
    backupsDirectory: () async => directoryPath,
    knownPaths: _knownPaths,
    thisDeviceId: _thisDeviceId,
  );
}
