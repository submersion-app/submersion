import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/ascent_rate_calculator.dart';

/// Vertical bars from a fixed mid-plot baseline, one per (decimated)
/// ascent-rate sample: both length and colour intensity scale with the
/// rate's magnitude. Descents draw downward in red, ascents upward in green.
///
/// This reads directly off [AscentRatePoint.rateMetersPerMin] rather than the
/// depth trace: the baseline is a fixed horizontal line at the vertical
/// middle of the plot, not anchored to the depth curve (issue #2228
/// follow-up, matching a reference dive-log tool's rendering). It replaces
/// the previous lime ascent-rate line (a `LineChartBarData` scaled curve,
/// removed) under the same legend toggle. It is deliberately independent
/// from the depth line's "velocity colouring" (which tints the depth trace
/// itself in 3 discrete bands) -- both can be on at once without
/// conflicting, since this one draws in its own space at the plot's
/// vertical centre.
///
/// Rendered as a widget layer above the LineChart (a later Stack child),
/// mirroring [PhotoMarkerOverlay]'s positioning: it shares the chart's
/// `insets` (reserved axis gutters) and visible-window seconds so it lines up
/// with the plot exactly, independent of zoom/pan.
class AscentRateBarOverlay extends StatelessWidget {
  /// Every sample's rate; index 0 is a zero placeholder (see
  /// [AscentRateCalculator]). Not pre-filtered to the visible window -- this
  /// widget clips to it itself, the same way [PhotoMarkerOverlay] does.
  final List<AscentRatePoint> ascentRates;

  /// Visible time window in seconds (the chart's zoomed/panned X range).
  final double visibleMinSeconds;
  final double visibleMaxSeconds;

  /// Reserved axis gutters around the plot rect (the chart's `_plotInsets`).
  final ({double left, double top, double right, double bottom}) insets;

  /// Symmetric +/- rate the bars saturate at: a sample at or beyond this
  /// magnitude draws at the maximum bar length and the darkest colour.
  /// Callers should pass [DiveProfileChart.ascentRateAxisRange]'s `max` so
  /// these bars, the optional lime rate line, and the right axis all agree
  /// on one scale rather than inventing a second threshold.
  final double maxAbsRateMetersPerMin;

  /// The touched/hovered sample's timestamp (seconds), or null when nothing
  /// is hovered. Non-null lights up every bar -- brighter and a little
  /// wider -- the same way hovering a metric line highlights that whole
  /// line rather than just the touched point on it. (Highlighting only the
  /// nearest bar read as a single stray bar changing among many identical
  /// ones, not as "this metric is highlighted".)
  final int? highlightedTimestamp;

  const AscentRateBarOverlay({
    super.key,
    required this.ascentRates,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
    required this.insets,
    required this.maxAbsRateMetersPerMin,
    this.highlightedTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = constraints.maxWidth - insets.left - insets.right;
        final plotHeight = constraints.maxHeight - insets.top - insets.bottom;
        final visibleRange = visibleMaxSeconds - visibleMinSeconds;
        if (plotWidth <= 0 ||
            plotHeight <= 0 ||
            visibleRange <= 0 ||
            ascentRates.isEmpty ||
            maxAbsRateMetersPerMin <= 0) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _AscentRateBarPainter(
              ascentRates: ascentRates,
              visibleMinSeconds: visibleMinSeconds,
              visibleMaxSeconds: visibleMaxSeconds,
              insets: insets,
              plotWidth: plotWidth,
              plotHeight: plotHeight,
              maxAbsRateMetersPerMin: maxAbsRateMetersPerMin,
              highlightedTimestamp: highlightedTimestamp,
            ),
          ),
        );
      },
    );
  }
}

class _AscentRateBarPainter extends CustomPainter {
  final List<AscentRatePoint> ascentRates;
  final double visibleMinSeconds;
  final double visibleMaxSeconds;
  final ({double left, double top, double right, double bottom}) insets;
  final double plotWidth;
  final double plotHeight;
  final double maxAbsRateMetersPerMin;
  final int? highlightedTimestamp;

  _AscentRateBarPainter({
    required this.ascentRates,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
    required this.insets,
    required this.plotWidth,
    required this.plotHeight,
    required this.maxAbsRateMetersPerMin,
    this.highlightedTimestamp,
  });

  // Light-to-dark ends of each direction's colour ramp. Red deepens with
  // descent speed, green deepens with ascent speed, matching the reference
  // sketch (faster = darker, in the same hue family as "danger"/"safe"). The
  // dark ends go past Material's own 900 shades -- red/green 900 alone did
  // not read as noticeably darker for the fastest rates against the chart's
  // own dark background.
  static const _descentLight = Color(0xFFEF9A9A); // red 200
  static const _descentDark = Color(0xFF7A0000); // past red 900
  static const _ascentLight = Color(0xFFA5D6A7); // green 200
  static const _ascentDark = Color(0xFF0A3D0F); // past green 900

