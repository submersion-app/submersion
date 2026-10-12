import 'package:fl_chart/fl_chart.dart';

import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';

/// One spot per item, placed through [scale], with a null spot wherever two
/// neighbours sit in different periods so fl_chart lifts the pen across the
/// gap (issue #3251). [items] must be in date order.
///
/// `source[i]` is the index into [items] behind spot `i`, null for a null
/// spot, so a tap's spot index can be mapped back to its item.
({List<FlSpot> spots, List<int?> source}) spotsAcrossBreaks<T>(
  List<T> items,
  DateTime Function(T item) dateOf,
  double Function(T item) valueOf,
  TrendTimeScale scale,
) {
  final spots = <FlSpot>[];
  final source = <int?>[];
  int? lastPeriod;
  for (var i = 0; i < items.length; i++) {
    final date = dateOf(items[i]);
    final period = scale.isIdentity ? 0 : scale.periodOf(date);
    if (lastPeriod != null && period != lastPeriod) {
      spots.add(FlSpot.nullSpot);
      source.add(null);
    }
    lastPeriod = period;
    spots.add(FlSpot(scale.toAxis(date), valueOf(items[i])));
    source.add(i);
  }
  return (spots: List.unmodifiable(spots), source: List.unmodifiable(source));
}

/// The fitted line drawn only across the periods with dives: one segment per
/// period, from its first to its last date in [dates] (date order), each
/// evaluated on the one fit so the rate is unchanged.
List<FlSpot> fitAcrossBreaks(
  LinearFit fit,
  List<DateTime> dates,
  TrendTimeScale scale,
) {
  if (dates.isEmpty) return const [];
  final spots = <FlSpot>[];
  var segmentStart = dates.first;
  var previous = dates.first;
  void close() {
    if (spots.isNotEmpty) spots.add(FlSpot.nullSpot);
    spots
      ..add(FlSpot(scale.toAxis(segmentStart), fit.valueAt(segmentStart)))
      ..add(FlSpot(scale.toAxis(previous), fit.valueAt(previous)));
  }

  for (final d in dates.skip(1)) {
    if (scale.periodOf(d) != scale.periodOf(previous)) {
      close();
      segmentStart = d;
    }
    previous = d;
  }
  close();
  return spots;
}
