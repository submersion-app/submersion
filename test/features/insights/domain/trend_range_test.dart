import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';

void main() {
  final start = DateTime.utc(2022, 1, 1);
  final end = DateTime.utc(2026, 1, 1);

  test('All is the whole span', () {
    final f = trendRangeFractions(TrendRange.all, start, end);
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('Last year ends at the latest dive and starts a year before', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.year1),
      start,
      end,
    );
    final full = end.difference(start).inMilliseconds;
    final expected =
        DateTime.utc(2025, 1, 1).difference(start).inMilliseconds / full;
    expect(f.end, 1);
    expect(f.start, closeTo(expected, 1e-9));
  });

  test('Last 6 months crosses a year boundary', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.months6),
      start,
      end,
    );
    final full = end.difference(start).inMilliseconds;
    final expected =
        DateTime.utc(2025, 7, 1).difference(start).inMilliseconds / full;
    expect(f.start, closeTo(expected, 1e-9));
  });

  test('a preset longer than the data shows everything', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.years5),
      start,
      end,
    );
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('a custom range inside the data maps to its fractions', () {
    final f = trendRangeFractions(
      TrendRange.custom(DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)),
      start,
      end,
    );
    final full = end.difference(start).inMilliseconds;
    expect(
      f.start,
      closeTo(DateTime.utc(2023).difference(start).inMilliseconds / full, 1e-9),
    );
    expect(
      f.end,
      closeTo(DateTime.utc(2024).difference(start).inMilliseconds / full, 1e-9),
    );
  });

  test('a custom range outside the data falls back to everything', () {
    final f = trendRangeFractions(
      TrendRange.custom(DateTime.utc(2010), DateTime.utc(2011)),
      start,
      end,
    );
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('a zero-length data span never divides by zero', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.months3),
      start,
      start,
    );
    expect(f.start, 0);
    expect(f.end, 1);
  });

  test('ranges compare by value', () {
    expect(
      TrendRange.custom(DateTime.utc(2023), DateTime.utc(2024)),
      TrendRange.custom(DateTime.utc(2023), DateTime.utc(2024)),
    );
    expect(
      const TrendRange.preset(TrendRangePreset.year1),
      isNot(TrendRange.all),
    );
  });
}
