import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('UnitFormatter SAC rate', () {
    group('volume-based (litersPerMin)', () {
      const liters = UnitFormatter(
        AppSettings(
          sacUnit: SacUnit.litersPerMin,
          volumeUnit: VolumeUnit.liters,
        ),
      );
      const cuft = UnitFormatter(
        AppSettings(
          sacUnit: SacUnit.litersPerMin,
          volumeUnit: VolumeUnit.cubicFeet,
        ),
      );

      test('sacUnit reflects the setting', () {
        expect(liters.sacUnit, SacUnit.litersPerMin);
      });

      test('sacSymbol is volume per minute', () {
        expect(liters.sacSymbol, 'L/min');
        expect(cuft.sacSymbol, 'cuft/min');
      });

      test('convertSac leaves liters unchanged in metric', () {
        expect(liters.convertSac(15.0), closeTo(15.0, 0.0001));
      });

      test('convertSac converts liters to cubic feet in imperial', () {
        expect(cuft.convertSac(15.0), closeTo(0.5297, 0.001));
      });
    });

    group('pressure-based (pressurePerMin)', () {
      const bar = UnitFormatter(
        AppSettings(
          sacUnit: SacUnit.pressurePerMin,
          pressureUnit: PressureUnit.bar,
        ),
      );
      const psi = UnitFormatter(
        AppSettings(
          sacUnit: SacUnit.pressurePerMin,
          pressureUnit: PressureUnit.psi,
        ),
      );

      test('sacUnit reflects the setting', () {
        expect(bar.sacUnit, SacUnit.pressurePerMin);
      });

      test('sacSymbol is pressure per minute', () {
        expect(bar.sacSymbol, 'bar/min');
        expect(psi.sacSymbol, 'psi/min');
      });

      test('convertSac leaves bar unchanged in metric', () {
        expect(bar.convertSac(1.5), closeTo(1.5, 0.0001));
      });

      test('convertSac converts bar to psi in imperial', () {
        expect(psi.convertSac(1.5), closeTo(21.7557, 0.001));
      });
    });
  });
}
