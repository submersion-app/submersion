import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/domain/mod_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';

void main() {
  group('defaults', () {
    test('start in Rec with EAN32 and no overrides', () {
      const p = ModCalculatorPreferences.defaults;
      expect(p.mode, ModCalculatorMode.rec);
      expect(p.rec.o2Percent, 32);
      expect(p.rec.hePercent, 0);
      expect(p.ocTec.o2Percent, 21);
      expect(p.ocTec.hePercent, 35);
      expect(p.minPpO2, 0.18);
      expect(p.waterType, isNull);
      expect(p.overridesByDiver, isEmpty);
      expect(p.overridesFor('diver-1'), ModLimitOverrides.none);
      expect(p.overridesFor(null), ModLimitOverrides.none);
    });
  });

  group('per-mode inputs', () {
    test('each mode keeps its own mix', () {
      final p = ModCalculatorPreferences.defaults.withInputs(
        ModCalculatorMode.ocTec,
        ModCalculatorPreferences.defaults.ocTec.copyWith(o2Percent: 50),
      );
      expect(p.inputsFor(ModCalculatorMode.ocTec).o2Percent, 50);
      expect(p.inputsFor(ModCalculatorMode.rec).o2Percent, 32);
      expect(p.inputsFor(ModCalculatorMode.ccrTec).o2Percent, 21);
    });
  });

  group('overrides', () {
    test('are kept per diver and never carry to another', () {
      final p = ModCalculatorPreferences.defaults.withOverrides(
        'diver-a',
        const ModLimitOverrides(workingPpO2: 1.3),
      );
      expect(p.overridesFor('diver-a').workingPpO2, 1.3);
      expect(p.overridesFor('diver-b'), ModLimitOverrides.none);
      expect(p.overridesFor(null), ModLimitOverrides.none);
    });

    test('an empty set drops the diver entry', () {
      final p = ModCalculatorPreferences.defaults
          .withOverrides('diver-a', const ModLimitOverrides(decoPpO2: 1.5))
          .withOverrides('diver-a', ModLimitOverrides.none);
      expect(p.overridesByDiver, isEmpty);
    });
  });

  group('JSON', () {
    test('round-trips every field', () {
      final p = ModCalculatorPreferences.defaults
          .copyWith(
            mode: ModCalculatorMode.ccrTec,
            waterType: WaterType.fresh,
            minPpO2: 0.16,
          )
          .withOverrides(
            'diver-a',
            const ModLimitOverrides(
              workingPpO2: 1.3,
              decoPpO2: 1.5,
              flushPpO2: 1.4,
              setpointBar: 1.2,
            ),
          )
          .withOverrides(null, const ModLimitOverrides(flushPpO2: 1.1))
          .withInputs(
            ModCalculatorMode.ccrTec,
            const ModModeInputs(
              o2Percent: 18,
              hePercent: 45,
              targetDepthMeters: 60,
              checkTargetDepth: true,
            ),
          );
      final decoded = ModCalculatorPreferences.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, p);
    });

    test('garbage falls back to the defaults field by field', () {
      final decoded = ModCalculatorPreferences.fromJson({
        'mode': 'nonsense',
        'rec': 'not a map',
        'ocTec': {'o2Percent': 'x', 'hePercent': 20},
        'waterType': 42,
        'minPpO2': 0.5,
        'overrides': {
          'diver-a': {'workingPpO2': 9.9, 'decoPpO2': 1.5},
          'diver-b': 'not a map',
          'diver-c': {'workingPpO2': 9.9},
        },
      });
      expect(decoded.mode, ModCalculatorMode.rec);
      expect(decoded.rec, ModCalculatorPreferences.defaults.rec);
      expect(decoded.ocTec.o2Percent, 21);
      expect(decoded.ocTec.hePercent, 20);
      expect(decoded.waterType, isNull);
      expect(decoded.minPpO2, 0.18);
      expect(decoded.overridesFor('diver-a').workingPpO2, isNull);
      expect(decoded.overridesFor('diver-a').decoPpO2, 1.5);
      // Nothing valid left: no entry at all.
      expect(decoded.overridesByDiver.keys, ['diver-a']);
    });

    test('only the water types the calculator offers are restored', () {
      // Brackish would be computed while neither segment shows it.
      for (final type in WaterType.values) {
        final decoded = ModCalculatorPreferences.fromJson({
          'waterType': type.name,
        });
        expect(
          decoded.waterType,
          type == WaterType.brackish ? isNull : type,
          reason: type.name,
        );
      }
    });

    test('a flush ppO2 below 1.0 is kept, down to 0.5', () {
      double? flush(double value) => ModCalculatorPreferences.fromJson({
        'overrides': {
          'd': {'flushPpO2': value},
        },
      }).overridesFor('d').flushPpO2;
      expect(flush(0.8), 0.8);
      expect(flush(0.4), isNull);
    });

    test('helium is clamped to the room the oxygen leaves', () {
      final decoded = ModCalculatorPreferences.fromJson({
        'ocTec': {'o2Percent': 30, 'hePercent': 90},
      });
      expect(decoded.ocTec.hePercent, 70);
    });
  });
}
