import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  test('queryUnitPrefsProvider mirrors every unit setting', () {
    const settings = AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(queryUnitPrefsProvider),
      const UnitPrefs(
        depth: DepthUnit.feet,
        temperature: TemperatureUnit.fahrenheit,
        pressure: PressureUnit.psi,
        weight: WeightUnit.pounds,
        volume: VolumeUnit.cubicFeet,
      ),
    );
  });

  test('the default settings are metric', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(queryUnitPrefsProvider), kMetricPrefs);
  });
}
