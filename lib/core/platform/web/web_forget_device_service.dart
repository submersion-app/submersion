import 'package:submersion/core/platform/cross_tab_lock.dart';
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
    required this.removeStorageEntry,
    required this.reload,
  });

  static const _log = LoggerService('WebForgetDevice');

  /// The origin private file system entries the app owns: drift's database
  /// directory and the sync temp files.
  static const List<String> storageEntries = [
    'drift_db',
    'submersion-sync-tmp',
  ];

  final Future<void> Function() disableSync;
  final Future<void> Function() clearSecureStorage;
  final Future<void> Function() clearPreferences;
  final Future<void> Function() closeDatabase;
  final Future<void> Function(String name) removeStorageEntry;
  final void Function() reload;

  Future<void> forget() =>
      SyncCoordinator.join(() => withCrossTabLock(kSyncCrossTabLock, _wipe));

  /// Every step runs whatever the ones before it did: a step that fails
  /// (a database still busy, say) must not leave the rest in place, and
  /// the reload drops whatever was still open.
  Future<void> _wipe() async {
    await _step('disable sync', disableSync);
    await _step('clear secure storage', clearSecureStorage);
    await _step('clear preferences', clearPreferences);
    await _step('close database', closeDatabase);
    for (final name in storageEntries) {
      await _step('remove $name', () => removeStorageEntry(name));
    }
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
