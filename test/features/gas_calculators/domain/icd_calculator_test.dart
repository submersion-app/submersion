import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';

IcdInputs _icdInputs({
  required double o2A,
  required double heA,
  required double o2B,
  required double heB,
}) => IcdInputs(
  gasA: IcdGasInputs(o2Percent: o2A, hePercent: heA),
  gasB: IcdGasInputs(o2Percent: o2B, hePercent: heB),
);

IcdGasInputs _gas({required double o2, required double he}) =>
    IcdGasInputs(o2Percent: o2, hePercent: he);

IcdResult _icd({
  required double o2A,
  required double heA,
  required double o2B,
  required double heB,
}) => computeIcd(
  IcdInputs(
    gasA: _gas(o2: o2A, he: heA),
    gasB: _gas(o2: o2B, he: heB),
  ),
);

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
      // Air to EAN32: no He in gas A, so the check does not apply even
      // though N2 falls (it does not rise here, but the guard must hold
      // regardless of what N2 does).
      final result = _icd(o2A: 21, heA: 0, o2B: 32, heB: 0);
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
      expect(suggestions.heBKeepingGasA, closeTo(31, 0.001));

      final applied = computeIcd(
        _icdInputs(o2A: 18, heA: 45, o2B: 32, heB: suggestions.heBKeepingGasA),
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
      expect(suggestions.heAKeepingGasB, closeTo(14, 0.001));

      final applied = computeIcd(
        _icdInputs(o2A: 18, heA: suggestions.heAKeepingGasB, o2B: 32, heB: 0),
      );
      expect(applied.n2IncreasePercent, closeTo(0, 0.001));
      expect(applied.severity, IcdSeverity.ok);
    });

    test('suggestions are clamped to a valid He% range', () {
      // Gas A (10/0, N2 90) to Gas B (90/0, N2 10): equalizing N2 on Gas B
      // would need He of 0 + 10 - 90 = -80, not a valid mix -- clamp to 0.
      final suggestions = computeIcdFixSuggestions(
        _icdInputs(o2A: 10, heA: 0, o2B: 90, heB: 0),
      );
      expect(suggestions.heBKeepingGasA, 0);
    });
  });
}
