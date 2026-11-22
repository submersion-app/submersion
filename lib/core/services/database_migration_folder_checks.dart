part of 'database_migration_service.dart';

// What [DatabaseMigrationService] checks about a folder before it opens or
// copies a dive log there, and the refusals it gives (issue #4834).

const String _alreadyHere = 'Database is already at this location';
const String _cannotCompare =
    'Could not tell whether the selected folder is the one the database is '
    'already in, so nothing was changed. Check that both folders can be '
    'reached and try again.';
const String _cannotCompareDefault =
    "Could not tell whether the app's default folder is the one the "
    'database is already in, so nothing was changed. Check that the current '
    'folder can be reached and try again.';
const String _cannotWrite =
    'Cannot write to the selected folder. Please check permissions.';
const String _occupied =
    'There is already a dive log in the selected folder, so nothing was '
    'changed. Choose the folder again to use that dive log or replace it.';
const String _unanswered =
    'The selected folder did not answer in time, so nothing was changed. '
    'Check that it can be reached and try again.';
const String _cannotCheck =
    'Could not check whether the selected folder already holds a dive log, so '
    'nothing was changed. Check that it can be reached and try again.';

extension _FolderChecks on DatabaseMigrationService {
  /// Whether [folderPath] is the folder the open database lives in, under
  /// any name (see [compareFolders]). Nothing may open or copy the live file
  /// through a second name for it, so callers about to do either treat
  /// [FolderIdentity.unknown] as a refusal.
  Future<FolderIdentity> _compareToCurrent(
    String currentPath,
    String folderPath,
  ) => compareFolders(
    p.dirname(currentPath),
    folderPath,
    timeout: _folderTimeout,
  );

  /// The refusal for a move or copy into [folderPath], or null when it is
  /// safe to go ahead because the folder is certainly another one.
  Future<MigrationResult?> _refuseUnlessElsewhere(
    String currentPath,
    String folderPath,
  ) async => switch (await _compareToCurrent(currentPath, folderPath)) {
    FolderIdentity.same => MigrationResult.failure(_alreadyHere),
    // Often just a folder this app may not write to, which the diver can fix
    FolderIdentity.unknown => MigrationResult.failure(
      await _writeCheck(folderPath) == false ? _cannotWrite : _cannotCompare,
    ),
    FolderIdentity.different => null,
  };

  /// Whether [folderPath] takes new files, or null when the check does not
  /// answer in time, which is not a refusal.
  Future<bool?> _writeCheck(String folderPath) async {
    try {
      return await _withTimeout(
        _locationService.verifyFolderAccessible(folderPath),
        'Folder check',
        timeout: _folderTimeout,
      );
    } on TimeoutException {
      return null;
    }
  }

  /// The refusal for a move into [folderPath] that the app cannot write to,
  /// or that does not answer in time, or null when it takes new files. A
  /// share can answer the identity probe and then stall here, so this is
  /// bounded too.
  Future<MigrationResult?> _refuseUnlessWritable(String folderPath) async =>
      switch (await _writeCheck(folderPath)) {
        true => null,
        false => MigrationResult.failure(_cannotWrite),
        null => MigrationResult.failure(_unanswered),
      };

  /// The refusal for a plain move into [folderPath] when a dive log is
  /// already there or it cannot be told, or null when there is certainly
  /// none. The folder check found nothing there, or ran out of time before
  /// it could tell (a NAS still waking, say), so one that is there after all
  /// is overwritten only through Replace, which backs it up first.
  Future<MigrationResult?> _refuseIfOccupied(String folderPath) async =>
      switch (await _holdsDiveLog(folderPath)) {
        true => MigrationResult.failure(_occupied),
        false => null,
        null => MigrationResult.failure(_cannotCheck),
      };

  /// Readies a Replace into [folderPath]: the refusal when it cannot go
  /// ahead, or null once the dive log there is backed up (or there is none).
  /// The write check comes first, as the backup writes there too. The backup
  /// is the only way back from the overwrite, so a look-up that fails or
  /// stalls refuses rather than read as "nothing to back up".
  Future<MigrationResult?> _backUpBeforeReplacing(String folderPath) async {
    final unwritable = await _refuseUnlessWritable(folderPath);
    if (unwritable != null) return unwritable;
    final holds = await _holdsDiveLog(folderPath);
    if (holds == null) return MigrationResult.failure(_cannotCheck);
    if (holds) {
      // Through _createBackup so the copy carries the target's `-wal`: that
      // file is not ours and may well have been left with an uncheckpointed
      // sidecar.
      await _createBackup(
        p.join(folderPath, DatabaseLocationService.databaseFilename),
      );
    }
    return null;
  }

  /// Whether a dive log is in [folderPath], or null when the look-up fails
  /// or does not answer in time: not "nothing there", since one may be
  /// behind the error.
  Future<bool?> _holdsDiveLog(String folderPath) async {
    try {
      return await _withTimeout(
        _locationService.databaseExistsAt(folderPath),
        'Folder check',
        timeout: _folderTimeout,
      );
    } on TimeoutException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}
