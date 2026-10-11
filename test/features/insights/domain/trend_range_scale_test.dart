import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';

void main() {
  final first = DateTime.utc(2013, 1, 1);
  final gapStart = DateTime.utc(2014, 1, 1);
  final gapEnd = DateTime.utc(2020, 1, 1);
  final last = DateTime.utc(2021, 1, 1);
  final scale = TrendTimeScale.build([
    first,
    DateTime.utc(2013, 7, 1),
    gapStart,
    gapEnd,
    DateTime.utc(2020, 7, 1),
    last,
  ], TrendGapThreshold.year1);

  test('the identity toAxis leaves the fractions unchanged', () {
    const range = TrendRange.preset(TrendRangePreset.year1);
    final a = trendRangeFractions(range, first, last);
    final b = trendRangeFractions(
      range,
      first,
      last,
      toAxis: TrendTimeScale.identity.toAxis,
    );
    expect(b, a);
  });

  test('last year of a collapsed axis is about half of it', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.year1),
      first,
      last,
      toAxis: scale.toAxis,
    );
    // Two one-year periods and a gap region (band and margins) of 7% of
    // them: the last year starts just past the middle, not at 7/8 as it
    // would on the real-time axis.
    expect(f.start, closeTo(0.53, 0.02));
    expect(f.end, 1.0);
  });

  test('a preset that starts inside the gap opens inside its region', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.years2),
      first,
      last,
      toAxis: scale.toAxis,
    );
    final full = scale.toAxis(last) - scale.toAxis(first);
    final startX = scale.toAxis(first) + f.start * full;
    expect(startX, greaterThan(scale.toAxis(gapStart)));
    expect(startX, lessThan(scale.toAxis(gapEnd)));
  });
}
