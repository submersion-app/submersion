import 'package:flutter/foundation.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// The process-wide answer to "is the sample logbook open?".
///
/// Sealed engine methods (sync, backup, restore, import, export, database
/// file operations) call [ensureNotDemo] first, so a sealed feature refuses
/// to run whichever screen, timer or background task reaches it. The gate is
/// a plain synchronous flag so it can be checked anywhere. Startup sets it
/// from the persisted state (`DemoStartup`) and `DemoModeService` while
/// entering and leaving; background work checks the demo directory instead.
class DemoModeGate {
  DemoModeGate._();

  static final DemoModeGate instance = DemoModeGate._();

  bool _active = false;

  bool get isActive => _active;

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
