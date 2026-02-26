import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

void main() {
  // Compartment 1 from ZH-L16C: halfTimeN2=4, a=1.2599, b=0.5050
  const comp1 = TissueCompartment(
    compartmentNumber: 1,
    halfTimeN2: 4.0,
    halfTimeHe: 1.51,
    mValueAN2: 1.2599,
    mValueBN2: 0.5050,
    mValueAHe: 1.7424,
    mValueBHe: 0.4245,
    currentPN2: 0.79, // Surface saturated
    currentPHe: 0.0,
  );

  group('mValueAtAmbient', () {
    test('at surface (1.0 bar) matches surfaceMValue', () {
      expect(comp1.mValueAtAmbient(1.0), closeTo(comp1.surfaceMValue, 0.0001));
    });

    test('increases with ambient pressure', () {
      final mAtSurface = comp1.mValueAtAmbient(1.0);
      final mAt10m = comp1.mValueAtAmbient(2.0);
      final mAt20m = comp1.mValueAtAmbient(3.0);

      expect(mAt10m, greaterThan(mAtSurface));
      expect(mAt20m, greaterThan(mAt10m));
    });

    test('formula is a + P_ambient / b', () {
      const ambient = 2.5;
      final expected = comp1.blendedA + (ambient / comp1.blendedB);
      expect(comp1.mValueAtAmbient(ambient), closeTo(expected, 0.0001));
    });
  });

  group('gradientFactor', () {
    test(
      'returns approximately zero when tissue equals ambient (equilibrium)',
      () {
        // Create a compartment where tissue tension equals ambient
        final equilibrated = comp1.copyWith(currentPN2: 1.5, currentPHe: 0.0);
        // At 5m (1.5 bar ambient), tissue tension = ambient
        final gf = equilibrated.gradientFactor(1.5);
        expect(gf, closeTo(0.0, 0.01));
      },
    );

    test('returns 1.0 when tissue tension equals M-value at depth', () {
      // Set tissue tension to exactly the M-value at 2.0 bar ambient
      final mAt2Bar = comp1.mValueAtAmbient(2.0);
      final atMValue = comp1.copyWith(currentPN2: mAt2Bar, currentPHe: 0.0);
      final gf = atMValue.gradientFactor(2.0);
      expect(gf, closeTo(1.0, 0.001));
    });

    test('returns negative when undersaturated', () {
      // Surface-saturated tissue at depth (tissue tension < ambient)
      // At 20m (3.0 bar), surface-saturated tissue (0.79) is way below ambient
      final gf = comp1.gradientFactor(3.0);
      expect(gf, isNegative);
    });

    test('returns >1.0 when M-value is exceeded', () {
      // Set tissue tension above M-value at surface
      final exceeded = comp1.copyWith(currentPN2: 4.0, currentPHe: 0.0);
      final gf = exceeded.gradientFactor(1.0);
      expect(gf, greaterThan(1.0));
    });

    test('returns 0.0 when denominator is zero or negative', () {
      // Create degenerate case where M-value <= ambient
      // This shouldn't happen physically but test the guard
      const degenerate = TissueCompartment(
        compartmentNumber: 1,
        halfTimeN2: 4.0,
        halfTimeHe: 1.51,
        mValueAN2: 0.0,
        mValueBN2: 100.0, // Makes M-value very small
        mValueAHe: 0.0,
        mValueBHe: 100.0,
        currentPN2: 0.5,
        currentPHe: 0.0,
      );
      final gf = degenerate.gradientFactor(100.0);
      expect(gf, equals(0.0));
    });

    test('increases as tissue tension rises at constant depth', () {
      final low = comp1.copyWith(currentPN2: 1.5);
      final high = comp1.copyWith(currentPN2: 2.5);
      const ambient = 2.0;

      expect(
        high.gradientFactor(ambient),
        greaterThan(low.gradientFactor(ambient)),
      );
    });
  });

  group('surfaceGradientFactor', () {
    test('matches gradientFactor(1.0)', () {
      expect(
        comp1.surfaceGradientFactor,
        closeTo(comp1.gradientFactor(1.0), 0.0001),
      );
    });

    test('is higher than GF at depth for supersaturated tissue', () {
      // A loaded tissue has higher GF at surface than at depth
      // because the M-value headroom is smaller at surface
      final loaded = comp1.copyWith(currentPN2: 2.0);
      const depthAmbient = 2.0; // 10m

      expect(
        loaded.surfaceGradientFactor,
        greaterThan(loaded.gradientFactor(depthAmbient)),
      );
    });

    test('returns 0.0 when surfaceMValue denominator is zero', () {
      const degenerate = TissueCompartment(
        compartmentNumber: 1,
        halfTimeN2: 4.0,
        halfTimeHe: 1.51,
        mValueAN2: 0.0,
        mValueBN2: 100.0,
        mValueAHe: 0.0,
        mValueBHe: 100.0,
        currentPN2: 0.5,
        currentPHe: 0.0,
      );
      expect(degenerate.surfaceGradientFactor, equals(0.0));
    });
  });

  group('with helium', () {
    test('gradientFactor uses blended coefficients for trimix', () {
      final trimix = comp1.copyWith(currentPN2: 1.5, currentPHe: 0.5);
      final gf = trimix.gradientFactor(1.0);
      // With He present, the blended a/b change, so GF differs from N2-only
      final n2Only = comp1.copyWith(currentPN2: 2.0, currentPHe: 0.0);
      final gfN2Only = n2Only.gradientFactor(1.0);
      // Different values due to different blended coefficients
      expect(gf, isNot(closeTo(gfN2Only, 0.001)));
    });
  });
}
