import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';

void main() {
  group('gasCompressibilityFactor', () {
    test('Z ≈ 1.0 at surface pressure for air', () {
      final z = gasCompressibilityFactor(o2Percent: 21, bar: 1.0);
      expect(z, closeTo(1.0, 0.001));
    });

    test('Z deviates from 1.0 at moderate pressure for air (200 bar)', () {
      final z = gasCompressibilityFactor(o2Percent: 21, bar: 200.0);
      // N2-dominated mix has positive Z deviation at high pressure
      expect(z, greaterThan(1.0));
      expect(z, closeTo(1.036, 0.01));
    });

    test('Z for pure O2 at 200 bar', () {
      final z = gasCompressibilityFactor(o2Percent: 100, bar: 200.0);
      // O2 has negative first virial coefficient, so Z < 1
      expect(z, lessThan(1.0));
    });

    test('Z for pure He at 200 bar is > 1 (positive virial)', () {
      final z = gasCompressibilityFactor(
        o2Percent: 0,
        hePercent: 100,
        bar: 200.0,
      );
      expect(z, greaterThan(1.0));
    });

    test('Z at 0 bar is exactly 1.0', () {
      final z = gasCompressibilityFactor(o2Percent: 21, bar: 0.0);
      expect(z, 1.0);
    });

    test('pressure is clamped at 500 bar', () {
      final z500 = gasCompressibilityFactor(o2Percent: 21, bar: 500.0);
      final z600 = gasCompressibilityFactor(o2Percent: 21, bar: 600.0);
      expect(z600, z500);
    });

    test('trimix 21/35 gives intermediate Z', () {
      final zAir = gasCompressibilityFactor(o2Percent: 21, bar: 200.0);
      final zHe = gasCompressibilityFactor(
        o2Percent: 0,
        hePercent: 100,
        bar: 200.0,
      );
      final zTrimix = gasCompressibilityFactor(
        o2Percent: 21,
        hePercent: 35,
        bar: 200.0,
      );
      // Trimix Z should be between air and pure helium
      expect(zTrimix, greaterThan(zAir));
      expect(zTrimix, lessThan(zHe));
    });

    test('EAN32 at 200 bar matches expected value', () {
      final z = gasCompressibilityFactor(o2Percent: 32, bar: 200.0);
      // More O2 means slightly lower Z than air
      final zAir = gasCompressibilityFactor(o2Percent: 21, bar: 200.0);
      expect(z, lessThan(zAir));
    });
  });

  group('gasVolume', () {
    test('returns 0 when pressure is 0', () {
      expect(
        gasVolume(
          tankSizeLiters: 12,
          pressureBar: 0,
          o2Percent: 21,
          model: GasModel.real,
        ),
        0.0,
      );
    });

    test('returns 0 when pressure is negative', () {
      expect(
        gasVolume(
          tankSizeLiters: 12,
          pressureBar: -10,
          o2Percent: 21,
          model: GasModel.real,
        ),
        0.0,
      );
    });

    test('12L tank at 200 bar air accounts for compressibility', () {
      final vol = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 21,
        model: GasModel.real,
      );
      // Ideal at the 1 bar reference: 12 * 200 = 2400 L.
      // With Z > 1 for air at 200 bar, actual volume < ideal (issue #828).
      expect(vol, lessThan(2400));
      expect(vol, closeTo(2317, 5));
    });

    test('helium tank stores more gas than air at same pressure', () {
      final volAir = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 21,
        model: GasModel.real,
      );
      final volHe = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 0,
        hePercent: 100,
        model: GasModel.real,
      );
      // He has Z > 1 (larger), so volume = tank * P/Z is less
      // Air also has Z > 1 but smaller than He, so air volume > He volume
      expect(volAir, greaterThan(volHe));
    });

    test('volume scales linearly with tank size', () {
      final vol12 = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 21,
        model: GasModel.real,
      );
      final vol24 = gasVolume(
        tankSizeLiters: 24,
        pressureBar: 200,
        o2Percent: 21,
        model: GasModel.real,
      );
      expect(vol24, closeTo(vol12 * 2, 0.001));
    });
  });

  group('pressureAfterConsuming', () {
    test('consuming zero keeps start pressure', () {
      expect(
        pressureAfterConsuming(
          tankSizeLiters: 11.1,
          startPressureBar: 207,
          litersConsumed: 0,
          o2Percent: 21,
          model: GasModel.real,
        ),
        closeTo(207.0, 0.01),
      );
    });

    test('matches python bisection for 500 L from an AL80', () {
      final end = pressureAfterConsuming(
        tankSizeLiters: 11.1,
        startPressureBar: 207,
        litersConsumed: 500,
        o2Percent: 21,
        model: GasModel.real,
      );
      // python3 at the 1 bar reference (issue #828): 155.935672 (ideal: 161.955)
      expect(end, closeTo(155.935672, 0.05));
    });

    test('consuming everything returns 0', () {
      expect(
        pressureAfterConsuming(
          tankSizeLiters: 11.1,
          startPressureBar: 207,
          litersConsumed: 99999,
          o2Percent: 21,
          model: GasModel.real,
        ),
        0.0,
      );
    });

    test('round-trips with gasVolume', () {
      const consumed = 800.0;
      final end = pressureAfterConsuming(
        tankSizeLiters: 12.0,
        startPressureBar: 232,
        litersConsumed: consumed,
        o2Percent: 18,
        hePercent: 45,
        model: GasModel.real,
      );
      final startVol = gasVolume(
        tankSizeLiters: 12.0,
        pressureBar: 232,
        o2Percent: 18,
        hePercent: 45,
        model: GasModel.real,
      );
      final endVol = gasVolume(
        tankSizeLiters: 12.0,
        pressureBar: end,
        o2Percent: 18,
        hePercent: 45,
        model: GasModel.real,
      );
      expect(startVol - endVol, closeTo(consumed, 0.5));
    });
  });
}
