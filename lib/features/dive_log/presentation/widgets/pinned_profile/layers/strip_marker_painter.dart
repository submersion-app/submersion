import 'dart:ui';

import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_painter_base.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// How far a tick reaches in from its edge of the strip.
const double kStripTickLength = 6;

/// Radius of a media dot.
const double kStripDotRadius = 3;

/// Radius of the dot standing for several captures too close to tell apart.
const double kStripClusterRadius = 4.5;

/// How close, in pixels, two media dots may be before they are drawn as one,
/// as the full chart clusters its photo markers.
const double _clusterRadiusPx = 8;

/// Radius of a bookmark's ring.
const double _bookmarkRadius = 2.5;

/// Draws the pinned strip's marks over its lines (issue #4562): ticks for
/// annotations, bookmarks, gas switches and instant findings, and a dot on
/// the depth line wherever a photo or video was taken.
class StripMarkerPainter extends StripLayerPainter {
  const StripMarkerPainter({required super.strip, required super.layers});

  @override
  bool get hasAnything =>
      layers.data.ticks.any((t) => layers.strengthOf(t.layer) > 0) ||
      (layers.data.dots.isNotEmpty && layers.strengthOf(StripLayer.media) > 0);

  @override
  void paintLayers(Canvas canvas, Rect area, PlotMapping m) {
    for (final tick in layers.data.ticks) {
      final strength = layers.strengthOf(tick.layer);
      if (strength <= 0) continue;
      final x = m.project(tick.seconds, 0).dx;
      final paint = Paint()
        ..color = StripLayerPainter.faded(tick.color, strength)
        ..strokeWidth = 1.5;
      if (tick.hollow) {
        canvas.drawCircle(
          Offset(x, area.top + _bookmarkRadius + 1.5),
          _bookmarkRadius,
          paint..style = PaintingStyle.stroke,
        );
        continue;
      }
      // From the curve area's edge: while the strip condenses its box is
      // the whole card, far below the curve.
      final top = tick.edge == StripTickEdge.top;
      final edge = top ? area.top : area.bottom;
      canvas.drawLine(
        Offset(x, edge),
        Offset(x, top ? edge + kStripTickLength : edge - kStripTickLength),
        paint,
      );
    }
    final media = layers.strengthOf(StripLayer.media);
    if (media <= 0) return;
    // Captures too close to tell apart are one dot, a little larger, as the
    // full chart clusters its markers.
    final dots = layers.data.dots;
    final clusters = clusterPhotoMarkers(
      points: [
        for (final d in dots)
          (
            seconds: d.seconds.toDouble(),
            depthDisplay:
                profileDepthAt(strip.profile, d.seconds) ?? d.depthMeters,
          ),
      ],
      visibleMinSeconds: m.minSeconds,
      visibleMaxSeconds: m.maxSeconds,
      visibleMinDepth: m.minDepthMeters,
      visibleMaxDepth: m.maxDepthMeters,
      plotWidth: m.rect.width,
      plotHeight: m.rect.height,
      mergeRadiusPx: _clusterRadiusPx,
    );
    for (final c in clusters) {
      _paintDot(
        canvas,
        m.rect.topLeft + Offset(c.x, c.y),
        c.memberIndexes.length > 1 ? kStripClusterRadius : kStripDotRadius,
        media,
      );
    }
  }

  /// A dot on the depth line the strip draws, ringed in its surface colour
  /// like the max-depth marker.
  void _paintDot(Canvas canvas, Offset at, double radius, double strength) {
    canvas
      ..drawCircle(
        at,
        radius,
        Paint()..color = StripLayerPainter.faded(strip.curveColor, strength),
      )
      ..drawCircle(
        at,
        radius,
        Paint()
          ..color = StripLayerPainter.faded(strip.surfaceColor, strength)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }
}
