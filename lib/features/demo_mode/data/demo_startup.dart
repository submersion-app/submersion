import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

final _log = LoggerService.forClass(DemoStartup);

class DemoStartupDecision {
  const DemoStartupDecision(this.demoDatabasePath);

  /// The sample logbook to open, or null to open the user's own logbook.
  final String? demoDatabasePath;
}

/// Decides at launch, before any database opens, whether the app resumes demo
/// mode, and finishes whatever a killed app left half done:
///
/// - **entering**: the entry never finished, so any preferences it changed
///   are restored, the partial demo directory is removed and the user's
///   logbook opens.
/// - **active**: the sample logbook opens again, with the strip showing.
/// - **exiting**: the exit is finished (preferences restored, demo directory
///   removed) and the user's logbook opens.
class DemoStartup {
  DemoStartup._();

  static Future<DemoStartupDecision> resolve({
    required DemoStateStore store,
    required SharedPreferences prefs,
  }) async {
    // The common case, demo mode never used: a synchronous look, so a
    // launch does no async work here (see DemoStateStore.hasAnything).
    if (!store.hasAnything) {
      DemoModeGate.instance.markActive(false);
      return const DemoStartupDecision(null);
    }
    final state = await store.read();
    String? demoPath;
    switch (state?.phase) {
      case null:
        // Demo files with no readable state are debris; clear them.
        await store.deleteAll();
      case DemoPhase.active when await store.hasDatabase():
        demoPath = store.paths.databaseFile;
      case DemoPhase.entering || DemoPhase.active || DemoPhase.exiting:
        await _finishExit(store, prefs);
    }
    DemoModeGate.instance.markActive(demoPath != null);
    return DemoStartupDecision(demoPath);
  }

  /// Leaves demo mode during startup because this build cannot open the
  /// sample logbook, for example one a newer build already upgraded before a
  /// downgrade. The sample is discarded on exit anyway, so nothing is lost,
  /// and the user's own logbook opens in its place.
  ///
  /// The user's preferences go back FIRST, and only then is the state marked
  /// exiting. When they cannot be put back this throws with demo mode on and
  /// the state still active, so the next launch returns to the sample rather
  /// than finishing an exit that would open the user's logbook under the
  /// sample's preferences. A snapshot that cannot be read is the exception,
  /// kept as [resolve] treats it (the preferences stay as they are).
  ///
  /// Past that point nothing stops the exit. A state that cannot be marked or
  /// a directory that cannot be removed is left for the next launch: exiting
  /// finishes there through [resolve], and an active state reopens the
  /// sample, fails the same way and comes back here, where restoring from
  /// the snapshot again changes nothing.
  static Future<void> abandon({
    required DemoStateStore store,
    required SharedPreferences prefs,
  }) async {
    final state = await store.read();
    await _restorePrefs(store, prefs);
    DemoModeGate.instance.markActive(false);
    try {
      if (state != null) {
        await store.write(state.copyWith(phase: DemoPhase.exiting));
      }
    } catch (e) {
      _log.warning('Demo mode state could not be marked exiting: $e');
    }
    try {
      await store.deleteAll();
    } catch (e) {
      _log.warning('Demo mode files are left for the next launch: $e');
    }
  }

  static Future<void> _restorePrefs(
    DemoStateStore store,
    SharedPreferences prefs,
  ) async {
    try {
      await store.restorePrefs(prefs);
    } on StateError catch (e) {
      _log.warning('Demo mode preferences could not be restored: $e');
    }
  }

  static Future<void> _finishExit(
    DemoStateStore store,
    SharedPreferences prefs,
  ) async {
    await _restorePrefs(store, prefs);
    await store.deleteAll();
  }
}
