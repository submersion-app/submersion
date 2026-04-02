import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';

void main() {
  group('TankPreset', () {
    group('volumeCuft', () {
      test('returns ratedCapacityCuft when available', () {
        const preset = TankPreset(
          name: 'test',
          displayName: 'Test',
          volumeLiters: 11.1,
          workingPressureBar: 206.843,
          material: TankMaterial.aluminum,
          ratedCapacityCuft: 77.4,
        );
        expect(preset.volumeCuft, 77.4);
      });

      test('calculates from ideal gas law when ratedCapacityCuft is null', () {
        const preset = TankPreset(
          name: 'test',
          displayName: 'Test',
          volumeLiters: 10.0,
          workingPressureBar: 200.0,
          material: TankMaterial.steel,
        );
        // 10.0 * 200.0 / 28.3168 = 70.65
        expect(preset.volumeCuft, closeTo(70.65, 0.1));
      });
    });
  });

  group('TankPresets built-in values', () {
    test('AL80 has correct specs', () {
      const al80 = TankPresets.al80;
      expect(al80.volumeLiters, 11.1);
      expect(al80.workingPressureBar, closeTo(206.843, 0.001));
      expect(al80.ratedCapacityCuft, 77.4);
      expect(al80.volumeCuft, 77.4);
      expect(al80.material, TankMaterial.aluminum);
    });

    test('HP100 has correct specs', () {
      const hp100 = TankPresets.hp100;
      expect(hp100.volumeLiters, 12.9);
      expect(hp100.workingPressureBar, closeTo(237.317, 0.001));
      expect(hp100.ratedCapacityCuft, 100.0);
      expect(hp100.volumeCuft, 100.0);
      expect(hp100.material, TankMaterial.steel);
    });

    test('LP85 has correct specs', () {
      const lp85 = TankPresets.lp85;
      expect(lp85.volumeLiters, 13.0);
      expect(lp85.workingPressureBar, closeTo(182.021, 0.001));
      expect(lp85.ratedCapacityCuft, 85.0);
      expect(lp85.volumeCuft, 85.0);
    });

    test('AL40 has correct volume (350 in3 = 5.7L)', () {
      expect(TankPresets.al40.volumeLiters, 5.7);
      expect(TankPresets.al40.ratedCapacityCuft, 40.0);
    });

    test('metric tanks have no ratedCapacityCuft', () {
      expect(TankPresets.steel10.ratedCapacityCuft, isNull);
      expect(TankPresets.steel12.ratedCapacityCuft, isNull);
      expect(TankPresets.steel15.ratedCapacityCuft, isNull);
    });

    test('metric tanks calculate cuft from ideal gas', () {
      // Steel 12L: 12.0 * 200.0 / 28.3168
      expect(TankPresets.steel12.volumeCuft, closeTo(84.8, 0.1));
    });

    test('byName returns preset', () {
      expect(TankPresets.byName('al80'), isNotNull);
      expect(TankPresets.byName('al80')!.displayName, 'AL80');
    });

    test('byName returns null for unknown', () {
      expect(TankPresets.byName('nonexistent'), isNull);
    });

    test('all presets list contains expected count', () {
      expect(TankPresets.all.length, 12);
    });

    test('US tank pressures convert cleanly to PSI', () {
      // All US tanks should round-trip to their standard PSI values
      const psiConversion = 14.5038;

      // 3000 PSI tanks
      for (final preset in [
        TankPresets.al80,
        TankPresets.al63,
        TankPresets.al40,
        TankPresets.al30Stage,
        TankPresets.al40Stage,
      ]) {
        final psi = (preset.workingPressureBar * psiConversion).round();
        expect(psi, 3000, reason: '${preset.displayName} should be 3000 PSI');
      }

      // 3442 PSI tanks
      for (final preset in [
        TankPresets.hp80,
        TankPresets.hp100,
        TankPresets.hp120,
      ]) {
        final psi = (preset.workingPressureBar * psiConversion).round();
        expect(psi, 3442, reason: '${preset.displayName} should be 3442 PSI');
      }

      // 2640 PSI tank
      final lp85Psi = (TankPresets.lp85.workingPressureBar * psiConversion)
          .round();
      expect(lp85Psi, 2640);
    });
  });

  group('matchBySpecs', () {
    test('matches AL80 by volume and pressure', () {
      // Imported data might have 207 bar (rounded) instead of 206.843
      final match = TankPresets.matchBySpecs(11.1, 207.0);
      expect(match, isNotNull);
      expect(match!.name, 'al80');
      expect(match.ratedCapacityCuft, 77.4);
    });

    test('matches HP100 by volume and pressure', () {
      final match = TankPresets.matchBySpecs(12.9, 237.0);
      expect(match, isNotNull);
      expect(match!.name, 'hp100');
    });

    test('returns null for non-matching specs', () {
      expect(TankPresets.matchBySpecs(14.0, 220.0), isNull);
    });

    test('returns null for metric tanks (no ratedCapacityCuft)', () {
      // Steel 12L is 12.0L @ 200 bar but has no ratedCapacityCuft
      expect(TankPresets.matchBySpecs(12.0, 200.0), isNull);
    });
  });
}
