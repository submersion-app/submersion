import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';

/// Scrub cursor + waypoint handles layer; repaints per pointer event without
/// touching the series or backdrop layers.
class PlanChartOverlayPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final double? scrubX;
  final List<Offset> handles;
  final int? activeHandle;
  final int? selectedHandle;

  const PlanChartOverlayPainter({
    required this.geometry,
    required this.palette,
    required this.scrubX,
    this.handles = const [],
    this.activeHandle,
    this.selectedHandle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plotRect;
    final x = scrubX;
    if (x != null) {
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = palette.scrubCursor
          ..strokeWidth = 1,
      );
    }

    final fill = Paint()..color = palette.backdrop;
    final stroke = Paint()
      ..color = palette.profileLine
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final selectedFill = Paint()..color = palette.profileLine;
    for (var i = 0; i < handles.length; i++) {
      final active = i == activeHandle;
      final selected = i == selectedHandle;
      final radius = active ? 6.5 : 4.5;
      canvas.drawCircle(handles[i], radius, selected ? selectedFill : fill);
      canvas.drawCircle(handles[i], radius, stroke);
    }
  }

  @override
  bool shouldRepaint(PlanChartOverlayPainter oldDelegate) =>
      oldDelegate.scrubX != scrubX ||
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.activeHandle != activeHandle ||
      oldDelegate.selectedHandle != selectedHandle ||
      !listEquals(oldDelegate.handles, handles);
}
