import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';

/// Validates the passive-addition SCR (pSCR) breathing model. The loop O2 is a
/// closed-form mass balance, so the vectors here are hand-computed from
/// loopFO2 = (Q*Fsupply - VO2) / (Q - VO2), with Q = rmv * dumpFraction.
void main() {
  group('PassiveScr steady-state loop', () {
    test('loop FO2 follows the passive mass balance (hand-computed)', () {
      // Q = 20 * 0.25 = 5 L/min; loopFO2 = (5*0.40 - 1.0)/(5 - 1.0) = 0.25.
      final p = PassiveScr(
        supplyFO2: 0.40,
        dumpFraction: 0.25,
        rmvLpm: 20,
        vo2: 1.0,
      );
      expect(p.loopFO2, closeTo(0.25, 1e-12));
      expect(p.hypoxicLoop, isFalse);
    });

    test('loop O2 is depleted below the supply O2', () {
      final p = PassiveScr(
        supplyFO2: 0.40,
        dumpFraction: 0.25,
        rmvLpm: 20,
        vo2: 1.0,
      );
      expect(p.loopFO2, lessThan(0.40));
    });

    test('inspired gas is the loop mix breathed open circuit', () {
      final p = PassiveScr(
        supplyFO2: 0.40,
        dumpFraction: 0.25,
        rmvLpm: 20,
        vo2: 1.0,
      );
      final oc = OpenCircuit(fO2: p.loopFO2);
      for (final amb in [1.0, 2.0, 4.0]) {
        expect(p.inspiredAt(amb).pO2, closeTo(oc.inspiredAt(amb).pO2, 1e-12));
        expect(p.inspiredAt(amb).pN2, closeTo(oc.inspiredAt(amb).pN2, 1e-12));
      }
    });

    test(
      'inspired ppO2 scales linearly with depth (constant loop fraction)',
      () {
        final p = PassiveScr(
          supplyFO2: 0.40,
          dumpFraction: 0.25,
          rmvLpm: 20,
          vo2: 1.0,
        );
        final p2 = p.inspiredAt(2.0).pO2;
        final p3 = p.inspiredAt(3.0).pO2;
        final p4 = p.inspiredAt(4.0).pO2;
        expect(p3 - p2, closeTo(p4 - p3, 1e-12));
      },
    );

    test('supply He:N2 ratio is preserved in the loop', () {
      // Supply 21/35 trimix. He fraction of total inert (1 - FO2) is
      // preserved by the metabolism-removes-only-O2 model.
      final p = PassiveScr(
        supplyFO2: 0.21,
        supplyFHe: 0.35,
        dumpFraction: 0.3,
        rmvLpm: 20,
        vo2: 1.0,
      );
      final g = p.inspiredAt(4.0);
      final loopInert = g.pN2 + g.pHe;
      expect(g.pHe / loopInert, closeTo(0.35 / (1.0 - 0.21), 1e-9));
    });

    test('insufficient fresh-gas flow falls back to the supply mix', () {
      // Q = 15 * 0.05 = 0.75 <= VO2 1.0 -> hypoxic, no valid steady state.
      final p = PassiveScr(
        supplyFO2: 0.32,
        dumpFraction: 0.05,
        rmvLpm: 15,
        vo2: 1.0,
      );
      expect(p.hypoxicLoop, isTrue);
      expect(p.loopFO2, closeTo(0.32, 1e-12));
    });

    test('leaner supply and less fresh gas both lower the loop O2', () {
      final rich = PassiveScr(
        supplyFO2: 0.50,
        dumpFraction: 0.3,
        rmvLpm: 20,
        vo2: 1.0,
      );
      final lean = PassiveScr(
        supplyFO2: 0.40,
        dumpFraction: 0.3,
        rmvLpm: 20,
        vo2: 1.0,
      );
      expect(lean.loopFO2, lessThan(rich.loopFO2));

      final moreFresh = PassiveScr(
        supplyFO2: 0.40,
        dumpFraction: 0.4,
        rmvLpm: 20,
        vo2: 1.0,
      );
      final lessFresh = PassiveScr(
        supplyFO2: 0.40,
        dumpFraction: 0.25,
        rmvLpm: 20,
        vo2: 1.0,
      );
      expect(lessFresh.loopFO2, lessThan(moreFresh.loopFO2));
    });
  });
}
