import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';

void main() {
  group('DiveStatsScope.predicate', () {
    test('defaults to alias d and the two descriptive rules', () {
      expect(
        DiveStatsScope.predicate(),
        'd.excluded_from_stats = 0 AND d.is_planned = 0',
      );
    });

    test('honours a custom alias on every term', () {
      expect(
        DiveStatsScope.predicate(alias: 'd2'),
        'd2.excluded_from_stats = 0 AND d2.is_planned = 0',
      );
    });

    test('the gas variant adds the gas flag and the gauge-mode rule', () {
      expect(
        DiveStatsScope.predicate(gas: true),
        'd.excluded_from_stats = 0 AND d.is_planned = 0 '
        "AND d.excluded_from_gas_stats = 0 AND d.dive_mode <> 'gauge'",
      );
    });

    test('the gas variant honours a custom alias on every term', () {
      final sql = DiveStatsScope.predicate(alias: 'dives', gas: true);
      expect(
        sql.contains('d.'),
        isFalse,
        reason: 'no term may fall back to the default alias',
      );
      expect(sql, contains('dives.excluded_from_gas_stats = 0'));
      expect(sql, contains("dives.dive_mode <> 'gauge'"));
    });

    test('the gas variant keeps rebreather dives, for gas-mix counts', () {
      expect(DiveStatsScope.predicate(gas: true), isNot(contains('ccr')));
    });

    test('the consumption-rate variant adds the rebreather rule to gas', () {
      expect(
        DiveStatsScope.predicate(consumptionRate: true),
        '${DiveStatsScope.predicate(gas: true)} '
        "AND d.dive_mode NOT IN ('ccr', 'scr')",
      );
    });

    test('the consumption-rate variant honours a custom alias', () {
      final sql = DiveStatsScope.predicate(
        alias: 'dives',
        consumptionRate: true,
      );
      expect(sql.contains('d.'), isFalse);
      expect(sql, contains("dives.dive_mode NOT IN ('ccr', 'scr')"));
      expect(sql, contains('dives.excluded_from_gas_stats = 0'));
    });
  });

  group('DiveStatsScope.and', () {
    test('prefixes the predicate for appending into an existing WHERE', () {
      expect(
        DiveStatsScope.and(),
        ' AND d.excluded_from_stats = 0 AND d.is_planned = 0',
      );
    });

    test('carries alias and gas through to the predicate', () {
      expect(
        DiveStatsScope.and(alias: 'x', gas: true),
        ' AND ${DiveStatsScope.predicate(alias: 'x', gas: true)}',
      );
    });

    test('carries the consumption-rate variant through', () {
      expect(
        DiveStatsScope.and(alias: 'x', consumptionRate: true),
        ' AND ${DiveStatsScope.predicate(alias: 'x', consumptionRate: true)}',
      );
    });

    test('never emits a bind placeholder', () {
      expect(
        DiveStatsScope.and(gas: true).contains('?'),
        isFalse,
        reason: 'callers must not have to thread params for the scope',
      );
    });
  });
}
