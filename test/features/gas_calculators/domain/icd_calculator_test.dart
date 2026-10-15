import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';

IcdInputs _icdInputs({
  required double o2A,
  required double heA,
  required double o2B,
  required double heB,
}) => IcdInputs(
  gasA: GasMix(o2: o2A, he: heA),
  gasB: GasMix(o2: o2B, he: heB),
);

IcdResult _icd({
  required double o2A,
  required double heA,
  required double o2B,
  required double heB,
}) => computeIcd(_icdInputs(o2A: o2A, heA: heA, o2B: o2B, heB: heB));

void main() {
  group('computeIcd', () {
    test('Tx 20/25 to EAN32 violates the rule of fifths', () {
      // He falls 25 -> 0 (decrease 25), N2 rises 55 -> 68 (increase 13).
      // Allowed increase is 25 / 5 = 5, far below the actual 13.
      final result = _icd(o2A: 20, heA: 25, o2B: 32, heB: 0);
      expect(result.heDecreasePercent, closeTo(25, 0.001));
      expect(result.n2IncreasePercent, closeTo(13, 0.001));
      expect(result.maxAllowedN2IncreasePercent, closeTo(5, 0.001));
      expect(result.severity, IcdSeverity.violation);
    });

    test('a starting gas without helium never triggers the rule', () {
      // EAN32 to air: N2 rises 68 -> 79, but with no He in gas A there is
      // nothing to counterdiffuse against, so the check does not apply.
      final result = _icd(o2A: 32, heA: 0, o2B: 21, heB: 0);
      expect(result.n2IncreasePercent, closeTo(11, 0.001));
      expect(result.maxAllowedN2IncreasePercent, 0);
      expect(result.severity, IcdSeverity.ok);
    });

    test('switching to a more helium-rich gas is never flagged', () {
      final result = _icd(o2A: 21, heA: 0, o2B: 18, heB: 45);
      expect(result.severity, IcdSeverity.ok);
    });

    test('helium unchanged keeps the result ok regardless of N2', () {
      final result = _icd(o2A: 18, heA: 40, o2B: 30, heB: 40);
      expect(result.heDecreasePercent, 0);
      expect(result.severity, IcdSeverity.ok);
    });

    test(
      'N2 increase exactly at the allowed maximum is caution, not a violation',
      () {
        // Gas A (20/25): N2 = 55. He falls 25 -> 0 (decrease 25), so the
        // allowed N2 increase is 5 -> N2 rises to exactly 60 (O2 40, He 0).
        // Right at the edge of what the rule allows, so it reads as a
        // cautious pass rather than a comfortable one.
        final result = _icd(o2A: 20, heA: 25, o2B: 40, heB: 0);
        expect(result.n2IncreasePercent, closeTo(5, 0.001));
        expect(result.maxAllowedN2IncreasePercent, closeTo(5, 0.001));
        expect(result.severity, IcdSeverity.caution);
      },
    );

    test(
      'N2 increase just above the caution threshold is caution, not a violation',
      () {
        // Allowed increase is 5; 90% of that is 4.5, comfortably below 5 but
        // above the 80% caution threshold.
        final result = _icd(o2A: 20, heA: 25, o2B: 40.5, heB: 0);
        expect(result.n2IncreasePercent, closeTo(4.5, 0.001));
        expect(result.severity, IcdSeverity.caution);
      },
    );

    test('N2 decreasing alongside He is never flagged', () {
      final result = _icd(o2A: 18, heA: 40, o2B: 50, heB: 10);
      expect(result.n2IncreasePercent, lessThan(0));
      expect(result.severity, IcdSeverity.ok);
    });

    test('n2Percent is derived as 100 - O2 - He', () {
      final result = _icd(o2A: 18, heA: 40, o2B: 32, heB: 0);
      expect(result.n2PercentA, closeTo(42, 0.001));
      expect(result.n2PercentB, closeTo(68, 0.001));
    });
  });

  group('computeIcdFixSuggestions', () {
    test('keeping Gas A: suggests the He% on Gas B that equalizes N2', () {
      // Gas A (18/45): N2 = 37. Gas B keeps O2 32; He that gives N2 37
      // too is 100 - 32 - 37 = 31.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 18, heA: 45, o2B: 32, heB: 0),
      );
      expect(suggestions.heBKeepingGasA.value, closeTo(31, 0.001));
      expect(suggestions.heBKeepingGasA.resolves, isTrue);

      final applied = computeIcd(
        _icdInputs(
          o2A: 18,
          heA: 45,
          o2B: 32,
          heB: suggestions.heBKeepingGasA.value,
        ),
      );
      expect(applied.n2IncreasePercent, closeTo(0, 0.001));
      expect(applied.severity, IcdSeverity.ok);
    });

    test('keeping Gas B: suggests the He% on Gas A that equalizes N2', () {
      // Gas B (32/0): N2 = 68. Gas A keeps O2 18; He that gives N2 68
      // too is 100 - 18 - 68 = 14.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 18, heA: 45, o2B: 32, heB: 0),
      );
      expect(suggestions.heAKeepingGasB.value, closeTo(14, 0.001));
      expect(suggestions.heAKeepingGasB.resolves, isTrue);

      final applied = computeIcd(
        _icdInputs(
          o2A: 18,
          heA: suggestions.heAKeepingGasB.value,
          o2B: 32,
          heB: 0,
        ),
      );
      expect(applied.n2IncreasePercent, closeTo(0, 0.001));
      expect(applied.severity, IcdSeverity.ok);
    });

    test('He suggestions are clamped to a valid He% range', () {
      // Gas A (10/0, N2 90) to Gas B (90/0, N2 10): equalizing N2 on Gas B
      // would need He of 0 + 10 - 90 = -80, not a valid mix, so clamp to 0.
      // Clamping He to 0 always leaves no helium to counterdiffuse against
      // on that side, so the rule no longer applies at all -- the clamped
      // suggestion still resolves, just not by matching N2 exactly.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 10, heA: 0, o2B: 90, heB: 0),
      );
      expect(suggestions.heBKeepingGasA.value, 0);
      expect(suggestions.heBKeepingGasA.resolves, isTrue);
    });

    test('keeping Gas B: suggests the O2% on Gas A that equalizes N2', () {
      // Matches an independently computed reference spreadsheet for the
      // same Tx 25/50 (Gas A) -> Tx 50/20 (Gas B) pair ("BO für Deko, He
      // führend"): O2(A) = O2(B) + He(B) - He(A) = 50 + 20 - 50 = 20.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 25, heA: 50, o2B: 50, heB: 20),
      );
      expect(suggestions.o2AKeepingGasB.value, closeTo(20, 0.001));

      final applied = computeIcd(
        _icdInputs(
          o2A: suggestions.o2AKeepingGasB.value,
          heA: 50,
          o2B: 50,
          heB: 20,
        ),
      );
      expect(applied.n2IncreasePercent, closeTo(0, 0.001));
    });

    test('keeping Gas A: suggests the O2% on Gas B that equalizes N2', () {
      // Same reference pair ("Deko für BO, He führend"):
      // O2(B) = O2(A) + He(A) - He(B) = 25 + 50 - 20 = 55.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 25, heA: 50, o2B: 50, heB: 20),
      );
      expect(suggestions.o2BKeepingGasA.value, closeTo(55, 0.001));

      final applied = computeIcd(
        _icdInputs(
          o2A: 25,
          heA: 50,
          o2B: suggestions.o2BKeepingGasA.value,
          heB: 20,
        ),
      );
      expect(applied.n2IncreasePercent, closeTo(0, 0.001));
    });

    test('o2AKeepingGasB can be clamped without resolving the violation', () {
      // Gas A (5/90, N2 5) to Gas B (5/80, N2 15): He falls 90 -> 80
      // (decrease 10), N2 rises 5 -> 15 (increase 10), far above the
      // allowed 10/5 = 2 -- a violation. Equalizing N2 on Gas A would
      // need O2 = 5 + 80 - 90 = -5, clamped to 0. Unlike a clamped He
      // suggestion, this does not touch He, so the rule still applies:
      // Gas A's N2 only falls to 10, still 5 above Gas B's 15 minus the
      // allowed 2 -- the clamped suggestion does not actually resolve it.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 5, heA: 90, o2B: 5, heB: 80),
      );
      expect(suggestions.o2AKeepingGasB.value, 0);
      expect(suggestions.o2AKeepingGasB.resolves, isFalse);
    });

    test('o2BKeepingGasA always resolves, even at the clamp', () {
      // Gas A (5/10, N2 85) to Gas B (0/20, N2 80): not a real violation
      // (He actually rises here, chosen purely to force the clamp) --
      // He(B) 20 exceeds O2(A)+He(A) 15, so the raw O2(B) = 5+10-20 = -5
      // clamps to 0. That clamp always coincides with He(B) > He(A), so
      // heDecrease (He(A) - He(B)) is forced negative, which disables the
      // rule itself -- the same mechanism that makes a clamped He
      // suggestion always resolve. A real violation (heDecrease > 0)
      // never reaches this clamp in the first place: see
      // o2AKeepingGasB's doc comment for the asymmetric counterpart.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 5, heA: 10, o2B: 0, heB: 20),
      );
      expect(suggestions.o2BKeepingGasA.value, 0);
      expect(suggestions.o2BKeepingGasA.resolves, isTrue);
    });

    test('a suggestion that only reaches caution still counts as resolved', () {
      // Gas A (5/6, N2 89) to Gas B (5/0, N2 95): He falls 6 -> 0
      // (decrease 6), N2 rises 89 -> 95 (increase 6), far above the
      // allowed 6/5 = 1.2 -- a violation. Equalizing N2 on Gas A via O2
      // would need O2 = 5 + 0 - 6 = -1, clamped to 0: N2(A) falls only to
      // 94, leaving a 1% increase against Gas B's 95 -- above the allowed
      // 1.2 threshold's caution band (0.96) but not above 1.2 itself, so
      // the result reads as a caution, not a violation. The widget itself
      // treats a caution as already compliant, so this must count as
      // resolved too, not just an exact match down to ok (Copilot review
      // on PR #3372).
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 5, heA: 6, o2B: 5, heB: 0),
      );
      expect(suggestions.o2AKeepingGasB.value, 0);
      expect(suggestions.o2AKeepingGasB.resolves, isTrue);

      final applied = computeIcd(
        _icdInputs(
          o2A: suggestions.o2AKeepingGasB.value,
          heA: 6,
          o2B: 5,
          heB: 0,
        ),
      );
      expect(applied.severity, IcdSeverity.caution);
    });
  });
}
