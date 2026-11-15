import 'dart:ui';

import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_painter_base.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// How far a tick reaches in from its edge of the strip.
const double kStripTickLength = 6;

/// Radius of a media dot.
const double kStripDotRadius = 3;

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
  void paintLayers(Canvas canvas, Size size, PlotMapping m) {
    for (final tick in layers.data.ticks) {
      final strength = layers.strengthOf(tick.layer);
      if (strength <= 0) continue;
      final x = m.project(tick.seconds, 0).dx;
      final paint = Paint()
        ..color = StripLayerPainter.faded(tick.color, strength)
        ..strokeWidth = 1.5;
      if (tick.hollow) {
        canvas.drawCircle(
          Offset(x, _bookmarkRadius + 1.5),
          _bookmarkRadius,
          paint..style = PaintingStyle.stroke,
        );
        continue;
      }
      final top = tick.edge == StripTickEdge.top;
      canvas.drawLine(
        Offset(x, top ? 0 : size.height),
        Offset(x, top ? kStripTickLength : size.height - kStripTickLength),
        paint,
      );
    }
    final media = layers.strengthOf(StripLayer.media);
    if (media <= 0) return;
    for (final dot in layers.data.dots) {
      _paintDot(canvas, m, dot, media);
    }
  }

  /// A dot on the depth line the strip draws, ringed in its surface colour
  /// like the max-depth marker.
  void _paintDot(Canvas canvas, PlotMapping m, StripDot dot, double strength) {
    final depth = profileDepthAt(strip.profile, dot.seconds) ?? dot.depthMeters;
    final at = m.project(dot.seconds, depth);
    canvas
      ..drawCircle(
        at,
        kStripDotRadius,
        Paint()..color = StripLayerPainter.faded(strip.curveColor, strength),
      )
      ..drawCircle(
        at,
        kStripDotRadius,
        Paint()
          ..color = StripLayerPainter.faded(strip.surfaceColor, strength)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }
}
