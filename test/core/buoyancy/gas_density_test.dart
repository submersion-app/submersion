import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gas_density.dart';

void main() {
  group('GasDensity.mixDensityKgPerLBar', () {
    // Vectors computed with python3 (molar masses O2 31.998, N2 28.014,
    // He 4.0026, air 28.9647; scaled so air matches 0.001225 kg/L/bar).
    test('21/0 is near the air constant', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 21, hePercent: 0),
        closeTo(0.0012201760763964412, 1e-9),
      );
    });

    test('EAN32 is denser than air', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 32, hePercent: 0),
        closeTo(0.0012387104993319452, 1e-9),
      );
    });

    test('Tx 18/45 is much lighter than air', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 18, hePercent: 45),
        closeTo(0.0007581413841676246, 1e-9),
      );
    });

    test('pure oxygen', () {
      expect(
        GasDensity.mixDensityKgPerLBar(o2Percent: 100, hePercent: 0),
        closeTo(0.0013532869320241534, 1e-9),
      );
    });

    test('density scales linearly with molar mass (monotone in He)', () {
      final lighter = GasDensity.mixDensityKgPerLBar(
        o2Percent: 21,
        hePercent: 30,
      );
      final air = GasDensity.mixDensityKgPerLBar(o2Percent: 21, hePercent: 0);
      expect(lighter, lessThan(air));
    });
  });
}
