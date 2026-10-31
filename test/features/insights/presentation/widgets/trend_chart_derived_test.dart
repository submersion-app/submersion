import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_axis.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_break_spots.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_derived.dart';

TrendDataPoint dive(DateTime date, double value, [String? id]) =>
    TrendDataPoint(date: date, value: value, diveId: id);

List<TrendDataPoint> run(DateTime from, int n, {double base = 10}) => [
  for (var i = 0; i < n; i++)
    dive(from.add(Duration(days: i * 2)), base + i, '${from.year}-$i'),
];

void main() {
  final early = run(DateTime.utc(2019, 1, 7), 8);
  final late = run(DateTime.utc(2022, 1, 3), 8, base: 30);
  final both = [...early, ...late];

  group('buckets', () {
    test('sorted per dive, whatever the input order', () {
      final derived = TrendChartDerived.compute(points: both.reversed.toList());
      expect(derived.buckets, hasLength(16));
      expect(derived.buckets.first.diveId, early.first.diveId);
      expect(derived.buckets.last.diveId, late.last.diveId);
      expect(derived.firstDate, early.first.date);
      expect(derived.lastDate, late.last.date);
    });

    test('each secondary is bucketed like the primary', () {
      final derived = TrendChartDerived.compute(
        points: early,
        secondary: [late],
        aggregation: TrendAggregation.monthly,
      );
      expect(derived.buckets, hasLength(1));
      expect(derived.secondary.single, hasLength(1));
      expect(derived.allBuckets, hasLength(2));
    });

    test('bounds span the secondaries when the primary is empty', () {
      final derived = TrendChartDerived.compute(
        points: const [],
        secondary: [late, early],
      );
      expect(derived.buckets, isEmpty);
      expect(derived.firstDate, early.first.date);
      expect(derived.lastDate, late.last.date);
    });
  });

  group('scale', () {
    test('identity with gaps off', () {
      final derived = TrendChartDerived.compute(points: both);
      expect(derived.scale.isIdentity, isTrue);
    });

    test('collapses a long gap', () {
      final derived = TrendChartDerived.compute(
        points: both,
        gapThreshold: TrendGapThreshold.year1,
      );
      expect(derived.scale.breaks, hasLength(1));
    });

    test('an aggregated chart scales over raw dates too', () {
      // The scale reads the buckets and the dives, so a bucket dated the 1st
      // cannot land inside a band that starts at the month's first dive.
      final points = [...early, ...late];
      final derived = TrendChartDerived.compute(
        points: points,
        aggregation: TrendAggregation.monthly,
        gapThreshold: TrendGapThreshold.year1,
      );
      final expected = TrendTimeScale.build([
        for (final b in aggregate(points, TrendAggregation.monthly)) b.date,
        for (final p in points) p.date,
      ], TrendGapThreshold.year1);
      expect(derived.scale.breaks.single.start, expected.breaks.single.start);
      expect(derived.scale.breaks.single.end, expected.breaks.single.end);
    });
  });

  group('fits', () {
    test('neither runs unless asked for', () {
      final derived = TrendChartDerived.compute(points: both);
      expect(derived.smoothed, isEmpty);
      expect(derived.fit, isNull);
      expect(derived.fitSpots, isEmpty);
      expect(derived.smoothedSpots, isEmpty);
    });

    test('the rolling mean respects the periods of the scale', () {
      final derived = TrendChartDerived.compute(
        points: both,
        gapThreshold: TrendGapThreshold.year1,
        showRollingMean: true,
      );
      final expected = rollingMean(both, periodOf: derived.scale.periodOf);
      expect(derived.smoothed.map((p) => p.value), [
        for (final p in expected) p.value,
      ]);
      expect(derived.smoothedSpots, contains(FlSpot.nullSpot));
    });

    test('both read the raw dives, not the buckets', () {
      final derived = TrendChartDerived.compute(
        points: both,
        aggregation: TrendAggregation.monthly,
        showRollingMean: true,
        showLinearFit: true,
      );
      final fit = linearFit(both)!;
      expect(derived.smoothed, hasLength(both.length));
      expect(derived.fit!.slopePerDay, fit.slopePerDay);
      expect(derived.fit!.intercept, fit.intercept);
    });

    test('no fit over an empty primary, however many secondaries', () {
      final derived = TrendChartDerived.compute(
        points: const [],
        secondary: [both],
        showLinearFit: true,
      );
      expect(derived.fit, isNull);
      expect(derived.fitSpots, isEmpty);
    });

    test('the fit is drawn across the periods with dives', () {
      final derived = TrendChartDerived.compute(
        points: both,
        gapThreshold: TrendGapThreshold.year1,
        showLinearFit: true,
      );
      final expected = fitAcrossBreaks(derived.fit!, [
        for (final b in derived.buckets) b.date,
      ], derived.scale);
      expect(derived.fitSpots, expected);
      expect(derived.fitSpots, contains(FlSpot.nullSpot));
    });
  });

  group('y axis', () {
    test('matches an axis over every drawn value', () {
      final derived = TrendChartDerived.compute(
        points: both,
        showRollingMean: true,
        showLinearFit: true,
      );
      final fit = derived.fit!;
      final expected = ChartAxis.forTrend([
        ...derived.allBuckets.expand((b) => [b.min, b.max]),
        ...derived.smoothed.map((p) => p.value),
        fit.valueAt(derived.firstDate),
        fit.valueAt(derived.lastDate),
      ]);
      expect(derived.yAxis.min, expected.min);
      expect(derived.yAxis.max, expected.max);
      expect(derived.yAxis.interval, expected.interval);
    });

    test('takes in a reference value outside the data', () {
      final plain = TrendChartDerived.compute(points: both);
      final marked = TrendChartDerived.compute(
        points: both,
        referenceValue: 500,
      );
      expect(plain.yAxis.max, lessThan(500));
      expect(marked.yAxis.max, greaterThanOrEqualTo(500));
    });
  });

  group('spots', () {
    test('per dive: one spot each, a pen lift at a break, no band bounds', () {
      final derived = TrendChartDerived.compute(
        points: both,
        gapThreshold: TrendGapThreshold.year1,
      );
      expect(derived.primary.spots, hasLength(17));
      expect(derived.primary.spots[8], FlSpot.nullSpot);
      expect(derived.primary.source[8], isNull);
      expect(derived.primary.source[9], 8);
      expect(derived.lowSpots, isEmpty);
      expect(derived.highSpots, isEmpty);
    });

    test('aggregated: the band bounds track each bucket', () {
      final derived = TrendChartDerived.compute(
        points: both,
        aggregation: TrendAggregation.monthly,
      );
      expect(derived.lowSpots.map((s) => s.y), [
        for (final b in derived.buckets) b.min,
      ]);
      expect(derived.highSpots.map((s) => s.y), [
        for (final b in derived.buckets) b.max,
      ]);
    });

    test('each secondary keeps its own spots and source', () {
      final derived = TrendChartDerived.compute(
        points: early,
        secondary: [late],
      );
      expect(derived.secondaryPlaced.single.spots, hasLength(late.length));
      expect(derived.secondaryPlaced.single.source.last, late.length - 1);
    });
  });
}
