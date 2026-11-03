import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// Forget this device (issue #4121): everything the browser keeps goes, in
/// an order that leaves no half state. Sync is turned off first so nothing
/// re-pulls, then the secrets and preferences, then the open database is
/// closed and its storage removed, and the page reloads to a fresh start.
///
/// Runs as a sync turn and under the cross-tab lock, so a sync in flight in
/// this tab or another finishes before anything is deleted. The steps are
/// injected: the web glue supplies the real ones, tests supply fakes.
class WebForgetDeviceService {
  const WebForgetDeviceService({
    required this.disableSync,
    required this.clearSecureStorage,
    required this.clearPreferences,
    required this.closeDatabase,
    required this.deleteDatabase,
    required this.removeStorageEntry,
    required this.announce,
    required this.reload,
  });

  static const _log = LoggerService('WebForgetDevice');

  /// The sync temp files' directory in the origin's private file system.
  static const String syncTempEntry = 'submersion-sync-tmp';

  final Future<void> Function() disableSync;
  final Future<void> Function() clearSecureStorage;
  final Future<void> Function() clearPreferences;
  final Future<void> Function() closeDatabase;

  /// Deletes the database wherever drift stored it and throws when a copy
  /// is still there; nothing after it runs then, since a reload over a
  /// surviving logbook would look like nothing happened on the one machine
  /// the user wanted it off.
  final Future<void> Function() deleteDatabase;
  final Future<void> Function(String name) removeStorageEntry;

  /// Tells the site's other tabs, which reload too. They would otherwise
  /// keep the dives and credentials in memory, and a sync from one could
  /// bring the library back. Runs under the cross-tab lock, so a sync
  /// waiting in another tab cannot start before it hears this.
  final void Function() announce;
  final void Function() reload;

  Future<void> forget() => SyncCoordinator.joinAcrossTabs(_wipe);

  /// Every step runs whatever the ones before it did, so a step that fails
  /// (a database still busy, say) does not leave the rest in place; the one
  /// exception is [deleteDatabase], whose failure stops the wipe before the
  /// reload, as it documents.
  Future<void> _wipe() async {
    await _step('disable sync', disableSync);
    await _step('clear secure storage', clearSecureStorage);
    await _step('clear preferences', clearPreferences);
    await _step('close database', closeDatabase);
    await deleteDatabase();
    await _step(
      'remove $syncTempEntry',
      () => removeStorageEntry(syncTempEntry),
    );
    announce();
    reload();
  }

  Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e, stackTrace) {
      _log.warning(
        'Forget this device: $name failed, carrying on',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
