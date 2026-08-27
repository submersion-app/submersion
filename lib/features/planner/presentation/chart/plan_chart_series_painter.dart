import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/stop_tag_layouter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// The data layer of the plan chart: ghost contingency profile, gradient
/// fill, the profile line itself, the mean-depth line, gas-switch flags, and
/// collision-avoided stop tags.
class PlanChartSeriesPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final PlanCanvasSeries series;
  final PlanCanvasSeries? ghost;
  final List<String> stopTagLabels;
  final String meanDepthLabel;
  final TextStyle labelStyle;
  final TextStyle tagStyle;
  final TextDirection textDirection;

  const PlanChartSeriesPainter({
    required this.geometry,
    required this.palette,
    required this.series,
    required this.ghost,
    required this.stopTagLabels,
    required this.meanDepthLabel,
    required this.labelStyle,
    required this.tagStyle,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plotRect;

    // Ghost contingency profile under everything.
    final ghostSeries = ghost;
    if (ghostSeries != null && ghostSeries.profile.length >= 2) {
      canvas.drawPath(
        dashedPath(_polyline(ghostSeries.profile), dash: 5, gap: 4),
        Paint()
          ..color = palette.ghostLine
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    if (series.profile.length >= 2) {
      // Gradient fill between the profile and the surface.
      final fill = Path.from(_polyline(series.profile))
        ..lineTo(geometry.xFor(series.profile.last.timeSeconds), plot.top)
        ..lineTo(geometry.xFor(series.profile.first.timeSeconds), plot.top)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.profileFillTop, palette.profileFillBottom],
          ).createShader(plot),
      );

      // Mean-depth line (dashed) with a right-aligned label above it.
      final mean = PlanChartGeometry.meanDepthMeters(series.profile);
      if (mean > 0) {
        final y = geometry.yFor(mean);
        final line = Path()
          ..moveTo(plot.left, y)
          ..lineTo(plot.right, y);
        canvas.drawPath(
          dashedPath(line, dash: 8, gap: 5),
          Paint()
            ..color = palette.meanDepthLine
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke,
        );
        final label = layoutLabel(
          meanDepthLabel,
          labelStyle.copyWith(color: palette.meanDepthLine),
          textDirection,
        );
        label.paint(
          canvas,
          Offset(plot.right - label.width - 4, y - label.height - 2),
        );
      }

      // The profile line.
      canvas.drawPath(
        _polyline(series.profile),
        Paint()
          ..color = palette.profileLine
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Gas-switch flags: dashed stem from the surface to the switch, pill on
    // top with the gas name.
    for (final marker in series.gasSwitches) {
      final x = geometry.xFor(marker.timeSeconds);
      final stem = Path()
        ..moveTo(x, plot.top)
        ..lineTo(x, geometry.yFor(marker.depth));
      canvas.drawPath(
        dashedPath(stem, dash: 3, gap: 3),
        Paint()
          ..color = palette.gasFlag
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke,
      );
      final label = layoutLabel(
        marker.label,
        tagStyle.copyWith(color: palette.gasFlag),
        textDirection,
      );
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 4, plot.top + 4, label.width + 12, label.height + 6),
        const Radius.circular(8),
      );
      canvas.drawRRect(pill, Paint()..color = palette.gasFlagBackground);
      label.paint(canvas, Offset(pill.left + 6, pill.top + 3));
    }

    // Stop tags with collision avoidance.
    if (series.stopLabels.isNotEmpty &&
        stopTagLabels.length == series.stopLabels.length) {
      final painters = [
        for (final text in stopTagLabels)
          layoutLabel(
            text,
            tagStyle.copyWith(color: palette.stopTagText),
            textDirection,
          ),
      ];
      final rects = StopTagLayouter.layout(
        anchors: [
          for (final m in series.stopLabels)
            geometry.toPixel(m.timeSeconds + m.durationSeconds, m.depth),
        ],
        sizes: [for (final p in painters) Size(p.width + 10, p.height + 6)],
        bounds: plot,
      );
      final borderPaint = Paint()
        ..color = palette.stopTagBorder
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final fillPaint = Paint()..color = palette.stopTagBackground;
      for (var i = 0; i < rects.length; i++) {
        final rrect = RRect.fromRectAndRadius(
          rects[i],
          const Radius.circular(4),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, borderPaint);
        painters[i].paint(canvas, Offset(rects[i].left + 5, rects[i].top + 3));
      }
    }
  }

  Path _polyline(List<CanvasPoint> points) {
    final path = Path()
      ..moveTo(
        geometry.xFor(points.first.timeSeconds),
        geometry.yFor(points.first.depth),
      );
    for (final point in points.skip(1)) {
      path.lineTo(geometry.xFor(point.timeSeconds), geometry.yFor(point.depth));
    }
    return path;
  }

  @override
  bool shouldRepaint(PlanChartSeriesPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.series != series ||
      oldDelegate.ghost != ghost ||
      oldDelegate.meanDepthLabel != meanDepthLabel ||
      !listEquals(oldDelegate.stopTagLabels, stopTagLabels) ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.tagStyle != tagStyle ||
      oldDelegate.textDirection != textDirection;
}
