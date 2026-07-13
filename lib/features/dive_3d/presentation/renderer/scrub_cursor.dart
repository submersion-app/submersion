import 'package:flutter/material.dart';

/// Draws the scrub cursor dot (light fill + dark outline) at [center].
/// Shared by the default scrub-cursor painter and the tissue chrome painter so
/// both scenes draw an identical cursor.
void paintScrubCursor(Canvas canvas, Offset center) {
  canvas.drawCircle(
    center,
    7,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    center,
    7,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}
