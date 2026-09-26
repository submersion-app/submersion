import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Every displayed rate unit comes from [UnitFormatter.perMinute] (issue
/// #1932). The minute part is an untranslated SI symbol, like `m` and `bar`,
/// so it reads "/min" in every locale.
void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
    ),
  );

  test('perMinute appends the minute symbol to a base unit', () {
    expect(UnitFormatter.perMinute('m'), 'm/min');
    expect(UnitFormatter.perMinute('cuft'), 'cuft/min');
  });

  test('depthRateSymbol follows the depth unit', () {
    expect(metric.depthRateSymbol, 'm/min');
    expect(imperial.depthRateSymbol, 'ft/min');
  });

  test('sacSymbol and rmvSymbol are built by perMinute', () {
    expect(metric.sacSymbol, UnitFormatter.perMinute(metric.pressureSymbol));
    expect(imperial.rmvSymbol, UnitFormatter.perMinute(imperial.volumeSymbol));
  });

  group('formatDepthRate', () {
    test('matches formatDepth with the rate symbol, no space', () {
      expect(metric.formatDepthRate(9), '9.0m/min');
      expect(metric.formatDepthRate(9, decimals: 0), '9m/min');
    });

    test('converts to the diver depth unit', () {
      // 9 m/min is 29.5 ft/min.
      expect(imperial.formatDepthRate(9), '29.5ft/min');
    });

    test('renders the neutral placeholder for a missing value', () {
      expect(metric.formatDepthRate(null), '--');
    });
  });
}
