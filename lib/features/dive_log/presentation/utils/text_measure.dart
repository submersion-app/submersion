import 'package:flutter/painting.dart';

/// The laid-out size of [text] on one line in [style], as it will paint
/// under [direction] and [scaler]. The width is rounded up so text sized to
/// it never clips by a fraction of a pixel.
Size measureSingleLine(
  String text,
  TextStyle? style, {
  required TextDirection direction,
  required TextScaler scaler,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final size = Size(painter.width.ceilToDouble(), painter.height);
  painter.dispose();
  return size;
}
