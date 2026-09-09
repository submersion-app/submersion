import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('settings map to thresholds with O2 as a fraction', () {
    const settings = AppSettings(
      coldWaterThresholdC: 8,
      deepDiveThresholdM: 25,
      highO2ThresholdPercent: 32,
    );
    expect(
      exposureThresholdsFromSettings(settings),
      const ExposureThresholds(
        coldWaterC: 8,
        deepDiveM: 25,
        highO2Fraction: 0.32,
      ),
    );
  });

  test('default settings give the built-in thresholds', () {
    expect(
      exposureThresholdsFromSettings(const AppSettings()),
      ExposureThresholds.defaults,
    );
  });
}
