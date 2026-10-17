import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/scenes/chart_painter.dart';
import 'package:submersion/shared/widgets/scenes/scene_dash.dart';

/// Where a mark sits on the chart, as fractions of the marks layer, and how
/// its halo pulses.
class ChartSpot extends Equatable {
  const ChartSpot({required this.at, this.halo = true, this.haloDelay = 0});

  /// Position as fractions of the layer's width and height.
  final Offset at;

  /// Whether the dot has a pulsing halo.
  final bool halo;

  /// Shifts this halo's pulse, in seconds, so halos never pulse together.
  final double haloDelay;

  @override
  List<Object?> get props => [at, halo, haloDelay];
}

/// The marks on the chart: filled dots with pulsing halos and, for the
/// passage, a dashed course through them in order whose dashes creep along.
///
/// It reads the clock from [time] at paint time and repaints whenever the
/// clock ticks, so the labels laid out around it never rebuild.
class ChartMarksPainter extends CustomPainter {
  ChartMarksPainter({
    required this.time,
    required this.brightness,
    required this.spots,
    this.course = false,
  }) : super(repaint: time);

  final ValueListenable<double> time;
  final Brightness brightness;
  final List<ChartSpot> spots;

  /// Draws a dashed course through the spots, in order.
  final bool course;

  static const double dotRadius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ChartPalette.of(brightness);
    final seconds = time.value;
    final points = [
      for (final spot in spots)
        Offset(spot.at.dx * size.width, spot.at.dy * size.height),
    ];
    if (course && points.length > 1) {
      canvas.drawPath(
        // 220 px every 40 s, the mockup's dash creep.
        dashedPath(_course(points), dash: 6, gap: 5, phase: seconds * 5.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = palette.course,
      );
    }
    final paint = Paint();
    for (var i = 0; i < spots.length; i++) {
      final spot = spots[i];
      if (spot.halo) {
        final q =
            (1 - math.cos(2 * math.pi * (seconds + spot.haloDelay) / 8)) / 2;
        paint.color = palette.mark.withValues(alpha: 0.25 - 0.17 * q);
        canvas.drawCircle(points[i], 14 * (1 + 0.6 * q), paint);
      }
      paint.color = palette.mark;
      canvas.drawCircle(points[i], dotRadius, paint);
    }
  }

  /// A gentle S-curve from each point to the next.
  static Path _course(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final d = points[i] - a;
      final n = Offset(d.dy, -d.dx);
      final c1 = a + d * 0.35 + n * 0.12;
      final c2 = a + d * 0.65 - n * 0.12;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, points[i].dx, points[i].dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(ChartMarksPainter oldDelegate) =>
      oldDelegate.brightness != brightness ||
      oldDelegate.course != course ||
      !identical(oldDelegate.time, time) ||
      !listEquals(oldDelegate.spots, spots);
}
