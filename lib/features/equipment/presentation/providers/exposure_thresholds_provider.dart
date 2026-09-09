import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The diver's exposure thresholds, in storage units. Shared by the clock
/// providers and the notification scheduler so both classify alike.
ExposureThresholds exposureThresholdsFromSettings(AppSettings s) =>
    ExposureThresholds(
      coldWaterC: s.coldWaterThresholdC,
      deepDiveM: s.deepDiveThresholdM,
      highO2Fraction: s.highO2ThresholdPercent / 100.0,
    );

final exposureThresholdsProvider = Provider<ExposureThresholds>((ref) {
  // A record selector keeps the provider from rebuilding on unrelated
  // settings writes.
  final (cold, deep, o2) = ref.watch(
    settingsProvider.select(
      (s) => (
        s.coldWaterThresholdC,
        s.deepDiveThresholdM,
        s.highO2ThresholdPercent,
      ),
    ),
  );
  return ExposureThresholds(
    coldWaterC: cold,
    deepDiveM: deep,
    highO2Fraction: o2 / 100.0,
  );
});
