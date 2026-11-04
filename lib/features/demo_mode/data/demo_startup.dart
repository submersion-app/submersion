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

  static Future<void> _finishExit(
    DemoStateStore store,
    SharedPreferences prefs,
  ) async {
    try {
      await store.restorePrefs(prefs);
    } on StateError catch (e) {
      _log.warning('Demo mode preferences could not be restored: $e');
    }
    await store.deleteAll();
  }
}
