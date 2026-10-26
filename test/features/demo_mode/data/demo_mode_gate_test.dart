import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

import '../../../helpers/global_test_defaults.dart';

void main() {
  late Directory support;
  late DemoStateStore store;

  setUp(() {
    support = Directory.systemTemp.createTempSync('demo_gate');
    store = DemoStateStore(DemoPaths(support.path));
  });

  tearDown(() {
    applyGlobalTestDefaults();
    support.deleteSync(recursive: true);
  });

  DemoState stateWith(DemoPhase phase) => DemoState(
    phase: phase,
    fromFirstRun: false,
    enteredAt: DateTime.utc(2026, 10, 26),
  );

  test('gate is active only for active and exiting phases', () async {
    for (final (phase, active) in [
      (DemoPhase.entering, false),
      (DemoPhase.active, true),
      (DemoPhase.exiting, true),
    ]) {
      await store.write(stateWith(phase));
      await DemoModeGate.instance.load(store);
      expect(DemoModeGate.instance.isActive, active, reason: phase.name);
    }
  });

  test('gate is inactive when there is no state', () async {
    DemoModeGate.instance.debugActive = true;

    await DemoModeGate.instance.load(store);

    expect(DemoModeGate.instance.isActive, isFalse);
  });

  test('ensureNotDemo throws DemoModeSealedException with the feature', () {
    DemoModeGate.instance.debugActive = true;

    expect(
      () => DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sync),
      throwsA(
        isA<DemoModeSealedException>().having(
          (e) => e.feature,
          'feature',
          DemoSealedFeature.sync,
        ),
      ),
    );
  });

  test('ensureNotDemo is silent while demo mode is off', () {
    DemoModeGate.instance.debugActive = false;

    expect(
      () => DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sync),
      returnsNormally,
    );
  });

  test('markActive flips the gate', () {
    DemoModeGate.instance.markActive(true);
    expect(DemoModeGate.instance.isActive, isTrue);

    DemoModeGate.instance.markActive(false);
    expect(DemoModeGate.instance.isActive, isFalse);
  });

  test('the harness default leaves the gate off', () {
    DemoModeGate.instance.debugActive = true;

    applyGlobalTestDefaults();

    expect(DemoModeGate.instance.isActive, isFalse);
  });
}
