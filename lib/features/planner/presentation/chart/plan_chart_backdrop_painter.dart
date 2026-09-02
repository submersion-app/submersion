import 'package:flutter/material.dart';

import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Static chart furniture: grid lines, axis tick labels, axis unit labels,
/// and the ceiling no-go band (shaded area above the deco ceiling with a
/// dashed boundary). Repaints only when the plan data or theme changes.
class PlanChartBackdropPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final List<CanvasPoint> ceiling;
  final double depthUnitScale;
  final String depthAxisLabel;
  final String timeAxisLabel;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  const PlanChartBackdropPainter({
    required this.geometry,
    required this.palette,
    required this.ceiling,
    required this.depthUnitScale,
    required this.depthAxisLabel,
    required this.timeAxisLabel,
    required this.labelStyle,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plotRect;
    final gridPaint = Paint()
      ..color = palette.gridLine
      ..strokeWidth = 1;
    final style = labelStyle.copyWith(color: palette.axisLabel);

    // Horizontal depth grid + labels (skip the surface line at depth 0).
    final depthStep = geometry.depthTickIntervalMeters;
    for (var d = depthStep; d < geometry.maxDepthMeters * 1.1; d += depthStep) {
      final y = geometry.yFor(d);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final label = layoutLabel(
        (d * depthUnitScale).round().toString(),
        style,
        textDirection,
      );
      label.paint(
        canvas,
        Offset(plot.left - label.width - 6, y - label.height / 2),
      );
    }

    // Vertical time grid + labels. The time axis-unit label owns the
    // bottom-right corner, so tick labels that would collide with it are
    // drawn as grid lines only.
    final timeUnit = layoutLabel(timeAxisLabel, style, textDirection);
    final timeUnitOrigin = Offset(plot.right - timeUnit.width, plot.bottom + 4);
    final timeUnitRect = timeUnitOrigin & Size(timeUnit.width, timeUnit.height);
    final timeStep = geometry.timeTickIntervalSeconds;
    for (var t = timeStep; t < geometry.maxTimeSeconds * 1.05; t += timeStep) {
      final x = geometry.xFor(t);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      final label = layoutLabel(
        (t / 60).round().toString(),
        style,
        textDirection,
      );
      final labelOrigin = Offset(x - label.width / 2, plot.bottom + 4);
      final labelRect = labelOrigin & Size(label.width, label.height);
      if (!labelRect.inflate(4).overlaps(timeUnitRect)) {
        label.paint(canvas, labelOrigin);
      }
    }

    // Axis unit labels: depth unit top-left, time unit bottom-right.
    final depthUnit = layoutLabel(depthAxisLabel, style, textDirection);
    depthUnit.paint(canvas, Offset(plot.left - depthUnit.width - 6, plot.top));
    timeUnit.paint(canvas, timeUnitOrigin);

    // Ceiling no-go band: the region shallower than the ceiling. Only drawn
    // while a ceiling actually exists — during NDL time (ceiling == 0) there
    // is nothing to shade, so skip runs that are clear to the surface.
    for (final run in _ceilingRuns(ceiling)) {
      if (run.length < 2) continue;
      final band = Path()
        ..moveTo(geometry.xFor(run.first.timeSeconds), plot.top);
      for (final point in run) {
        band.lineTo(
          geometry.xFor(point.timeSeconds),
          geometry.yFor(point.depth),
        );
      }
      band
        ..lineTo(geometry.xFor(run.last.timeSeconds), plot.top)
        ..close();
      canvas.drawPath(band, Paint()..color = palette.ceilingFill);

      final boundary = Path()
        ..moveTo(
          geometry.xFor(run.first.timeSeconds),
          geometry.yFor(run.first.depth),
        );
      for (final point in run.skip(1)) {
        boundary.lineTo(
          geometry.xFor(point.timeSeconds),
          geometry.yFor(point.depth),
        );
      }
      canvas.drawPath(
        dashedPath(boundary, dash: 5, gap: 4),
        Paint()
          ..color = palette.ceilingLine
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// A ceiling at or below this depth (in meters) counts as clear to the
  /// surface. Deliberately tiny: it exists only to absorb the sub-centimeter
  /// residue that gradient-factor interpolation leaves on the final sample
  /// of [PlanOutcome.ceilingTrace], not to hide a real obligation. A larger
  /// value would end each run at a sample that is still meters deep, so the
  /// band would cut off in mid-water instead of tapering to the surface.
  static const clearCeilingEpsilon = 0.05;

  /// Splits [ceiling] into contiguous runs where the ceiling is actually
  /// above the surface (> [clearCeilingEpsilon]), each bookended by the
  /// adjacent clear-to-surface sample so the shaded band tapers down to 0
  /// instead of cutting off abruptly.
  List<List<CanvasPoint>> _ceilingRuns(List<CanvasPoint> ceiling) {
    final runs = <List<CanvasPoint>>[];
    List<CanvasPoint>? current;
    for (var i = 0; i < ceiling.length; i++) {
      final point = ceiling[i];
      if (point.depth > clearCeilingEpsilon) {
        current ??= [if (i > 0) ceiling[i - 1]];
        current.add(point);
      } else if (current != null) {
        current.add(point);
        runs.add(current);
        current = null;
      }
    }
    if (current != null) runs.add(current);
    return runs;
  }

  @override
  bool shouldRepaint(PlanChartBackdropPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.ceiling != ceiling ||
      oldDelegate.depthUnitScale != depthUnitScale ||
      oldDelegate.depthAxisLabel != depthAxisLabel ||
      oldDelegate.timeAxisLabel != timeAxisLabel ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textDirection != textDirection;
}
