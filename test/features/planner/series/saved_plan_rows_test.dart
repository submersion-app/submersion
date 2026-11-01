import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/utils/saved_plan_rows.dart';

void main() {
  DivePlanSummary plan(
    String id, {
    String? series,
    int? index,
    double? depth,
    int? runtime,
  }) => DivePlanSummary(
    id: id,
    name: 'Reef day',
    updatedAt: DateTime(2026, 10, 27),
    seriesId: series,
    seriesIndex: index,
    maxDepth: depth,
    runtimeSeconds: runtime,
  );

  test('an ordinary plan is its own row', () {
    final rows = collapseSeries([plan('a'), plan('b')]);

    expect(rows.map((r) => r.plan.id), ['a', 'b']);
    expect(rows.first.isSeries, isFalse);
    expect(rows.first.showsDives, isFalse);
  });

  test('a series is one row, its dives in order wherever they were', () {
    final rows = collapseSeries([
      plan('c', series: 's', index: 2),
      plan('solo'),
      plan('a', series: 's', index: 0),
      plan('b', series: 's', index: 1),
    ]);

    expect(rows.map((r) => r.plan.id), ['a', 'solo']);
    expect(rows.first.dives.map((d) => d.id), ['a', 'b', 'c']);
    expect(rows.first.isSeries, isTrue);
    expect(rows.first.showsDives, isTrue);
  });

  test('a single followed dive is a series that lists no dives', () {
    final rows = collapseSeries([plan('a', series: 's', index: 0)]);

    expect(rows.single.isSeries, isTrue);
    expect(rows.single.showsDives, isFalse);
  });

  test('a single plan in the log lists its one dive, to link to it', () {
    final linked = DivePlanSummary(
      id: 'a',
      name: 'Solo',
      updatedAt: DateTime(2026, 10, 27),
      linkedDiveId: 'entry',
    );
    final row = collapseSeries([linked]).single;

    expect(row.hasSeveralDives, isFalse);
    expect(row.showsDives, isTrue);
  });

  test('a series row has its deepest dive and total runtime', () {
    final row = collapseSeries([
      plan('a', series: 's', index: 0, depth: 30, runtime: 2400),
      plan('b', series: 's', index: 1, depth: 18, runtime: 3000),
      plan('c', series: 's', index: 2),
    ]).single;

    expect(row.maxDepth, 30);
    expect(row.runtimeSeconds, 5400);
  });

  test('a row with no summaries has no totals', () {
    final row = collapseSeries([plan('a')]).single;

    expect(row.maxDepth, isNull);
    expect(row.runtimeSeconds, isNull);
  });
}
