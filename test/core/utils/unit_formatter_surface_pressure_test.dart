import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A surface pressure is typed in the unit, and with the decimals, it is
/// shown in: whole mbar for a metric diver, inHg to two places for an
/// imperial one.
void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  test('mbar are whole numbers', () {
    expect(metric.surfacePressureSymbol, 'mbar');
    expect(metric.surfacePressureDecimals, 0);
  });

  test('inHg carry two decimals', () {
    expect(imperial.surfacePressureSymbol, 'inHg');
    expect(imperial.surfacePressureDecimals, 2);
  });

  // The number an input row shows must be the number the read card shows.
  for (final (name, units) in [('metric', metric), ('imperial', imperial)]) {
    test('$name: an input shows the same number as the formatted value', () {
      const bar = 0.87;
      final typed = formatFixedForInput(
        units.convertSurfacePressure(bar),
        units.surfacePressureDecimals,
      );

      expect(
        units.formatSurfacePressure(bar),
        '$typed ${units.surfacePressureSymbol}',
      );
    });
  }

  test('a typed value converts back to bar', () {
    expect(metric.surfacePressureToBar(870), closeTo(0.87, 1e-9));
    expect(
      imperial.surfacePressureToBar(imperial.convertSurfacePressure(0.87)),
      closeTo(0.87, 1e-9),
    );
  });
}
