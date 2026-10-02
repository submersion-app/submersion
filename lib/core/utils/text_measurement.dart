import 'package:flutter/widgets.dart';

/// The width [text] needs on one line in [style], for a layout decision made
/// before the text is actually painted (fits-on-one-row checks, breakpoints).
double measureTextWidth(
  String text,
  TextStyle style,
  TextDirection direction,
  TextScaler textScaler,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
