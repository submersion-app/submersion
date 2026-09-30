import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/explore_clause_lowering.dart';
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  const metric = UnitPrefs(
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
  );
  final now = DateTime(2026, 9, 30);

  LoweredClause lower(ParsedSubject s, String field, String op, Object value) {
    final c = QueryClause(
      field: field,
      op: ClauseOp.values.firstWhere((o) => o.jsonName == op),
      value: value,
      text: '$field $op $value',
    );
    return lowerClause(c, exploreFieldFor(s, field)!.field, metric, now: now);
  }

  ConditionNode cond(String key, QueryOp op, QueryValue v) =>
      ConditionNode(FieldPath([key]), op, v);

  group('date fields take a time phrase', () {
    test('before a year is before its first day', () {
      final r = lower(ParsedSubject.sites, 'lastDived', 'lt', '2022');
      expect(r.error, isNull);
      expect(r.nodes, [
        cond('lastDived', QueryOp.lt, DateValue(DateTime(2022))),
      ]);
    });

    test('a bare number year reads as the year', () {
      final r = lower(ParsedSubject.sites, 'lastDived', 'lt', 2022);
      expect(r.nodes, [
        cond('lastDived', QueryOp.lt, DateValue(DateTime(2022))),
      ]);
    });

    test('after a year is after its last day', () {
      final r = lower(ParsedSubject.species, 'firstSeen', 'gt', '2023');
      expect(r.nodes, [
        cond('firstSeen', QueryOp.gt, DateValue(DateTime(2023, 12, 31))),
      ]);
    });

    test('eq is within the period', () {
      final r = lower(ParsedSubject.species, 'lastSeen', 'eq', 'last year');
      expect(r.nodes, [
        cond('lastSeen', QueryOp.gte, DateValue(DateTime(2025))),
        cond('lastSeen', QueryOp.lte, DateValue(DateTime(2025, 12, 31))),
      ]);
    });

    test('words the date grammar cannot read are unplaced', () {
      final r = lower(ParsedSubject.sites, 'lastDived', 'lt', 'ages ago');
      expect(r.error, 'unknownTime');
    });
  });

  group('days count forward from today', () {
    test('within 30 days bounds the next due date', () {
      final r = lower(ParsedSubject.equipment, 'serviceDueWithin', 'lte', 30);
      expect(r.nodes, [
        cond('nextServiceDue', QueryOp.lte, DateValue(DateTime(2026, 10, 30))),
      ]);
      expect(r.chip!.value, 30);
    });

    test('a negative or huge number of days is out of range', () {
      expect(
        lower(ParsedSubject.equipment, 'serviceDueWithin', 'lte', -3).error,
        'outOfRange',
      );
      expect(
        lower(ParsedSubject.equipment, 'serviceDueWithin', 'lte', 5000).error,
        'outOfRange',
      );
    });

    test('more than N days is not a due window', () {
      expect(
        lower(ParsedSubject.equipment, 'serviceDueWithin', 'gt', 30).error,
        'invalid',
      );
    });
  });

  group('a dive count is strict', () {
    test('more than twice is at least three', () {
      final r = lower(ParsedSubject.centers, 'diveCount', 'gt', 2);
      expect(r.nodes, [
        cond('diveCount', QueryOp.gte, const NumberValue(3, null)),
      ]);
      expect(r.chip!.op, ClauseOp.gte);
      expect(r.chip!.value, 3);
    });

    test('fewer than three is at most two', () {
      final r = lower(ParsedSubject.species, 'diveCount', 'lt', 3);
      expect(r.nodes, [
        cond('diveCount', QueryOp.lte, const NumberValue(2, null)),
      ]);
    });

    test('exactly once stays exact', () {
      final r = lower(ParsedSubject.species, 'diveCount', 'eq', 1);
      expect(r.nodes, [
        cond('diveCount', QueryOp.gte, const NumberValue(1, null)),
        cond('diveCount', QueryOp.lte, const NumberValue(1, null)),
      ]);
    });
  });

  test('a site depth grounds the unit on the site max depth', () {
    final r = lowerClause(
      const QueryClause(
        field: 'depth',
        op: ClauseOp.gt,
        value: 100,
        unit: ClauseUnit.ft,
        text: 'deeper than 100 ft',
      ),
      exploreFieldFor(ParsedSubject.sites, 'depth')!.field,
      metric,
      now: now,
    );
    expect(r.nodes, [
      cond('maxDepth', QueryOp.gte, const NumberValue(30.48, null)),
    ]);
  });
}