  /// One bar per this many pixels of plot width: dense profiles (thousands of
  /// samples) would otherwise paint one line per sample, most of them
  /// sub-pixel and invisible. Each bucket keeps its single most extreme
  /// sample (by |rate|) rather than an average, so a brief rapid-ascent spike
  /// still shows at full height instead of being smoothed away.
  static const _pixelsPerBar = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final baselineY = insets.top + plotHeight / 2;
    final visibleSpan = visibleMaxSeconds - visibleMinSeconds;
    final pixelsPerSecond = plotWidth / visibleSpan;

    // Bucket by pixel column so the bar count is bounded by plot width, not
    // sample count, and pick each bucket's most extreme sample.
    final buckets = <int, AscentRatePoint>{};
    for (final point in ascentRates) {
      final t = point.timestamp.toDouble();
      if (t < visibleMinSeconds || t > visibleMaxSeconds) continue;
      final xPixel = (t - visibleMinSeconds) * pixelsPerSecond;
      final bucket = (xPixel / _pixelsPerBar).floor();
      final current = buckets[bucket];
      if (current == null ||
          point.rateMetersPerMin.abs() > current.rateMetersPerMin.abs()) {
        buckets[bucket] = point;
      }
    }
    if (buckets.isEmpty) return;

    // Whether anything is hovered at all: every bar lights up together in
    // that case (see the field doc on [highlightedTimestamp]), so there is
    // no per-bucket matching to do here.
    final isHighlighted = highlightedTimestamp != null;

    final halfBand = plotHeight / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // Sorted so each bar's right edge is the next occupied bucket's left
    // edge: a profile sparser than one sample per bucket leaves buckets
    // with no entry at all, and a fixed _pixelsPerBar width per bar (rather
    // than reaching to whichever bucket is actually next) would leave a
    // visible gap across that empty stretch.
    final sortedKeys = buckets.keys.toList()..sort();

    for (var i = 0; i < sortedKeys.length; i++) {
      final bucket = sortedKeys[i];
      final point = buckets[bucket]!;
      final rate = point.rateMetersPerMin;
      if (rate == 0) continue;
      final magnitude = (rate.abs() / maxAbsRateMetersPerMin).clamp(0.0, 1.0);
      if (magnitude <= 0) continue;

      final left = insets.left + bucket * _pixelsPerBar;
      final nextBucket = i + 1 < sortedKeys.length
          ? sortedKeys[i + 1]
          : bucket + 1;
      // The last bar's own bucket boundary can land past the plot's right
      // edge (a sample at exactly visibleMaxSeconds floors into the last
      // bucket, whose +1 edge is bucket-quantized, not clipped to the real
      // pixel width); the parent stack paints with Clip.none, so an
      // unclamped edge here would bleed into the right-axis gutter.
      final right = math.min(
        insets.left + nextBucket * _pixelsPerBar,
        insets.left + plotWidth,
      );
      final barLength = magnitude * halfBand;
      final descending = rate < 0;
      // Eased, not linear: a plain lerp on `magnitude` left medium and fast
      // rates looking too close in colour to tell apart at a glance. Squaring
      // keeps slow rates close to the light end and reserves the darkest
      // shades for genuinely fast ones, while staying a smooth function of
      // rate rather than a stepped/banded one. Bar length stays linear in
      // `magnitude` -- only the colour ramp uses this.
      final colorMagnitude = magnitude * magnitude;
      final baseColor = Color.lerp(
        descending ? _descentLight : _ascentLight,
        descending ? _descentDark : _ascentDark,
        colorMagnitude,
      )!;
      // Lit up: brighter (lerp toward white), the same way hovering a
      // metric line highlights that whole line rather than just the
      // touched point on it.
      paint.color = isHighlighted
          ? Color.lerp(baseColor, Colors.white, 0.45)!
          : baseColor;
      final endY = descending ? baselineY + barLength : baselineY - barLength;
      final top = descending ? baselineY : endY;
      final bottom = descending ? endY : baselineY;
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AscentRateBarPainter oldDelegate) =>
      !identical(oldDelegate.ascentRates, ascentRates) ||
      oldDelegate.visibleMinSeconds != visibleMinSeconds ||
      oldDelegate.visibleMaxSeconds != visibleMaxSeconds ||
      oldDelegate.insets != insets ||
      oldDelegate.plotWidth != plotWidth ||
      oldDelegate.plotHeight != plotHeight ||
      oldDelegate.maxAbsRateMetersPerMin != maxAbsRateMetersPerMin ||
      oldDelegate.highlightedTimestamp != highlightedTimestamp;
}
