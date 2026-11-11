import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The outline the tissue charts draw around the highlighted compartment
/// (the bar chart's bar and the heat map's row), also used for the heat
/// map's time cursor (issue #4431).
///
/// It is a single 2 px line in the theme's accent colour, except on the heat
/// map in light mode, where it is black. The outline it replaced was a
/// thinner, translucent theme text colour drawn across the row's own edge,
/// which vanished on the heat map's Default scale: that scale runs through
/// pure black and dark purple near the inspired gas pressure and white past
/// the M-value.
abstract final class HighlightOutline {
  static const double width = 2.0;

  /// Corner radius of the outline around a bar.
  static const Radius barRadius = Radius.circular(2);

  /// The outline's colour under [scheme].
  static Color colorOf(ColorScheme scheme) => scheme.primary;

  /// The heat map's outline and time cursor colour under [scheme].
  ///
  /// Black in the light theme, where the accent is a dark blue that is hard
  /// to see on the scale's cells. The dark theme's accent is a light blue
  /// that stands out on them.
  static Color heatMapColorOf(ColorScheme scheme) =>
      scheme.brightness == Brightness.light ? Colors.black : scheme.primary;

  /// A stroke paint for the outline in [color].
  static Paint strokeOf(Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color;
}

/// Paints [HighlightOutline] just inside the box it is given, so a bar keeps
/// its size and does not overlap its neighbours when highlighted.
class HighlightOutlinePainter extends CustomPainter {
  final Color color;

  const HighlightOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the line so the whole line lies inside the box. A box
    // thinner than the line (a nearly empty bar) is inset by at most half
    // its own size, which centres the line on it; half the stroke width
    // would still spill over its edges into the chart around it, so the
    // line is clipped to the box.
    final box = Offset.zero & size;
    final inset = math.min(HighlightOutline.width / 2, size.shortestSide / 2);
    canvas.save();
    canvas.clipRect(box);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.deflate(inset), HighlightOutline.barRadius),
      HighlightOutline.strokeOf(color),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(HighlightOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
