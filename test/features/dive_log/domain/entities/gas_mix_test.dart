import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('GasMix.name', () {
    test('rounds near-integer nitrox percentages for display', () {
      const ean29 = GasMix(o2: 28.999999999, he: 0.0);
      expect(ean29.name, 'EAN29');
    });

    test('rounds near-integer trimix percentages for display', () {
      const tx2135 = GasMix(o2: 20.999999999, he: 34.999999999);
      expect(tx2135.name, 'Tx 21/35');
    });

    test('pure oxygen (100%) returns O2', () {
      const o2 = GasMix(o2: 100.0, he: 0.0);
      expect(o2.name, 'O2');
    });

    test('99% O2 with no helium returns O2', () {
      const o2 = GasMix(o2: 99.0, he: 0.0);
      expect(o2.name, 'O2');
    });

    test('trimix takes precedence over oxygen label', () {
      const trimixHighO2 = GasMix(o2: 99.0, he: 1.0);
      expect(trimixHighO2.name, startsWith('Tx'));
    });

    test('air returns Air', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.name, 'Air');
    });
  });

  group('GasMix.isOxygen', () {
    test('100% O2 with no helium is oxygen', () {
      const o2 = GasMix(o2: 100.0, he: 0.0);
      expect(o2.isOxygen, isTrue);
    });

    test('99% O2 with no helium is oxygen', () {
      const o2 = GasMix(o2: 99.0, he: 0.0);
      expect(o2.isOxygen, isTrue);
    });

    test('98% O2 is not oxygen', () {
      const almostO2 = GasMix(o2: 98.0, he: 0.0);
      expect(almostO2.isOxygen, isFalse);
    });

    test('100% O2 with helium is not oxygen (trimix)', () {
      const heliox = GasMix(o2: 100.0, he: 1.0);
      expect(heliox.isOxygen, isFalse);
    });

    test('air is not oxygen', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.isOxygen, isFalse);
    });
  });

  group('GasMix.mnd', () {
    test('air with O2 narcotic returns depth equal to END limit', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.mnd(endLimit: 30.0, o2Narcotic: true), closeTo(30.0, 0.1));
    });

    test('trimix Tx 21/35 with O2 narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      expect(tx2135.mnd(endLimit: 30.0, o2Narcotic: true), closeTo(51.5, 0.5));
    });

    test('trimix Tx 21/35 with O2 NOT narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      expect(tx2135.mnd(endLimit: 30.0, o2Narcotic: false), closeTo(61.8, 0.5));
    });

    test('EAN32 with O2 narcotic', () {
      const ean32 = GasMix(o2: 32.0, he: 0.0);
      expect(ean32.mnd(endLimit: 30.0, o2Narcotic: true), closeTo(30.0, 0.1));
    });

    test('EAN32 with O2 NOT narcotic', () {
      const ean32 = GasMix(o2: 32.0, he: 0.0);
      expect(ean32.mnd(endLimit: 30.0, o2Narcotic: false), closeTo(36.5, 0.5));
    });

    test('pure O2/He mix with O2 NOT narcotic returns infinity', () {
      const heliox = GasMix(o2: 21.0, he: 79.0);
      expect(heliox.mnd(endLimit: 30.0, o2Narcotic: false), double.infinity);
    });

    test('defaults to endLimit 30 and o2Narcotic true', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.mnd(), closeTo(30.0, 0.1));
    });
  });

  group('GasMix.end with o2Narcotic flag', () {
    test('air at 30m with O2 narcotic', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.end(30.0, o2Narcotic: true), closeTo(30.0, 0.1));
    });

    test('trimix Tx 21/35 at 60m with O2 narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      expect(tx2135.end(60.0, o2Narcotic: true), closeTo(35.5, 0.5));
    });

    test('trimix Tx 21/35 at 60m with O2 NOT narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      expect(tx2135.end(60.0, o2Narcotic: false), closeTo(29.0, 0.5));
    });

    test('backward compatible - defaults to o2Narcotic true', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.end(30.0), closeTo(30.0, 0.1));
    });
  });

  // Issue #4299: the narcotic pressure follows the dive's water and surface,
  // and END is the depth in that same water where air reaches it.
  group('GasMix.end in a dive environment', () {
    final altitude = DiveEnvironment.forConditions(
      altitudeMeters: 3000,
      waterType: WaterType.fresh,
    );
    const tx2135 = GasMix(o2: 21.0, he: 35.0);

    test('reads the narcotic pressure in the given water', () {
      final narcotic = altitude.pressureAtDepth(60.0) * 0.65;
      expect(
        tx2135.end(60.0, environment: altitude),
        closeTo(altitude.depthAtPressure(narcotic), 1e-9),
      );
      // The flat model reads 35.5 m; the 3000 m lake reads about 36.5 m.
      expect(tx2135.end(60.0), closeTo(35.5, 1e-9));
      expect(tx2135.end(60.0, environment: altitude), closeTo(36.5, 0.05));
    });

    test('with O2 not narcotic compares N2 against air in the same water', () {
      final n2Pressure = altitude.pressureAtDepth(60.0) * 0.44;
      expect(
        tx2135.end(60.0, o2Narcotic: false, environment: altitude),
        closeTo(altitude.depthAtPressure(n2Pressure / airN2Fraction), 1e-9),
      );
    });

    test('air is as narcotic as itself: its END is its depth, exactly', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.end(30.0, environment: altitude), 30.0);
      expect(air.end(30.0, environment: DiveEnvironment.forConditions()), 30.0);
    });

    test('the standard environment matches the flat model', () {
      expect(
        tx2135.end(60.0, environment: DiveEnvironment.standard),
        closeTo(tx2135.end(60.0), 1e-9),
      );
    });
  });

  group('GasMix.heForMnd', () {
    test('calculates He needed for MND 50m with O2 21% (O2 narcotic)', () {
      final he = GasMix.heForMnd(50.0, 21.0, endLimit: 30.0, o2Narcotic: true);
      expect(he, closeTo(33.3, 0.5));
    });

    test('returns 0 when target MND <= END limit (no He needed)', () {
      final he = GasMix.heForMnd(25.0, 21.0, endLimit: 30.0, o2Narcotic: true);
      expect(he, 0.0);
    });

    test('clamps to max He when target unreachable', () {
      final he = GasMix.heForMnd(200.0, 50.0, endLimit: 30.0, o2Narcotic: true);
      expect(he, 50.0);
    });

    test('calculates He needed with O2 NOT narcotic', () {
      final he = GasMix.heForMnd(50.0, 21.0, endLimit: 30.0, o2Narcotic: false);
      expect(he, closeTo(26.3, 0.5));
    });

    test('roundtrip: heForMnd result fed back into mnd returns target', () {
      final he = GasMix.heForMnd(50.0, 21.0, endLimit: 30.0, o2Narcotic: true);
      final mix = GasMix(o2: 21.0, he: he);
      expect(mix.mnd(endLimit: 30.0, o2Narcotic: true), closeTo(50.0, 0.5));
    });
  });
}
