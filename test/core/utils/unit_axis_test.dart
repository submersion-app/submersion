import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

UnitFormatter _metric() => const UnitFormatter(AppSettings());

UnitFormatter _imperial() => const UnitFormatter(
  AppSettings(
    depthUnit: DepthUnit.feet,
    volumeUnit: VolumeUnit.cubicFeet,
    pressureUnit: PressureUnit.psi,
  ),
);

void main() {
  group('UnitAxis.stressedSac', () {
    test('metric exposes the canonical 15-40 L/min range', () {
      final axis = UnitAxis.stressedSac(_metric());
      expect(axis.min, 15);
      expect(axis.max, 40);
      expect(axis.decimals, 0);
      expect(axis.symbol, 'L/min');
    });

    test('imperial snaps to a selectable cuft/min range', () {
      final axis = UnitAxis.stressedSac(_imperial());
      // 15 L/min = 0.53 cuft/min, 40 L/min = 1.41 cuft/min.
      // The old slider offered 15-35 CUFT/min, which is 425-991 L/min.
      expect(axis.min, closeTo(0.55, 1e-9));
      expect(axis.max, closeTo(1.40, 1e-9));
      expect(axis.step, closeTo(0.05, 1e-9));
      expect(axis.decimals, 2);
      expect(axis.symbol, 'cuft/min');
    });

    test('imperial max is nowhere near the old off-scale minimum', () {
      final axis = UnitAxis.stressedSac(_imperial());
      expect(axis.max, lessThan(15.0));
    });

    test('roundtrips canonical -> display -> canonical', () {
      final axis = UnitAxis.stressedSac(_imperial());
      final display = axis.toDisplay(28.3);
      expect(axis.toCanonical(display), closeTo(28.3, 1e-6));
    });

    test('formats imperial with two decimals, not zero', () {
      final axis = UnitAxis.stressedSac(_imperial());
      expect(axis.format(0.75), '0.75');
      expect(UnitAxis.stressedSac(_metric()).format(20), '20');
    });
  });

  group('UnitAxis.ascentRate', () {
    test('metric is 3-18 m/min', () {
      final axis = UnitAxis.ascentRate(_metric());
      expect(axis.min, 3);
      expect(axis.max, 18);
      expect(axis.symbol, 'm/min');
    });

    test('imperial snaps to 10-55 ft/min on a 5 ft grid', () {
      final axis = UnitAxis.ascentRate(_imperial());
      // The old min of 6 m/min converted to 19.7 ft/min, which is what the
      // user saw as a "20 ft/min minimum".
      expect(axis.min, 10);
      expect(axis.max, 55);
      expect(axis.step, 5);
      expect(axis.symbol, 'ft/min');
    });

    test('divisions match the snapped grid', () {
      expect(UnitAxis.ascentRate(_imperial()).divisions, 9);
      expect(UnitAxis.ascentRate(_metric()).divisions, 15);
    });
  });

  group('UnitAxis.depth', () {
    test('imperial snaps to a whole-5ft range inside the canonical bounds', () {
      final axis = UnitAxis.depth(_imperial());
      // 10 m = 32.8 ft -> 35; 50 m = 164 ft -> 160.
      expect(axis.min, 35);
      expect(axis.max, 160);
      expect(axis.step, 5);
    });
  });

  group('clampCanonical', () {
    test('keeps a canonical value inside the display-snapped range', () {
      final axis = UnitAxis.ascentRate(_imperial());
      // 100 m/min is far above the ceiling.
      final clamped = axis.clampCanonical(100);
      expect(axis.toDisplay(clamped), closeTo(axis.max, 1e-6));
    });
  });
}
