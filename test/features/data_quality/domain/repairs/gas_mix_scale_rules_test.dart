import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/repairs/gas_mix_scale_rules.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #4714: imports that read percentages as fractions stored mixes 100
/// times too high (UDDF #4705, MacDive #1493), such as 3200% O2.
void main() {
  group('hundredfoldCorrection', () {
    test('divides a nitrox stored 100 times too high', () {
      expect(
        hundredfoldCorrection(const GasMix(o2: 3200)),
        const GasMix(o2: 32),
      );
      expect(hundredfoldCorrection(const GasMix(o2: 2100)), const GasMix());
      expect(
        hundredfoldCorrection(const GasMix(o2: 10000)),
        const GasMix(o2: 100),
      );
    });

    test('divides both shares of a trimix', () {
      expect(
        hundredfoldCorrection(const GasMix(o2: 2100, he: 3500)),
        const GasMix(o2: 21, he: 35),
      );
    });

    test('divides a helium share the import also multiplied', () {
      // `<o2>21</o2><he>0.9</he>` stored 2100/90: 0.9% helium.
      expect(
        hundredfoldCorrection(const GasMix(o2: 2100, he: 90)),
        const GasMix(o2: 21, he: 0.9),
      );
    });

    test('keeps the precision of an analysed mix', () {
      expect(
        hundredfoldCorrection(const GasMix(o2: 3212.5)),
        const GasMix(o2: 32.125),
      );
      expect(
        hundredfoldCorrection(const GasMix(o2: 3210)),
        const GasMix(o2: 32.1),
      );
    });

    test('a possible mix needs no correction', () {
      expect(hundredfoldCorrection(const GasMix(o2: 32)), isNull);
      expect(hundredfoldCorrection(const GasMix(o2: 100)), isNull);
    });

    test('no correction when dividing leaves too little oxygen to breathe', () {
      // 1.5% or 4% O2 is no breathing gas: something else went wrong.
      expect(hundredfoldCorrection(const GasMix(o2: 150)), isNull);
      expect(hundredfoldCorrection(const GasMix(o2: 400)), isNull);
      expect(hundredfoldCorrection(const GasMix(o2: 60, he: 50)), isNull);
    });

    test('the oxygen floor itself is accepted', () {
      expect(
        hundredfoldCorrection(const GasMix(o2: 500, he: 8000)),
        const GasMix(o2: 5, he: 80),
      );
    });

    test('a hypoxic result needs helium to be a diving gas', () {
      // A typed 100% with an extra zero is 1000%: divided, 10% O2 with
      // nothing but nitrogen, which no diver breathes. Left for the diver.
      expect(hundredfoldCorrection(const GasMix(o2: 1000)), isNull);
      expect(hundredfoldCorrection(const GasMix(o2: 500)), isNull);
      // A hypoxic trimix stored 100 times too high is still divided.
      expect(
        hundredfoldCorrection(const GasMix(o2: 1000, he: 7000)),
        const GasMix(o2: 10, he: 70),
      );
    });

    test('a normoxic nitrox needs no helium', () {
      expect(
        hundredfoldCorrection(const GasMix(o2: 1600)),
        const GasMix(o2: 16),
      );
    });

    test('no correction when the divided mix is still impossible', () {
      expect(hundredfoldCorrection(const GasMix(o2: 3200, he: 7000)), isNull);
      expect(hundredfoldCorrection(const GasMix(o2: -2100)), isNull);
    });
  });
}
