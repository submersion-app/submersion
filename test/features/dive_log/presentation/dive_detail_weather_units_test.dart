import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _metric = UnitFormatter(AppSettings());
const _imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

void main() {
  group('formatSurfacePressure', () {
    test('metric renders mbar', () {
      expect(_metric.formatSurfacePressure(1.013), '1013 mbar');
    });

    test('imperial renders inHg', () {
      // 1.013 bar = 29.91 inHg.
      final text = _imperial.formatSurfacePressure(1.013);
      expect(text, contains('inHg'));
      expect(text, contains('29.9'));
    });

    test('null renders the placeholder', () {
      expect(_metric.formatSurfacePressure(null), '--');
    });

    test('the symbol follows the depth unit, not the tank pressure unit', () {
      // Tank pressure is bar/psi; barometric pressure is a different
      // quantity, so it tracks the depth unit like wind speed does.
      const psiButMetricDepth = UnitFormatter(
        AppSettings(pressureUnit: PressureUnit.psi),
      );
      expect(psiButMetricDepth.surfacePressureSymbol, 'mbar');
      expect(_imperial.surfacePressureSymbol, 'inHg');
    });
  });

  group('swell height uses the depth unit', () {
    test('imperial converts meters to feet', () {
      // A diver enters 3 ft, we store 0.9144 m, and the detail page must
      // read it back as 3.0 ft -- not the "0.9m" the old hardcoded suffix
      // produced.
      expect(_imperial.formatDepth(0.9144, decimals: 1), '3.0ft');
    });

    test('metric renders meters unchanged', () {
      expect(_metric.formatDepth(0.9, decimals: 1), '0.9m');
    });
  });
}
