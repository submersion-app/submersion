import 'package:flutter/material.dart';

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// A small top-down sketch of a route's raw local (north, east) shape, for
/// list rows of unanchored routes (spec
/// 2026-09-10-underwater-nav-track-design.md, "The routes area"): no
/// georeferencing, just the path's silhouette normalized into the tile.
class NavTrackShapeThumbnail extends StatelessWidget {
  const NavTrackShapeThumbnail({
    super.key,
    required this.points,
    this.size = 40,
  });

  final List<NavTrackPoint> points;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShapePainter(
          points: points,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({required this.points, required this.color});

  final List<NavTrackPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var minNorth = points.first.north, maxNorth = points.first.north;
    var minEast = points.first.east, maxEast = points.first.east;
    for (final p in points) {
      if (p.north < minNorth) minNorth = p.north;
      if (p.north > maxNorth) maxNorth = p.north;
      if (p.east < minEast) minEast = p.east;
      if (p.east > maxEast) maxEast = p.east;
    }
    final spanNorth = (maxNorth - minNorth).abs();
    final spanEast = (maxEast - minEast).abs();
    final span = (spanNorth > spanEast ? spanNorth : spanEast);
    final scale = span <= 0 ? 0.0 : (size.shortestSide * 0.8) / span;
    final centerNorth = (minNorth + maxNorth) / 2;
    final centerEast = (minEast + maxEast) / 2;

    Offset toOffset(NavTrackPoint p) => Offset(
      size.width / 2 + (p.east - centerEast) * scale,
      // Screen y grows downward; north should point up.
      size.height / 2 - (p.north - centerNorth) * scale,
    );

    final path = Path()
      ..moveTo(toOffset(points.first).dx, toOffset(points.first).dy);
    for (final p in points.skip(1)) {
      final o = toOffset(p);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
