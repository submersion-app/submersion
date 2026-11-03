part of 'database_service.dart';

/// A browser's restore (issue #4121): a backup's bytes become the library.
extension DatabaseServiceBrowserRestore on DatabaseService {
  /// Installs [image] under a new database name, opens it through the
  /// normal open (which runs the upgrade ladder for an older backup), and
  /// only then points the browser's preference at it. A failed open puts
  /// the previous library back and removes the image, so nothing is lost
  /// and nothing is left behind. The replaced library is deleted once the
  /// new one is in use; a tab that still holds it keeps it until a later
  /// launch sweeps it up.
  ///
  /// The caller has checked the backup: a sealed restore, a non-SQLite
  /// file or a newer schema never reaches here.
  Future<void> restoreImage(Uint8List image) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.restore);
    return SyncCoordinator.join(() => _restoreImage(image));
  }

  Future<void> _restoreImage(Uint8List image) async {
    final location = _locationService;
    if (location == null) {
      throw StateError('A browser restore needs the database location');
    }
    final previous = await databasePath;
    final target = webRestoredLibraryPath(DateTime.now());
    await BackgroundDatabaseConnection.installImage(target, image);
    try {
      await _reinitializeAtPath(target);
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
    await location.setWebLibraryPath(target);
    // The site's other tabs still hold the old library open.
    BrowserOriginStorage.announceLibraryChanged();
    await _deleteWebLibrary(previous);
  }

  /// Best effort: another tab may hold [path] open, and the launch sweep
  /// removes it later.
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
