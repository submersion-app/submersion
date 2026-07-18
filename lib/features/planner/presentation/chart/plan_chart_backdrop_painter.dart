import 'package:flutter/material.dart';

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

    // Ceiling no-go band: the region shallower than the ceiling.
    if (ceiling.length >= 2) {
      final band = Path()
        ..moveTo(geometry.xFor(ceiling.first.timeSeconds), plot.top);
      for (final point in ceiling) {
        band.lineTo(
          geometry.xFor(point.timeSeconds),
          geometry.yFor(point.depth),
        );
      }
      band
        ..lineTo(geometry.xFor(ceiling.last.timeSeconds), plot.top)
        ..close();
      canvas.drawPath(band, Paint()..color = palette.ceilingFill);

      final boundary = Path()
        ..moveTo(
          geometry.xFor(ceiling.first.timeSeconds),
          geometry.yFor(ceiling.first.depth),
        );
      for (final point in ceiling.skip(1)) {
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
