import 'package:flutter/material.dart';

/// A dashed rounded rectangle drawn over a chip: a hidden card's chip in
/// the Add strip, or a species tag the app applied and the diver has not
/// confirmed (issue #4727).
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({required this.color, required this.radius});

  static const double _dash = 4;
  static const double _gap = 3;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
