import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints the marks of `DiveTideChart`: grid, tide curve, the dive's band
/// and the dots on each high, low and the entry.
///
/// Every position arrives already laid out, in the chart's own pixels. The
/// chart's text is not painted here: its labels are widgets placed over this
/// painter, so they follow the text scale and can be read by a test.
class DiveTideChartPainter extends CustomPainter {
  const DiveTideChartPainter({
    required this.plot,
    required this.curve,
    required this.gridYs,
    required this.tickXs,
    required this.midnightXs,
    required this.extremes,
    required this.entryX,
    required this.entryY,
    required this.exitX,
    required this.curveColor,
    required this.gridColor,
    required this.midnightColor,
    required this.diveColor,
    required this.ringColor,
  });

  /// The area the curve is drawn in.
  final Rect plot;

  /// The tide curve, left to right.
  final List<Offset> curve;

  /// Height gridlines.
  final List<double> gridYs;

  /// Time gridlines, and the ones among them that fall on a site midnight.
  final List<double> tickXs;
  final List<double> midnightXs;

  /// A dot on each high and low.
  final List<({Offset at, Color color})> extremes;

  /// Where the dive starts; [entryY] is null when the curve has no height
  /// there. [exitX] is null when the dive's duration is unknown.
  final double entryX;
  final double? entryY;
  final double? exitX;

  final Color curveColor;
  final Color gridColor;
  final Color midnightColor;
  final Color diveColor;

  /// Rings each dot to punch it out of the curve: the colour behind the
  /// chart (its card), as on the other tide charts.
  final Color ringColor;

  static const double extremeDotRadius = 5.5;
  static const double entryDotRadius = 6.5;

  /// The narrowest the dive's band is drawn, so a short dive still shows.
  static const double minBandWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (plot.width <= 0 || plot.height <= 0) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final y in gridYs) {
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    for (final x in tickXs) {
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
    }
    final midnight = Paint()
      ..color = midnightColor
      ..strokeWidth = 1.5;
    for (final x in midnightXs) {
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), midnight);
    }
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, midnight);

    if (curve.length >= 2) {
      final line = Path()..moveTo(curve.first.dx, curve.first.dy);
      for (final point in curve.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      final fill = Path.from(line)
        ..lineTo(curve.last.dx, plot.bottom)
        ..lineTo(curve.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..color = curveColor.withValues(alpha: 0.14),
      );

      _paintDive(canvas);

      canvas.drawPath(
        line,
        Paint()
          ..color = curveColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    } else {
      _paintDive(canvas);
    }

    final ring = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final extreme in extremes) {
      canvas.drawCircle(
        extreme.at,
        extremeDotRadius,
        Paint()..color = extreme.color,
      );
      canvas.drawCircle(extreme.at, extremeDotRadius, ring);
    }
    final y = entryY;
    if (y != null) {
      final at = Offset(entryX, y);
      canvas.drawCircle(at, entryDotRadius, Paint()..color = diveColor);
      canvas.drawCircle(at, entryDotRadius, ring);
    }
  }

  /// The band from entry to exit, and a dashed line down the entry.
  void _paintDive(Canvas canvas) {
    final exit = exitX;
    if (exit != null) {
      final right = math.min(plot.right, math.max(exit, entryX + minBandWidth));
      canvas.drawRect(
        Rect.fromLTRB(entryX, plot.top, right, plot.bottom),
        Paint()..color = diveColor.withValues(alpha: 0.2),
      );
    }
    final dash = Paint()
      ..color = diveColor
      ..strokeWidth = 1.5;
    const dashLength = 4.0;
    const gapLength = 3.0;
    for (var y = plot.top; y < plot.bottom; y += dashLength + gapLength) {
      canvas.drawLine(
        Offset(entryX, y),
        Offset(entryX, math.min(y + dashLength, plot.bottom)),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DiveTideChartPainter oldDelegate) {
    // Every field is drawn, so every field is compared.
    return plot != oldDelegate.plot ||
        !listEquals(curve, oldDelegate.curve) ||
        !listEquals(gridYs, oldDelegate.gridYs) ||
        !listEquals(tickXs, oldDelegate.tickXs) ||
        !listEquals(midnightXs, oldDelegate.midnightXs) ||
        !listEquals(extremes, oldDelegate.extremes) ||
        entryX != oldDelegate.entryX ||
        entryY != oldDelegate.entryY ||
        exitX != oldDelegate.exitX ||
        curveColor != oldDelegate.curveColor ||
        gridColor != oldDelegate.gridColor ||
        midnightColor != oldDelegate.midnightColor ||
        diveColor != oldDelegate.diveColor ||
        ringColor != oldDelegate.ringColor;
  }
}
