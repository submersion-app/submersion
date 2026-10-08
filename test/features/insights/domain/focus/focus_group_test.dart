import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_group.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

TrendDataPoint p(String id, int day, double value) =>
    TrendDataPoint(date: DateTime.utc(2025, 1, day), value: value, diveId: id);

void main() {
  final series = [
    p('a', 1, 20),
    p('b', 2, 14),
    p('c', 3, 18),
    p('d', 4, 14),
    p('e', 5, 25),
  ];

  test('lowest N takes the smallest values, ties newest first', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.lowest, count: 2),
    );
    expect(group.members.map((m) => m.diveId), ['d', 'b']);
  });

  test('highest N takes the largest values', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.highest, count: 2),
    );
    expect(group.members.map((m) => m.diveId), ['e', 'a']);
  });

  test('N beyond the data returns every dive', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.lowest, count: 50),
    );
    expect(group.members, hasLength(5));
  });

  test('above is strictly greater, newest first', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.above, threshold: 18),
    );
    expect(group.members.map((m) => m.diveId), ['e', 'a']);
  });

  test('below is strictly less', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.below, threshold: 18),
    );
    expect(group.members.map((m) => m.diveId), ['d', 'b']);
  });

  test('a threshold mode without a threshold selects nothing', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.above),
    );
    expect(group.members, isEmpty);
    expect(group.population, hasLength(5));
  });

  test('points with no dive behind them are left out', () {
    final group = selectFocusGroup([
      ...series,
      TrendDataPoint(date: DateTime.utc(2025), value: 1),
    ], const FocusSelection(mode: FocusMode.lowest, count: 1));
    expect(group.population, hasLength(5));
    expect(group.members.single.diveId, anyOf('b', 'd'));
  });

  test('means and range describe the group and the population', () {
    final group = selectFocusGroup(
      series,
      const FocusSelection(mode: FocusMode.lowest, count: 2),
    );
    expect(group.memberMean, 14);
    expect(group.populationMean, closeTo(18.2, 1e-9));
    expect(group.populationMin, 14);
    expect(group.populationMax, 25);
  });

  test('only gas consumption has a better end', () {
    expect(FocusMetric.rmv.lowerIsBetter, isTrue);
    expect(FocusMetric.sac.lowerIsBetter, isTrue);
    expect(FocusMetric.maxDepth.lowerIsBetter, isFalse);
  });

  test('copyWith can clear the threshold', () {
    const s = FocusSelection(mode: FocusMode.above, threshold: 1);
    expect(s.copyWith(clearThreshold: true).threshold, isNull);
    expect(s.copyWith(count: 5).threshold, 1);
  });
}
