import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('SAC value unit conversion', () {
    test('pressure-based SAC converts bar/min to psi/min in imperial', () {
      // A SAC rate of 1.0 bar/min should convert to ~14.5 psi/min
      const imperialSettings = AppSettings(
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
      );
      const units = UnitFormatter(imperialSettings);

      const sacBarPerMin = 1.0;
      final converted = units.convertPressure(sacBarPerMin);

      // 1 bar = 14.5038 psi
      expect(converted, closeTo(14.5038, 0.01));
    });

    test('pressure-based SAC stays in bar/min in metric', () {
      const metricSettings = AppSettings(
        pressureUnit: PressureUnit.bar,
        volumeUnit: VolumeUnit.liters,
      );
      const units = UnitFormatter(metricSettings);

      const sacBarPerMin = 0.5;
      final converted = units.convertPressure(sacBarPerMin);

      expect(converted, equals(0.5));
    });

    test('volume-based SAC converts L/min to cuft/min in imperial', () {
      // A SAC rate of 15.0 L/min should convert to ~0.53 cuft/min
      const imperialSettings = AppSettings(
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
      );
      const units = UnitFormatter(imperialSettings);

      const sacLPerMin = 15.0;
      final converted = units.convertVolume(sacLPerMin);

      // 1 L = 0.0353147 cuft, 15 L = 0.5297
      expect(converted, closeTo(0.5297, 0.01));
    });

    test('volume-based SAC stays in L/min in metric', () {
      const metricSettings = AppSettings(
        pressureUnit: PressureUnit.bar,
        volumeUnit: VolumeUnit.liters,
      );
      const units = UnitFormatter(metricSettings);

      const sacLPerMin = 15.0;
      final converted = units.convertVolume(sacLPerMin);

      expect(converted, equals(15.0));
    });

    test('convertSacValue helper applies correct conversion per sacUnit', () {
      const imperialSettings = AppSettings(
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
      );
      const units = UnitFormatter(imperialSettings);

      // Pressure-based SAC: should use convertPressure
      const pressureSac = 0.5; // bar/min
      final convertedPressure = _convertSacValue(
        pressureSac,
        SacUnit.pressurePerMin,
        units,
      );
      expect(convertedPressure, closeTo(0.5 * 14.5038, 0.1));

      // Volume-based SAC: should use convertVolume
      const volumeSac = 15.0; // L/min
      final convertedVolume = _convertSacValue(
        volumeSac,
        SacUnit.litersPerMin,
        units,
      );
      expect(convertedVolume, closeTo(15.0 * 0.0353147, 0.01));
    });
  });
}

/// Mirror of the conversion logic that should exist in the statistics gas page
double _convertSacValue(double value, SacUnit sacUnit, UnitFormatter units) {
  return sacUnit == SacUnit.litersPerMin
      ? units.convertVolume(value)
      : units.convertPressure(value);
}
