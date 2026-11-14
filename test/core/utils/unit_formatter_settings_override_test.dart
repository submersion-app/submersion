import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A cylinder's own units over the diver's (issue #4534): everything but
/// the overridden units reads through to the base.
void main() {
  const base = AppSettings(
    depthUnit: DepthUnit.feet,
    weightUnit: WeightUnit.pounds,
    dateFormat: DateFormatPreference.ddmmyyyy,
    gfHigh: 70,
  );

  test('overrides only the units it is given', () {
    const override = UnitFormatterSettingsOverride(
      base,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
    );

    expect(
      unitFormatterSettingsKey(override),
      unitFormatterSettingsKey(
        base.copyWith(
          pressureUnit: PressureUnit.psi,
          volumeUnit: VolumeUnit.cubicFeet,
        ),
      ),
    );
  });

  test('with no overrides it reads exactly as its base', () {
    const override = UnitFormatterSettingsOverride(base);

    expect(unitFormatterSettingsKey(override), unitFormatterSettingsKey(base));
  });
}
