import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';

void main() {
  group('BestMixCalculatorPreferences.defaults', () {
    test('starts in Rec with non-breaking values', () {
      const prefs = BestMixCalculatorPreferences.defaults;
      expect(prefs.mode, BestMixMode.rec);
      expect(prefs.rec.densityAware, isFalse);
      expect(prefs.ocTec.densityAware, isFalse);
      expect(prefs.ccrTec.densityAware, isFalse);
      expect(prefs.ccrSource, CcrGasSource.diluent);
      expect(prefs.waterType, isNull);
      expect(prefs.temperature, GasDensityTemperature.zeroC);
      expect(prefs.overridesByDiver, isEmpty);
    });
  });

  group('inputsFor', () {
    test('returns the slot matching the mode', () {
      const prefs = BestMixCalculatorPreferences.defaults;
      expect(prefs.inputsFor(BestMixMode.rec), prefs.rec);
      expect(prefs.inputsFor(BestMixMode.ocTec), prefs.ocTec);
      expect(prefs.inputsFor(BestMixMode.ccrTec), prefs.ccrTec);
    });
  });

  group('withInputs', () {
    test('updates only the targeted mode slot', () {
      const prefs = BestMixCalculatorPreferences.defaults;
      final updated = prefs.withInputs(
        BestMixMode.ocTec,
        prefs.ocTec.copyWith(depthMeters: 55, densityAware: true),
      );
      expect(updated.ocTec.depthMeters, 55);
      expect(updated.ocTec.densityAware, isTrue);
      expect(updated.rec, prefs.rec);
      expect(updated.ccrTec, prefs.ccrTec);
    });
  });

  group('withOverrides', () {
    test('stores an override for one diver without touching another', () {
      const prefs = BestMixCalculatorPreferences.defaults;
      final withA = prefs.withOverrides(
        'diverA',
        const ModLimitOverrides(workingPpO2: 1.3),
      );
      expect(withA.overridesFor('diverA').workingPpO2, 1.3);
      expect(withA.overridesFor('diverB').isEmpty, isTrue);
    });

    test('an empty override set removes the stored entry', () {
      const prefs = BestMixCalculatorPreferences.defaults;
      final withA = prefs.withOverrides(
        'diverA',
        const ModLimitOverrides(workingPpO2: 1.3),
      );
      final cleared = withA.withOverrides('diverA', ModLimitOverrides.none);
      expect(cleared.overridesByDiver, isEmpty);
    });
  });

  group('JSON round-trip', () {
    test('a fully populated value survives encode/decode', () {
      const prefs = BestMixCalculatorPreferences(
        mode: BestMixMode.ccrTec,
        rec: BestMixModeInputs(
          depthMeters: 25,
          densityAware: false,
          recPpO2: 1.2,
        ),
        ocTec: BestMixModeInputs(
          depthMeters: 55,
          densityAware: true,
          recPpO2: 1.4,
        ),
        ccrTec: BestMixModeInputs(
          depthMeters: 60,
          densityAware: true,
          recPpO2: 1.4,
        ),
        ccrSource: CcrGasSource.bailout,
        waterType: WaterType.fresh,
        temperature: GasDensityTemperature.twentyC,
        overridesByDiver: {'diverA': ModLimitOverrides(workingPpO2: 1.3)},
      );
      final decoded = BestMixCalculatorPreferences.fromJson(prefs.toJson());
      expect(decoded.mode, BestMixMode.ccrTec);
      expect(decoded.rec.depthMeters, 25);
      expect(decoded.rec.recPpO2, 1.2);
      expect(decoded.ocTec.depthMeters, 55);
      expect(decoded.ocTec.densityAware, isTrue);
      expect(decoded.ccrTec.depthMeters, 60);
      expect(decoded.ccrSource, CcrGasSource.bailout);
      expect(decoded.waterType, WaterType.fresh);
      expect(decoded.temperature, GasDensityTemperature.twentyC);
      expect(decoded.overridesFor('diverA').workingPpO2, 1.3);
    });

    test('malformed input falls back per field, not as a whole', () {
      final decoded = BestMixCalculatorPreferences.fromJson({
        'mode': 'not-a-mode',
        'rec': 'not-a-map',
        'ccrSource': 42,
        'waterType': 'brackish', // not an offered type
        'temperature': 'lukewarm',
        'overrides': 'not-a-map',
      });
      expect(decoded.mode, BestMixMode.rec);
      expect(decoded.rec, BestMixCalculatorPreferences.defaults.rec);
      expect(decoded.ccrSource, CcrGasSource.diluent);
      expect(decoded.waterType, isNull);
      expect(decoded.temperature, GasDensityTemperature.zeroC);
      expect(decoded.overridesByDiver, isEmpty);
    });

    test('an absent key falls back to its default rather than throwing', () {
      final decoded = BestMixCalculatorPreferences.fromJson({});
      expect(decoded, BestMixCalculatorPreferences.defaults);
    });
  });
}
