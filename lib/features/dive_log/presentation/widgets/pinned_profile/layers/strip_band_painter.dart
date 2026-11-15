import 'dart:ui';

import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_painter_base.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// Draws the pinned strip's bands beneath its depth shading (issue #4562):
/// the phases of the dive, and the windows of its safety findings with a
/// solid edge where each starts.
class StripBandPainter extends StripLayerPainter {
  const StripBandPainter({required super.strip, required super.layers});

  @override
  bool get hasAnything =>
      layers.data.bands.any((b) => layers.strengthOf(b.layer) > 0);

  @override
  void paintLayers(Canvas canvas, Rect area, PlotMapping m) {
    for (final band in layers.data.bands) {
      final strength = layers.strengthOf(band.layer);
      if (strength <= 0) continue;
      final left = m.project(band.start, 0).dx;
      final right = m.project(band.end, 0).dx;
      canvas.drawRect(
        Rect.fromLTRB(left, area.top, right, area.bottom),
        Paint()
          ..color = band.color.withValues(
            alpha: band.color.a * band.alpha * strength,
          ),
      );
      if (band.layer == StripLayer.safetyFindings) {
        canvas.drawLine(
          Offset(left, area.top),
          Offset(left, area.bottom),
          Paint()
            ..color = StripLayerPainter.faded(band.color, strength)
            ..strokeWidth = 1.5,
        );
      }
    }
  }
}
