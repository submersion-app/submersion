import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';

void main() {
  group('GasConsumptionDisplay', () {
    test('sac shows only the pressure lane', () {
      expect(GasConsumptionDisplay.sac.showsSac, isTrue);
      expect(GasConsumptionDisplay.sac.showsRmv, isFalse);
      expect(GasConsumptionDisplay.sac.lanes, [GasConsumptionLane.sac]);
    });

    test('rmv shows only the volume lane', () {
      expect(GasConsumptionDisplay.rmv.showsSac, isFalse);
      expect(GasConsumptionDisplay.rmv.showsRmv, isTrue);
      expect(GasConsumptionDisplay.rmv.lanes, [GasConsumptionLane.rmv]);
    });

    test('both shows both lanes, SAC first', () {
      expect(GasConsumptionDisplay.both.showsSac, isTrue);
      expect(GasConsumptionDisplay.both.showsRmv, isTrue);
      expect(GasConsumptionDisplay.both.lanes, [
        GasConsumptionLane.sac,
        GasConsumptionLane.rmv,
      ]);
    });

    test('fromName resolves current names', () {
      for (final value in GasConsumptionDisplay.values) {
        expect(GasConsumptionDisplay.fromName(value.name), value);
      }
    });

    test('fromName maps the retired SacUnit spellings onto their lane', () {
      // A stored 'litersPerMin' was the volume lane; 'pressurePerMin' the
      // pressure lane. Both can still arrive from a peer on an older build.
      expect(
        GasConsumptionDisplay.fromName('litersPerMin'),
        GasConsumptionDisplay.rmv,
      );
      expect(
        GasConsumptionDisplay.fromName('pressurePerMin'),
        GasConsumptionDisplay.sac,
      );
    });

    test('fromName falls back to both for anything else', () {
      expect(GasConsumptionDisplay.fromName(null), GasConsumptionDisplay.both);
      expect(GasConsumptionDisplay.fromName(''), GasConsumptionDisplay.both);
      expect(
        GasConsumptionDisplay.fromName('nonsense'),
        GasConsumptionDisplay.both,
      );
    });
  });
}
