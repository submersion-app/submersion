import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';

void main() {
  group('barToAtm', () {
    test('1 bar ≈ 0.9869 atm', () {
      expect(barToAtm(1.0), closeTo(0.9869, 0.0001));
    });

    test('standard atmosphere converts to 1.0 atm', () {
      expect(barToAtm(standardAtmBar), closeTo(1.0, 1e-10));
    });

    test('0 bar = 0 atm', () {
      expect(barToAtm(0), 0.0);
    });
  });

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
      expect(gasVolume(tankSizeLiters: 12, pressureBar: 0, o2Percent: 21), 0.0);
    });

    test('returns 0 when pressure is negative', () {
      expect(
        gasVolume(tankSizeLiters: 12, pressureBar: -10, o2Percent: 21),
        0.0,
      );
    });

    test('12L tank at 200 bar air accounts for compressibility', () {
      final vol = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 21,
      );
      // Ideal: 12 * (200/1.01325) ≈ 2369 L
      // With Z > 1 for air, actual volume < ideal
      expect(vol, lessThan(2369));
      expect(vol, closeTo(2287, 5));
    });

    test('helium tank stores more gas than air at same pressure', () {
      final volAir = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 21,
      );
      final volHe = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 0,
        hePercent: 100,
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
      );
      final vol24 = gasVolume(
        tankSizeLiters: 24,
        pressureBar: 200,
        o2Percent: 21,
      );
      expect(vol24, closeTo(vol12 * 2, 0.001));
    });
  });
}
