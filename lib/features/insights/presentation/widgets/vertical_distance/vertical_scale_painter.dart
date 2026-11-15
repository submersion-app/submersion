import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_selection.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_scale_geometry.dart';

/// Paints the scale (issue #4569): sea level, the two bars, a tick for each
/// passed landmark, a dashed line at the next one on each side, and the
/// hairline at the selected level. Labels and headlines are widgets laid
/// over it, so text follows the theme and the reading direction.
class VerticalScalePainter extends CustomPainter {
  VerticalScalePainter({
    required this.geometry,
    required this.selection,
    required this.ascentColor,
    required this.descentColor,
    required this.lineColor,
    required this.hairlineColor,
  }) : super(repaint: selection);

  final VerticalScaleGeometry geometry;

  /// Repaints the hairline on its own, without a rebuild.
  final ValueListenable<VerticalSelection> selection;
  final Color ascentColor;
  final Color descentColor;
  final Color lineColor;
  final Color hairlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, g.seaY), Offset(size.width, g.seaY), line);

    final bar = g.layout.barPx;
    if (bar > 0) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(g.barLeft, g.seaY - bar, g.barRight, g.seaY),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = ascentColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(g.barLeft, g.seaY, g.barRight, g.seaY + bar),
          bottomLeft: const Radius.circular(3),
          bottomRight: const Radius.circular(3),
        ),
        Paint()..color = descentColor,
      );
    }

    // Ticks sit on the labels' side of the bar.
    final tickFrom = g.labelsOnLeft
        ? g.barLeft - VerticalScaleGeometry.tickLength
        : g.barRight;
    final tickTo = tickFrom + VerticalScaleGeometry.tickLength;
    for (final d in VerticalLeg.values) {
      for (final m in g.layout.marksOn(d)) {
        final y = g.yFor(d, m.offsetPx);
        if (m.passed) {
          canvas.drawLine(Offset(tickFrom, y), Offset(tickTo, y), line);
        } else {
          _dashed(
            canvas,
            g.barLeft - VerticalScaleGeometry.tickLength,
            g.barRight + VerticalScaleGeometry.tickLength,
            y,
            line,
          );
        }
      }
    }

    final p = selection.value.probe;
    if (p != null) {
      final y = g.yFor(p.direction, g.layout.offsetFor(p.meters));
      canvas.drawLine(
        Offset(g.barLeft - 6, y),
        Offset(g.barRight + 6, y),
        Paint()
          ..color = hairlineColor
          ..strokeWidth = 2,
      );
    }
  }

  void _dashed(Canvas canvas, double from, double to, double y, Paint paint) {
    const dash = 4.0;
    const gap = 3.0;
    for (var x = from; x < to; x += dash + gap) {
      final end = x + dash < to ? x + dash : to;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(VerticalScalePainter old) =>
      old.geometry.layout != geometry.layout ||
      old.geometry.width != geometry.width ||
      old.geometry.labelsOnLeft != geometry.labelsOnLeft ||
      old.selection != selection ||
      old.ascentColor != ascentColor ||
      old.descentColor != descentColor ||
      old.lineColor != lineColor ||
      old.hairlineColor != hairlineColor;
}
