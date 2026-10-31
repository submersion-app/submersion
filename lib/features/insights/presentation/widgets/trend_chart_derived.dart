import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_axis.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_break_spots.dart';

/// Everything a trend chart draws that follows from its data alone, computed
/// together so no part can disagree with another.
///
/// Pan and zoom rebuild the chart on every pointer move and change none of
/// this (issue #3858): only the visible window and the date axis follow the
/// viewport. Bars stay outside because they carry theme colours and cost next
/// to nothing to build from spots that already exist.
@immutable
class TrendChartDerived {
  const TrendChartDerived._({
    required this.buckets,
    required this.secondary,
    required this.allBuckets,
    required this.scale,
    required this.firstDate,
    required this.lastDate,
    required this.fit,
    required this.yAxis,
    required this.primary,
    required this.lowSpots,
    required this.highSpots,
    required this.smoothedSpots,
    required this.fitSpots,
    required this.secondaryPlaced,
  });

  /// [points] and each of [secondary] are raw per-dive series, in any order;
  /// at least one must hold a point. [referenceValue] is a marker the y axis
  /// has to reach.
  factory TrendChartDerived.compute({
    required List<TrendDataPoint> points,
    List<List<TrendDataPoint>> secondary = const [],
    TrendAggregation aggregation = TrendAggregation.none,
    TrendGapThreshold gapThreshold = TrendGapThreshold.off,
    bool showRollingMean = false,
    bool showLinearFit = false,
    double? referenceValue,
  }) {
    final raw = aggregation == TrendAggregation.none;
    final buckets = aggregate(points, aggregation);
    final secondaryBuckets = [
      for (final s in secondary) aggregate(s, aggregation),
    ];
    // The x range spans every drawn bucket; the primary may be empty when
    // the secondaries carry the data.
    final allBuckets = [...buckets, ...secondaryBuckets.expand((b) => b)];
    // Every plotted date feeds the scale, so no point (a month bucket dated
    // the 1st included) can land inside a band. Per dive, every bucket is a
    // dive, so the bucket dates are the lot.
    final scale = TrendTimeScale.build([
      for (final b in allBuckets) b.date,
      if (!raw) ...[
        for (final p in points) p.date,
        for (final s in secondary)
          for (final p in s) p.date,
      ],
    ], gapThreshold);

    var firstDate = allBuckets.first.date;
    var lastDate = firstDate;
    for (final b in allBuckets) {
      if (b.date.isBefore(firstDate)) firstDate = b.date;
      if (b.date.isAfter(lastDate)) lastDate = b.date;
    }

    // Both fits read the RAW dives, never the buckets. Fitting over monthly
    // means would smooth twice, and the line would visibly move when the
    // dropdown changed, implying the underlying trend had changed when only
    // the drawing did.
    final smoothed = showRollingMean
        ? rollingMean(
            points,
            periodOf: scale.isIdentity ? null : scale.periodOf,
          )
        : const <TrendDataPoint>[];
    final fit = showLinearFit ? linearFit(points) : null;

    // The fits can run outside the bucket range, so the axis has to see them.
    final yAxis = ChartAxis.forTrend(<double>[
      ...allBuckets.expand((b) => [b.min, b.max]),
      ...smoothed.map((p) => p.value),
      if (fit != null) ...[fit.valueAt(firstDate), fit.valueAt(lastDate)],
      // A threshold outside the data would otherwise sit off the plot.
      ?referenceValue,
    ]);

    PlacedSpots place(
      List<TrendBucket> series,
      double Function(TrendBucket) valueOf,
    ) => spotsAcrossBreaks(series, (b) => b.date, valueOf, scale);

    return TrendChartDerived._(
      buckets: buckets,
      secondary: secondaryBuckets,
      allBuckets: allBuckets,
      scale: scale,
      firstDate: firstDate,
      lastDate: lastDate,
      fit: fit,
      yAxis: yAxis,
      primary: place(buckets, (b) => b.mean),
      lowSpots: raw ? const [] : place(buckets, (b) => b.min).spots,
      highSpots: raw ? const [] : place(buckets, (b) => b.max).spots,
      smoothedSpots: spotsAcrossBreaks(
        smoothed,
        (p) => p.date,
        (p) => p.value,
        scale,
      ).spots,
      // One fit, drawn only across the periods with dives, so it steps at a
      // band rather than sloping through years with no dives.
      fitSpots: fit == null
          ? const []
          : fitAcrossBreaks(fit, [for (final b in buckets) b.date], scale),
      secondaryPlaced: [
        for (final s in secondaryBuckets) place(s, (b) => b.mean),
      ],
    );
  }

  /// The primary's buckets, in date order, so a tap can resolve its dive.
  final List<TrendBucket> buckets;

  /// Each secondary's buckets, parallel to [secondaryPlaced].
  final List<List<TrendBucket>> secondary;

  /// Every drawn bucket of every series. Not in date order.
  final List<TrendBucket> allBuckets;

  final TrendTimeScale scale;

  /// The earliest and latest drawn bucket.
  final DateTime firstDate;
  final DateTime lastDate;

  /// The linear fit; null when off, below the minimum for a fit, or when
  /// every point shares one date.
  final LinearFit? fit;

  final ChartAxis yAxis;

  final PlacedSpots primary;

  /// The bucket bounds the spread band fills between; empty per dive.
  final List<FlSpot> lowSpots;
  final List<FlSpot> highSpots;

  /// The rolling mean; empty when off or below the minimum for a fit.
  final List<FlSpot> smoothedSpots;

  final List<FlSpot> fitSpots;

  final List<PlacedSpots> secondaryPlaced;
}
