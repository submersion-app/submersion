import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_window_seater.dart';

void main() {
  final dates = [
    DateTime.utc(2013, 1, 1),
    DateTime.utc(2013, 7, 1),
    DateTime.utc(2014, 1, 1),
    DateTime.utc(2020, 1, 1),
    DateTime.utc(2020, 7, 1),
    DateTime.utc(2021, 1, 1),
  ];
  final collapsed = TrendTimeScale.build(dates, TrendGapThreshold.year1);
  const identity = TrendTimeScale.identity;

  ChartViewport seat(TrendWindowSeater s, TrendRange r, TrendTimeScale scale) =>
      s.seat(
        r,
        ChartViewport.reset,
        scale.toAxis(dates.first),
        scale.toAxis(dates.last),
        scale: scale,
      );

  test('a custom range reports back the same dates through a scale', () {
    final seater = TrendWindowSeater();
    final range = TrendRange.custom(
      DateTime.utc(2020, 2, 1),
      DateTime.utc(2020, 10, 1),
    );
    final vp = seat(seater, range, collapsed);
    final moved = vp.pannedBy(0.0001, 0);
    final reported = seater.report(moved)!;
    expect(
      reported.start!.difference(range.start!).inDays.abs(),
      lessThanOrEqualTo(1),
    );
    expect(
      reported.end!.difference(range.end!).inDays.abs(),
      lessThanOrEqualTo(1),
    );
  });

  test('changing the threshold keeps a custom window on its dates', () {
    final seater = TrendWindowSeater();
    final range = TrendRange.custom(
      DateTime.utc(2020, 2, 1),
      DateTime.utc(2020, 10, 1),
    );
    seat(seater, range, identity);
    final vp = seat(seater, range, collapsed);
    final full = collapsed.toAxis(dates.last) - collapsed.toAxis(dates.first);
    final shownStart = collapsed.toDate(
      collapsed.toAxis(dates.first) + vp.windowStart * full,
    );
    expect(shownStart.difference(range.start!).inHours.abs(), lessThan(24));
  });

  test('an identity scale seats exactly as before', () {
    const range = TrendRange.preset(TrendRangePreset.year1);
    final a = TrendWindowSeater().seat(
      range,
      ChartViewport.reset,
      identity.toAxis(dates.first),
      identity.toAxis(dates.last),
    );
    final b = seat(TrendWindowSeater(), range, identity);
    expect(b.sameWindowAs(a), isTrue);
  });
}
