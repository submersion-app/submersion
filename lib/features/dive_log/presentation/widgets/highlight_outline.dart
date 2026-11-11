import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// The two-tone outline the tissue charts draw around the highlighted
/// compartment (the bar chart's bar and the heat map's row) and the heat
/// map's time cursor (issue #4431).
///
/// The charts can put any colour under the outline. The heat map's Default
/// scale runs through pure black near the inspired gas pressure and white
/// past the M-value, and the bars run from green to red. A single outline
/// colour, such as the theme's text colour, vanishes on some of them in
/// either theme. A dark core inside a light halo keeps one of the two in
/// contrast with whatever lies underneath, so the outline depends on neither
/// the colours nor the theme.
abstract final class HighlightOutline {
  /// The light band painted first, wider than the core so it shows on both
  /// sides of it.
  static const Color haloColor = Color(0xF2FFFFFF);

  /// The dark line painted down the middle of the halo.
  static const Color coreColor = Color(0xFF111111);

  static const double haloWidth = 3.5;
  static const double coreWidth = 1.5;

  /// Corner radius of the outline around a bar.
  static const Radius barRadius = Radius.circular(2);

  /// Paints the outline with its band centred on [rrect].
  static void paintRRect(Canvas canvas, RRect rrect) {
    canvas.drawRRect(rrect, _halo);
    canvas.drawRRect(rrect, _core);
  }

  /// Paints the outline as a line from [p1] to [p2].
  static void paintLine(Canvas canvas, Offset p1, Offset p2) {
    canvas.drawLine(p1, p2, _halo);
    canvas.drawLine(p1, p2, _core);
  }

  // Built once and never mutated: the outline's style is constant.
  static final Paint _halo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = haloWidth
    ..color = haloColor;

  static final Paint _core = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = coreWidth
    ..color = coreColor;
}

/// Paints [HighlightOutline] just inside the box it is given, so a bar keeps
/// its size and does not overlap its neighbours when highlighted.
class HighlightOutlinePainter extends CustomPainter {
  const HighlightOutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the band so the whole band lies inside the box. A box
    // thinner than the band (a nearly empty bar) is inset by at most half
    // its own size, which centres the band on it; half the stroke width
    // would still spill over its edges into the chart around it, so the
    // band is clipped to the box.
    final box = Offset.zero & size;
    final inset = math.min(
      HighlightOutline.haloWidth / 2,
      size.shortestSide / 2,
    );
    canvas.save();
    canvas.clipRect(box);
    HighlightOutline.paintRRect(
      canvas,
      RRect.fromRectAndRadius(box.deflate(inset), HighlightOutline.barRadius),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(HighlightOutlinePainter oldDelegate) => false;
}
