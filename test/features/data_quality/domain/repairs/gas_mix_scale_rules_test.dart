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

    test('a share the diver may have put right is not divided again', () {
      // The importers multiplied both shares. A Tx 18/45 stored as 1800/4500
      // whose helium the diver put right by hand is 1800/45: read that way
      // it is 18/45, a gas, so dividing both (45% helium to 0.45%) is a
      // guess the repair must not make. Left for the diver.
      expect(hundredfoldCorrection(const GasMix(o2: 1800, he: 45)), isNull);
      expect(hundredfoldCorrection(const GasMix(o2: 32, he: 3500)), isNull);
    });

    test('a small helium share no hand correction explains is divided', () {
      // `<o2>21</o2><he>1</he>` in a percentage file was stored 2100/100.
      // Read as a hand correction it would be 21/100, no gas, so the import
      // multiplied the helium too: Tx 21/1.
      expect(
        hundredfoldCorrection(const GasMix(o2: 2100, he: 100)),
        const GasMix(o2: 21, he: 1),
      );
      expect(
        hundredfoldCorrection(const GasMix(o2: 2100, he: 90)),
        const GasMix(o2: 21, he: 0.9),
      );
    });

    test('a helium share over 100% is divided with the oxygen', () {
      expect(
        hundredfoldCorrection(const GasMix(o2: 2100, he: 150)),
        const GasMix(o2: 21, he: 1.5),
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
      // Nor does a trace of helium: 1000/50 divided is 10% O2 with 0.5%
      // helium, still no gas a diver breathes.
      expect(hundredfoldCorrection(const GasMix(o2: 1000, he: 50)), isNull);
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
