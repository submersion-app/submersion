import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/domain/mod_calculator_preferences.dart';

void main() {
  group('defaults', () {
    test('start in Rec with EAN32 and no overrides', () {
      const p = ModCalculatorPreferences.defaults;
      expect(p.mode, ModCalculatorMode.rec);
      expect(p.rec.o2Percent, 32);
      expect(p.rec.hePercent, 0);
      expect(p.ocTec.o2Percent, 21);
      expect(p.ocTec.hePercent, 35);
      expect(p.setpointBar, isNull);
      expect(p.minPpO2, 0.18);
      expect(p.waterType, isNull);
      expect(p.workingPpO2, isNull);
      expect(p.decoPpO2, isNull);
      expect(p.flushPpO2, isNull);
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
    test('can be set and cleared again', () {
      final set = ModCalculatorPreferences.defaults.copyWith(workingPpO2: 1.3);
      expect(set.workingPpO2, 1.3);
      final cleared = set.copyWith(clearWorkingPpO2: true);
      expect(cleared.workingPpO2, isNull);
    });
  });

  group('JSON', () {
    test('round-trips every field', () {
      final p = ModCalculatorPreferences.defaults
          .copyWith(
            mode: ModCalculatorMode.ccrTec,
            waterType: WaterType.fresh,
            minPpO2: 0.16,
            workingPpO2: 1.3,
            decoPpO2: 1.5,
            flushPpO2: 1.45,
            setpointBar: 1.2,
          )
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
        'workingPpO2': 9.9,
        'decoPpO2': 1.5,
      });
      expect(decoded.mode, ModCalculatorMode.rec);
      expect(decoded.rec, ModCalculatorPreferences.defaults.rec);
      expect(decoded.ocTec.o2Percent, 21);
      expect(decoded.ocTec.hePercent, 20);
      expect(decoded.waterType, isNull);
      expect(decoded.minPpO2, 0.18);
      expect(decoded.workingPpO2, isNull);
      expect(decoded.decoPpO2, 1.5);
    });

    test('helium is clamped to the room the oxygen leaves', () {
      final decoded = ModCalculatorPreferences.fromJson({
        'ocTec': {'o2Percent': 30, 'hePercent': 90},
      });
      expect(decoded.ocTec.hePercent, 70);
    });
  });
}
