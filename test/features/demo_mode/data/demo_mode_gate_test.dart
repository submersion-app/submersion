import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

import '../../../helpers/global_test_defaults.dart';

void main() {
  tearDown(applyGlobalTestDefaults);

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
