import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';

/// Height of the strip's values row, under its curve.
const double kPinnedStripRowHeight = 16;

/// Breathing room above and below the strip's curve.
const double _curvePad = 4;

/// Height of the pinned strip's curve area, above its values row. The strip
/// aims its line at this from the start, whatever height its box has while
/// it condenses, so the line never grows back out toward a tall box.
const double _curveAreaHeight = kPinnedStripHeight - kPinnedStripRowHeight;

/// Paints the pinned strip's depth curve (issue #4423).
///
/// The curve goes through a [PlotMapping] that moves, as [morph] runs from 0
/// to 1, from [from] (where the full chart draws its depth line, in this
/// painter's coordinates) to the strip's own curve area. At 0 the line lies
/// exactly on the chart's, so the condense never shows two depth lines; every
/// point then travels continuously into the strip.
class PinnedStripPainter extends CustomPainter {
  const PinnedStripPainter({
    required this.profile,
    required this.selectedSeconds,
    required this.curveColor,
    required this.fillColors,
    required this.markerColor,
    this.from,
    this.morph = 1,
  });

  final List<DiveProfilePoint> profile;
  final int? selectedSeconds;
  final Color curveColor;

  /// Top and bottom of the shading under the line, as the full chart's depth
  /// gradient.
  final List<Color> fillColors;
  final Color markerColor;
  final PlotMapping? from;
  final double morph;

  /// The strip's own mapping: the whole dive across the pinned strip's curve
  /// area, surface to deepest point down.
  PlotMapping _own(Size size) {
    var maxDepth = 0.0;
    for (final p in profile) {
      maxDepth = math.max(maxDepth, p.depth);
    }
    return PlotMapping(
      rect: Rect.fromLTWH(
        0,
        _curvePad,
        size.width,
        _curveAreaHeight - 2 * _curvePad,
      ),
      minSeconds: profile.isEmpty ? 0 : profile.first.timestamp.toDouble(),
      maxSeconds: profile.isEmpty ? 1 : profile.last.timestamp.toDouble(),
      minDepthMeters: 0,
      maxDepthMeters: maxDepth <= 0 ? 1 : maxDepth,
    );
  }

  /// The mapping the curve is drawn through at this [morph].
  PlotMapping mappingFor(Size size) {
    final own = _own(size);
    final start = from;
    return start == null ? own : PlotMapping.lerp(start, own, morph);
  }

  /// Where the curve is clipped while it morphs: from the chart's plot (the
  /// chart clips its line there, so a zoomed-in chart hides the rest of the
  /// dive) to the strip's whole curve area. Null without a chart plot.
  Rect? clipFor(Size size) {
    final start = from;
    if (start == null) return null;
    final curveArea = Rect.fromLTWH(0, 0, size.width, _curveAreaHeight);
    return Rect.lerp(start.rect, curveArea, morph);
  }

  /// The shaded area, as the full chart draws it: between the depth line and
  /// the bottom of the plot (the water below the diver), clear above.
  Path? fillPathFor(Size size) {
    if (profile.length < 2) return null;
    final m = mappingFor(size);
    final bottomY = m.rect.bottom;
    final first = m.project(profile.first.timestamp, profile.first.depth);
    final path = Path()..moveTo(first.dx, bottomY);
    for (final p in profile) {
      final o = m.project(p.timestamp, p.depth);
      path.lineTo(o.dx, o.dy);
    }
    final last = m.project(profile.last.timestamp, profile.last.depth);
    return path
      ..lineTo(last.dx, bottomY)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;
    final m = mappingFor(size);
    final clip = clipFor(size);
    if (clip != null) canvas.clipRect(clip);
    final line = Path();
    for (var i = 0; i < profile.length; i++) {
      final o = m.project(profile[i].timestamp, profile[i].depth);
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      fillPathFor(size)!,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fillColors,
        ).createShader(m.rect),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = kProfileDepthLineWidth,
    );

    final selected = selectedSeconds;
    if (selected == null) return;
    final depth = profileDepthAt(profile, selected);
    final top = m.project(selected, m.minDepthMeters);
    final bottom = m.project(selected, m.maxDepthMeters);
    canvas.drawLine(
      Offset(top.dx, math.max(0, top.dy)),
      Offset(bottom.dx, math.min(size.height, bottom.dy)),
      Paint()
        ..color = markerColor
        ..strokeWidth = 1.5,
    );
    if (depth != null) {
      canvas.drawCircle(
        m.project(selected, depth),
        4,
        Paint()..color = markerColor,
      );
    }
  }

  @override
  bool shouldRepaint(PinnedStripPainter old) =>
      old.profile != profile ||
      old.selectedSeconds != selectedSeconds ||
      old.curveColor != curveColor ||
      !listEquals(old.fillColors, fillColors) ||
      old.markerColor != markerColor ||
      old.morph != morph ||
      old.from != from;
}
