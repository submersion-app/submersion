import 'package:flutter/rendering.dart';

import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// What the pinned strip's layer painters share (issue #4562): they draw
/// through [strip]'s own mapping and clip, so every layer lines up with the
/// depth line, and each layer at its strength in [layers].
abstract class StripLayerPainter extends CustomPainter {
  const StripLayerPainter({required this.strip, required this.layers});

  final PinnedStripPainter strip;
  final StripLayerState layers;

  /// Paints the layers through [m] within [area], the curve area as it is
  /// this frame (the whole strip once settled, the morphing plot while it
  /// condenses), already clipped to it.
  void paintLayers(Canvas canvas, Rect area, PlotMapping m);

  /// Whether this painter has anything at a strength above 0.
  bool get hasAnything;

  /// [color] faded to [strength].
  static Color faded(Color color, double strength) =>
      color.withValues(alpha: color.a * strength);

  @override
  void paint(Canvas canvas, Size size) {
    if (strip.profile.length < 2 || !hasAnything) return;
    final area = strip.clipFor(size) ?? Offset.zero & size;
    canvas
      ..save()
      ..clipRect(area);
    paintLayers(canvas, area, strip.mappingFor(size));
    canvas.restore();
  }

  @override
  bool shouldRepaint(StripLayerPainter oldDelegate) =>
      oldDelegate.runtimeType != runtimeType ||
      !identical(oldDelegate.layers.data, layers.data) ||
      !_sameStrengths(oldDelegate.layers.strengths, layers.strengths) ||
      oldDelegate.strip.profile != strip.profile ||
      oldDelegate.strip.from != strip.from ||
      oldDelegate.strip.morph != strip.morph ||
      oldDelegate.strip.curveHeight != strip.curveHeight ||
      oldDelegate.strip.extraMaxDepthMeters != strip.extraMaxDepthMeters ||
      oldDelegate.strip.surfaceColor != strip.surfaceColor ||
      // The media dots are drawn in the depth line's colour.
      oldDelegate.strip.curveColor != strip.curveColor;

  static bool _sameStrengths(Map<Object, double> a, Map<Object, double> b) {
    if (a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      if (b[key] != value) return false;
    }
    return true;
  }
}
