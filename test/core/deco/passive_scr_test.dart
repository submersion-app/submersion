import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';

/// Validates the passive-addition SCR (pSCR) breathing model, a faithful port
/// of Subsurface's `pscr_o2` (core/gas.cpp). The inspired ppO2 is the supply
/// ppO2 minus a depth-independent metabolic drop:
///
///   drop_bar = (1 - fO2) * o2Consumption / (sac * pscrRatio) * 1000
///
/// clamped at zero, with the remaining pressure split as inert by the supply
/// He:N2 ratio. Vectors here are hand-computed from that formula with
/// Subsurface's default settings (720 / 20000 / 100), which give a 0.36*(1-fO2)
/// bar drop.
void main() {
  group('PassiveScr (Subsurface pscr_o2 model)', () {
    test('O2 drop matches the Subsurface formula (hand-computed)', () {
      // air: (1 - 0.21) * 720 / (20000 * 100) * 1000 = 0.79 * 0.36 = 0.2844.
      expect(PassiveScr(supplyFO2: 0.21).o2DropBar, closeTo(0.2844, 1e-9));
      // EAN50: 0.50 * 0.36 = 0.18.
      expect(PassiveScr(supplyFO2: 0.50).o2DropBar, closeTo(0.18, 1e-9));
    });

    test(
      'inspired pO2 is supply ppO2 minus the fixed drop, clamped at zero',
      () {
        final air = PassiveScr(supplyFO2: 0.21);
        // 4 bar: 0.21*4 - 0.2844 = 0.5556.
        expect(air.inspiredAt(4.0).pO2, closeTo(0.5556, 1e-9));
        // Surface: 0.21 - 0.2844 < 0 -> clamped to 0 (a hypoxic loop).
        expect(air.inspiredAt(1.0).pO2, 0.0);
      },
    );

    test('the O2 drop is depth-independent (Subsurface steady state)', () {
      final air = PassiveScr(supplyFO2: 0.21);
      double drop(double amb) => 0.21 * amb - air.inspiredAt(amb).pO2;
      // Where not clamped, OC ppO2 minus loop ppO2 is the constant drop.
      expect(drop(3.0), closeTo(0.2844, 1e-9));
      expect(drop(5.0), closeTo(0.2844, 1e-9));
    });

    test('inspired partials sum to ambient (no water-vapor term)', () {
      final g = PassiveScr(supplyFO2: 0.32).inspiredAt(4.0);
      expect(g.pO2 + g.pN2 + g.pHe, closeTo(4.0, 1e-9));
    });

    test('remaining pressure is inert, split by the supply He:N2 ratio', () {
      // 21/35 trimix: inert is He 0.35 : N2 0.44 of total inert (0.79).
      final g = PassiveScr(supplyFO2: 0.21, supplyFHe: 0.35).inspiredAt(4.0);
      final inert = g.pN2 + g.pHe;
      expect(g.pHe / inert, closeTo(0.35 / 0.79, 1e-9));
      expect(g.pN2 / inert, closeTo(0.44 / 0.79, 1e-9));
    });

    test('the loop is hypoxic shallow but breathable at depth (lean gas)', () {
      final air = PassiveScr(supplyFO2: 0.21);
      expect(air.hypoxicAt(1.0), isTrue); // clamped ppO2 0 near the surface
      expect(air.hypoxicAt(4.0), isFalse); // 0.556 bar at 30 m
    });

    test('a leaner supply gas produces a larger O2 drop', () {
      expect(
        PassiveScr(supplyFO2: 0.21).o2DropBar,
        greaterThan(PassiveScr(supplyFO2: 0.50).o2DropBar),
      );
    });

    test('a larger pSCR ratio shrinks the drop proportionally', () {
      final base = PassiveScr(supplyFO2: 0.32);
      final doubled = PassiveScr(supplyFO2: 0.32, pscrRatio: 200);
      expect(doubled.o2DropBar, closeTo(base.o2DropBar / 2.0, 1e-12));
    });
  });
}
