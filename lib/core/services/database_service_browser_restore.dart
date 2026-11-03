part of 'database_service.dart';

/// A browser's restore (issue #4121): a backup's bytes become the library.
extension DatabaseServiceBrowserRestore on DatabaseService {
  /// Installs [image] under a new database name, opens it through the
  /// normal open (which runs the upgrade ladder for an older backup), and
  /// only then points the browser's preference at it. Returns the path of
  /// the library it replaced, for [retireWebLibrary]. A failed open, or a
  /// preference the browser refuses to store, puts the previous library
  /// back and removes the image, so nothing is lost and nothing is left for
  /// a launch to sweep up later.
  ///
  /// The caller has checked the backup: a sealed restore, a non-SQLite
  /// file or a newer schema never reaches here. It holds
  /// [SyncCoordinator.joinAcrossTabs] from before this call until
  /// [retireWebLibrary] returns, as Forget this device does, so no tab's
  /// sync runs on the new library before the caller has re-baselined it.
  /// [onMigrationProgress] hears the upgrade ladder of an older backup.
  Future<String> restoreImage(
    Uint8List image, {
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.restore);
    final location = _locationService;
    if (location == null) {
      throw StateError('A browser restore needs the database location');
    }
    final previous = await databasePath;
    final target = webRestoredLibraryPath(DateTime.now());
    await BackgroundDatabaseConnection.installImage(target, image);
    try {
      await _reinitializeAtPath(
        target,
        onMigrationProgress: onMigrationProgress,
      );
      // Inside the rollback: a library the preference does not name is
      // one the next launch sweeps away, with whatever was edited in it.
      await location.setWebLibraryPath(target);
    } catch (_) {
      // Best effort: the error to report is the one that stopped the open.
      try {
        await _reinitializeAtPath(previous);
      } catch (e, stackTrace) {
        _log.error(
          'Could not reopen the library after a failed restore',
          error: e,
          stackTrace: stackTrace,
        );
      }
      await _deleteWebLibrary(target);
      rethrow;
    }
    return previous;
  }

  /// Tells the site's other tabs, which still hold [path] open, to reload
  /// onto the library a restore installed, then deletes [path]. Best effort:
  /// a tab that still holds it keeps it until a later launch sweeps it up.
  Future<void> retireWebLibrary(String path) async {
    BrowserOriginStorage.announceLibraryChanged();
    await _deleteWebLibrary(path);
  }

  Future<void> _deleteWebLibrary(String path) async {
    try {
      await BackgroundDatabaseConnection.deleteStoredDatabases(
        path,
      ).timeout(const Duration(seconds: 5));
    } catch (e, stackTrace) {
      _log.warning(
        'Could not delete the browser library at $path yet',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
