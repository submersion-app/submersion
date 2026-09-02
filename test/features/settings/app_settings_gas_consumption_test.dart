import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The gas-consumption display preference replaces the SAC unit toggle
/// (spec D3). New installs show both lanes.
void main() {
  test('defaults to both', () {
    expect(
      const AppSettings().gasConsumptionDisplay,
      GasConsumptionDisplay.both,
    );
  });

  test('copyWith replaces the display and leaves the rest alone', () {
    const before = AppSettings(volumeUnit: VolumeUnit.cubicFeet);
    final after = before.copyWith(
      gasConsumptionDisplay: GasConsumptionDisplay.rmv,
    );
    expect(after.gasConsumptionDisplay, GasConsumptionDisplay.rmv);
    expect(after.volumeUnit, VolumeUnit.cubicFeet);
    expect(before.gasConsumptionDisplay, GasConsumptionDisplay.both);
  });
}
