import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';

/// Canvas positions for [points] in a [size] box: aspect-preserving, centred,
/// with a 6 px inset.
///
/// Pulled out of [TrackShapePainter.paint] so the layout can be asserted
/// without rasterizing - toImage() hangs under flutter test.
///
/// Returns fewer than two offsets when there is nothing to draw.
List<Offset> trackShapeOffsets(List<GpsTrackPoint> points, Size size) {
  if (points.length < 2) return const [];
  final bounds = trackBounds(points);
  if (bounds == null) return const [];

  final latSpan = bounds.maxLat - bounds.minLat;
  final lonSpan = bounds.maxLon - bounds.minLon;

  // A perfectly straight north-south or east-west track has a zero span on
  // one axis. Substituting 1 keeps the scale finite instead of producing NaN.
  final safeLatSpan = latSpan == 0 ? 1.0 : latSpan;
  final safeLonSpan = lonSpan == 0 ? 1.0 : lonSpan;

  // Preserve aspect ratio: use the tighter scale on both axes, then centre.
  const padding = 6.0;
  final usableWidth = size.width - padding * 2;
  final usableHeight = size.height - padding * 2;
  final scale = (usableWidth / safeLonSpan) < (usableHeight / safeLatSpan)
      ? usableWidth / safeLonSpan
      : usableHeight / safeLatSpan;

  final drawnWidth = safeLonSpan * scale;
  final drawnHeight = safeLatSpan * scale;
  final offsetX = (size.width - drawnWidth) / 2;
  final offsetY = (size.height - drawnHeight) / 2;

  // The substituted span above is arbitrary, so on a collapsed axis every
  // point would land on the LEADING edge of a box that wide - visibly off
  // centre. Shift the collapsed axis to the box's midpoint.
  final centreX = lonSpan == 0 ? drawnWidth / 2 : 0.0;
  final centreY = latSpan == 0 ? drawnHeight / 2 : 0.0;

  return [
    for (final p in points)
      Offset(
        // trackBounds may report an unwrapped maxLon above 180 for a track
        // that crosses the antimeridian. Read every point through the same
        // frame, or the western half draws hundreds of degrees off canvas.
        offsetX +
            centreX +
            (longitudeInBoundsFrame(p.longitude, bounds) - bounds.minLon) *
                scale,
        // Screen y grows downward, latitude grows northward: invert.
        offsetY + centreY + (bounds.maxLat - p.latitude) * scale,
      ),
  ];
}

/// Draws a track's shape with no basemap, scaled to fill the canvas.
///
/// The offline fallback for row thumbnails. A GPS track is recorded on a boat,
/// where there is usually no signal to fetch tiles with, so this path runs
/// often enough to deserve being good rather than being a stub.
class TrackShapePainter extends CustomPainter {
  TrackShapePainter({required this.points, required this.color});

  final List<GpsTrackPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final offsets = trackShapeOffsets(points, size);
    if (offsets.length < 2) return;

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  /// Compares point lists by identity, not element-wise.
  ///
  /// Every geometry list in this feature comes from a List.unmodifiable in
  /// simplifyTrack or the cache repository, so a changed track always yields
  /// a new instance. Deep-comparing thousands of points every frame would
  /// cost more than the repaint it avoids.
  @override
  bool shouldRepaint(TrackShapePainter oldDelegate) =>
      oldDelegate.color != color || !identical(oldDelegate.points, points);
}

/// A fixed-size tinted chip containing a [TrackShapePainter].
class TrackShapeChip extends StatelessWidget {
  const TrackShapeChip({
    super.key,
    required this.points,
    required this.width,
    required this.height,
  });

  final List<GpsTrackPoint> points;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: TrackShapePainter(points: points, color: scheme.primary),
        ),
      ),
    );
  }
}
