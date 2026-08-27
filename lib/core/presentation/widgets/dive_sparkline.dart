import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// An additional depth series drawn alongside [DiveSparkline.profile] on the
/// same chart (and therefore the same time/depth axes) -- e.g. one line per
/// source dive when previewing a multi-computer consolidation.
class DiveSparklineSeries {
  const DiveSparklineSeries({required this.profile, required this.color});

  final List<DiveProfilePoint> profile;
  final Color color;
}

/// A compact, non-interactive depth-vs-time sparkline for dive profiles.
///
/// Renders a minimal [LineChart] showing the dive's depth curve with a subtle
/// gradient fill. Designed for inline use in lists where a visual "fingerprint"
/// of the dive shape is helpful (e.g. import wizard review step).
///
/// Returns [SizedBox.shrink] when [profile] is empty.
class DiveSparkline extends StatelessWidget {
  /// The profile sample points (timestamp + depth).
  final List<DiveProfilePoint> profile;

  /// Widget width in logical pixels.
  final double width;

  /// Widget height in logical pixels.
  final double height;

  /// Line and fill color. Defaults to [ColorScheme.primary].
  final Color? color;

  /// Maximum points to render; the profile is downsampled to this many.
  /// The default (40) suits tiny list thumbnails; larger previews can raise
  /// it to keep detail such as a mid-dive surface interval crisp.
  final int maxPoints;

  /// X-ranges (in the profile's timestamp units) to re-draw in a distinct
  /// colour on top of the main line -- e.g. inserted surface time between
  /// combined dives, so it reads apart from the real dive data.
  final List<({double startX, double endX})> highlightBands;

  /// Colour for [highlightBands]. Defaults to [ColorScheme.tertiary].
  final Color? highlightColor;

  /// Additional depth series drawn on the same axes as [profile], each in
  /// its own colour -- e.g. one line per source dive when previewing a
  /// multi-computer consolidation. Empty by default so existing single-line
  /// callers are unaffected.
  final List<DiveSparklineSeries> extraSeries;

  const DiveSparkline({
    super.key,
    required this.profile,
    this.width = 80,
    this.height = 32,
    this.color,
    this.maxPoints = 40,
    this.highlightBands = const [],
    this.highlightColor,
    this.extraSeries = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.primary;
    final samples = downsample(profile, maxPoints: maxPoints);

    // Negate depth so the curve goes downward (divers' convention).
    FlSpot toSpot(DiveProfilePoint p) =>
        FlSpot(p.timestamp.toDouble(), -p.depth);

    LineChartBarData depthBar(List<FlSpot> spots, Color c, double fillAlpha) =>
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: c,
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: c.withValues(alpha: fillAlpha),
          ),
        );

    final bars = <LineChartBarData>[
      depthBar(samples.map(toSpot).toList(), effectiveColor, 0.15),
      for (final series in extraSeries)
        if (series.profile.isNotEmpty)
          depthBar(
            downsample(
              series.profile,
              maxPoints: maxPoints,
            ).map(toSpot).toList(),
            series.color,
            0.15,
          ),
    ];

    // Re-draw each highlighted x-range on top of the main line in a distinct
    // colour and slightly stronger fill, so it stands out from the dive data.
    if (highlightBands.isNotEmpty) {
      final highlight = highlightColor ?? scheme.tertiary;
      for (final band in highlightBands) {
        final bandSpots = samples
            .where(
              (p) => p.timestamp >= band.startX && p.timestamp <= band.endX,
            )
            .map(toSpot)
            .toList();
        if (bandSpots.length < 2) continue;
        bars.add(depthBar(bandSpots, highlight, 0.28));
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          clipData: const FlClipData.all(),
          lineBarsData: bars,
        ),
      ),
    );
  }

  /// Downsample a profile to at most [maxPoints] using uniform stride.
  ///
  /// Always preserves the first and last points. Returns the original list
  /// unchanged when it contains [maxPoints] or fewer points. [maxPoints] is
  /// clamped to at least 2 so the stride divisor can never be zero.
  static List<DiveProfilePoint> downsample(
    List<DiveProfilePoint> points, {
    int maxPoints = 40,
  }) {
    final cap = maxPoints < 2 ? 2 : maxPoints;
    if (points.length <= cap) return points;

    final result = <DiveProfilePoint>[points.first];
    final stride = (points.length - 1) / (cap - 1);

    for (var i = 1; i < cap - 1; i++) {
      result.add(points[(i * stride).round()]);
    }

    result.add(points.last);
    return result;
  }
}
