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
      await _refusesWrites(folderPath) ? _cannotWrite : _cannotCompare,
    ),
    FolderIdentity.different => null,
  };

  /// True only when [folderPath] is known not to take new files. A check
  /// that does not answer in time is not a refusal.
  Future<bool> _refusesWrites(String folderPath) async {
    try {
      return !await _withTimeout(
        _locationService.verifyFolderAccessible(folderPath),
        'Folder check',
        timeout: _folderTimeout,
      );
    } on TimeoutException {
      return false;
    }
  }

  /// The refusal for a plain move into [folderPath] when a dive log is
  /// already there, or null when there is none. The folder check found
  /// nothing there, or ran out of time before it could tell (a NAS still
  /// waking, say), so one that is there after all is overwritten only through
  /// Replace, which backs it up first.
  Future<MigrationResult?> _refuseIfOccupied(String folderPath) async {
    try {
      final occupied = await _withTimeout(
        _locationService.databaseExistsAt(folderPath),
        'Folder check',
        timeout: _folderTimeout,
      );
      return occupied ? MigrationResult.failure(_occupied) : null;
    } on TimeoutException {
      return MigrationResult.failure(_unanswered);
    }
  }
}
