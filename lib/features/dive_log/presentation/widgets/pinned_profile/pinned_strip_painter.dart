import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// Height of the strip's values row, under its curve.
const double kPinnedStripRowHeight = 16;

/// Breathing room above and below the strip's curve.
const double _curvePad = 4;

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
    required this.fillColor,
    required this.markerColor,
    this.from,
    this.morph = 1,
  });

  final List<DiveProfilePoint> profile;
  final int? selectedSeconds;
  final Color curveColor;
  final Color fillColor;
  final Color markerColor;
  final PlotMapping? from;
  final double morph;

  /// The strip's own mapping: the whole dive across the curve area above the
  /// values row, surface to deepest point down.
  PlotMapping _own(Size size) {
    var maxDepth = 0.0;
    for (final p in profile) {
      maxDepth = math.max(maxDepth, p.depth);
    }
    final curveHeight = math.max(0.0, size.height - kPinnedStripRowHeight);
    return PlotMapping(
      rect: Rect.fromLTWH(
        0,
        _curvePad,
        size.width,
        math.max(1.0, curveHeight - 2 * _curvePad),
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
    final curveArea = Rect.fromLTWH(
      0,
      0,
      size.width,
      math.max(0.0, size.height - kPinnedStripRowHeight),
    );
    return Rect.lerp(start.rect, curveArea, morph);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;
    final m = mappingFor(size);
    final clip = clipFor(size);
    if (clip != null) canvas.clipRect(clip);
    final surfaceY = m.project(0, 0).dy;

    final line = Path();
    for (var i = 0; i < profile.length; i++) {
      final o = m.project(profile[i].timestamp, profile[i].depth);
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    final first = m.project(profile.first.timestamp, 0);
    final last = m.project(profile.last.timestamp, 0);
    final fill = Path()
      ..moveTo(first.dx, surfaceY)
      ..addPath(line, Offset.zero)
      ..lineTo(last.dx, surfaceY)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
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
      old.fillColor != fillColor ||
      old.markerColor != markerColor ||
      old.morph != morph ||
      old.from != from;
}
