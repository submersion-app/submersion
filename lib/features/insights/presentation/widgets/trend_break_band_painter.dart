import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/trend_time_scale.dart';

/// A collapsed gap placed in plot pixels, with its length label.
typedef TrendBreakBand = ({double left, double right, String label});

/// Draws each collapsed gap as a diagonal-hatched band the full height of
/// the plot, with its length centred under the x axis (issue #3251).
class TrendBreakBandPainter extends CustomPainter {
  TrendBreakBandPainter({
    required this.bands,
    required this.plot,
    required this.hatch,
    required this.fill,
    required this.labelStyle,
    required this.textDirection,
  });

  final List<TrendBreakBand> bands;
  final Rect plot;
  final Color hatch;
  final Color fill;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  /// Gap between hatch lines, in pixels.
  static const double _spacing = 6;

  /// Places [breaks] in pixels over [plot] for the window
  /// [visibleMin]..[visibleMax], clipping to the plot and dropping any
  /// wholly out of view.
  static List<TrendBreakBand> layout({
    required List<TrendGapBreak> breaks,
    required double visibleMin,
    required double visibleMax,
    required Rect plot,
    required String Function(TrendGapBreak) labelOf,
  }) {
    final span = visibleMax - visibleMin;
    if (span <= 0) return const [];
    double px(double x) => plot.left + (x - visibleMin) / span * plot.width;
    return [
      for (final b in breaks)
        if (b.axisEnd > visibleMin && b.axisStart < visibleMax)
          (
            left: math.max(px(b.axisStart), plot.left),
            right: math.min(px(b.axisEnd), plot.right),
            label: labelOf(b),
          ),
    ];
  }

  /// Left edge for a label [width] wide centred on [centre], kept inside a
  /// chart [chartWidth] wide so a band at the edge of a zoomed window does
  /// not paint its length past the chart.
  static double labelLeft(double centre, double width, double chartWidth) {
    final left = centre - width / 2;
    final maxLeft = math.max(0.0, chartWidth - width);
    return left.clamp(0.0, maxLeft);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = hatch
      ..strokeWidth = 1;
    final fillPaint = Paint()..color = fill;
    for (final band in bands) {
      final rect = Rect.fromLTRB(band.left, plot.top, band.right, plot.bottom);
      canvas
        ..save()
        ..clipRect(rect)
        ..drawRect(rect, fillPaint);
      for (var x = rect.left - rect.height; x < rect.right; x += _spacing) {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + rect.height, rect.top),
          linePaint,
        );
      }
      canvas.restore();

      final text = TextPainter(
        text: TextSpan(text: band.label, style: labelStyle),
        textDirection: textDirection,
      )..layout();
      final centre = (band.left + band.right) / 2;
      text.paint(
        canvas,
        Offset(labelLeft(centre, text.width, size.width), plot.bottom + 8),
      );
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(TrendBreakBandPainter old) =>
      old.bands != bands ||
      old.plot != plot ||
      old.hatch != hatch ||
      old.fill != fill ||
      old.labelStyle != labelStyle ||
      old.textDirection != textDirection;
}
