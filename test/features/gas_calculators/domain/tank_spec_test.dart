import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

void main() {
  group('TankSpec', () {
    test('AL80 is 11.1 L of water, not 2265 L', () {
      final al80 = TankSpec.fromPreset(TankPresets.al80);
      expect(al80.waterVolumeLiters, closeTo(11.1, 0.01));
      // The old code stored free gas here, which is ~200x larger.
      expect(al80.waterVolumeLiters, lessThan(20));
    });

    test('free gas is water volume times working pressure', () {
      final al80 = TankSpec.fromPreset(TankPresets.al80);
      // 11.1 L * 206.843 bar = 2296 L of free gas at the surface.
      expect(al80.freeGasLiters, closeTo(2296, 5));
      // Which is ~81 cuft, close to the AL80's rated 77.4 (the difference is
      // real gas compressibility, which the ideal-gas figure ignores).
      expect(al80.freeGasLiters * 0.0353147, closeTo(81, 1));
    });

    test('carries the manufacturer rated capacity when the preset has one', () {
      final al80 = TankSpec.fromPreset(TankPresets.al80);
      expect(al80.ratedCapacityCuft, 77.4);

      final steel12 = TankSpec.fromPreset(TankPresets.steel12);
      expect(steel12.ratedCapacityCuft, isNull);
    });

    test('imperial choices are real tanks, not bare numbers', () {
      final choices = imperialTankChoices();
      expect(choices, isNotEmpty);
      for (final t in choices) {
        expect(t.waterVolumeLiters, lessThan(30));
        expect(t.workingPressureBar, greaterThan(150));
      }
    });

    test('imperial choices do not all assume a 200 bar fill', () {
      final pressures = imperialTankChoices()
          .map((t) => t.workingPressureBar)
          .toSet();
      expect(pressures.length, greaterThan(1));
      // The old code hardcoded 200 bar for every imperial tank.
      expect(pressures, isNot(contains(200.0)));
    });

    test('metric choices are present and sane', () {
      final choices = metricTankChoices();
      expect(choices, isNotEmpty);
      for (final t in choices) {
        expect(t.waterVolumeLiters, inInclusiveRange(5, 30));
      }
    });

    test('choices are ascending by capacity so chips read naturally', () {
      for (final choices in [metricTankChoices(), imperialTankChoices()]) {
        final volumes = choices.map((t) => t.waterVolumeLiters).toList();
        final sorted = [...volumes]..sort();
        expect(volumes, sorted);
      }
    });

    test('equal specs compare equal so chip selection works by value', () {
      expect(
        TankSpec.fromPreset(TankPresets.al80),
        TankSpec.fromPreset(TankPresets.al80),
      );
      expect(
        TankSpec.fromPreset(TankPresets.al80),
        isNot(TankSpec.fromPreset(TankPresets.al63)),
      );
    });
  });
}
