import 'package:flutter/foundation.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

/// The process-wide answer to "is the sample logbook open?".
///
/// Sealed engine methods (sync, backup, restore, import, export, database
/// file operations) call [ensureNotDemo] first, so a sealed feature refuses
/// to run whichever screen, timer or background task reaches it. The gate is
/// a plain synchronous flag so it can be checked anywhere, including the
/// background isolate, which loads it from the persisted state.
class DemoModeGate {
  DemoModeGate._();

  static final DemoModeGate instance = DemoModeGate._();

  bool _active = false;

  bool get isActive => _active;

  /// Sets the gate from the persisted state. Demo mode counts as active while
  /// the demo database is open ([DemoPhase.active]) and while leaving it
  /// ([DemoPhase.exiting]); during [DemoPhase.entering] the user's own
  /// database is still the open one.
  Future<void> load(DemoStateStore store) async {
    final state = await store.read();
    _active =
        state != null &&
        (state.phase == DemoPhase.active || state.phase == DemoPhase.exiting);
  }

  void markActive(bool value) => _active = value;

  /// Throws [DemoModeSealedException] for [feature] while demo mode is active.
  void ensureNotDemo(DemoSealedFeature feature) {
    if (_active) throw DemoModeSealedException(feature);
  }

  /// Test hook. `applyGlobalTestDefaults()` sets it back to false, and the
  /// global state scan requires a test that assigns it to restore it.
  @visibleForTesting
  set debugActive(bool value) => _active = value;
}
