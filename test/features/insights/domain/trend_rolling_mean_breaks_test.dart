import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

List<TrendDataPoint> run(DateTime from, int n, double value) => [
  for (var i = 0; i < n; i++)
    TrendDataPoint(
      date: from.add(Duration(days: i * 3)),
      value: value,
    ),
];

void main() {
  final before = run(DateTime.utc(2013, 1, 1), 30, 10);
  final after = run(DateTime.utc(2020, 1, 1), 30, 50);
  int periodOf(DateTime d) => d.year < 2020 ? 0 : 1;

  test('without periods the window mixes both sides of the gap', () {
    final smoothed = rollingMean([...before, ...after]);
    expect(smoothed[29].value, greaterThan(10));
    expect(smoothed[30].value, lessThan(50));
  });

  test('with periods no window reaches across the gap', () {
    final smoothed = rollingMean([...after, ...before], periodOf: periodOf);
    expect(smoothed, hasLength(60));
    for (final p in smoothed) {
      expect(p.value, p.date.year < 2020 ? 10 : 50);
    }
  });

  test('a short period averages only its own dives', () {
    final lone = TrendDataPoint(date: DateTime.utc(2020, 1, 1), value: 99);
    final smoothed = rollingMean([...before, lone], periodOf: periodOf);
    expect(smoothed.last.value, 99);
  });

  test('one period is the same as no periods', () {
    final a = rollingMean(before);
    final b = rollingMean(before, periodOf: (_) => 0);
    expect([for (final p in b) p.value], [for (final p in a) p.value]);
  });
}
