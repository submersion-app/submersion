import 'package:flutter/painting.dart';

/// A copy of [source] consisting of dash segments of length [dash] separated
/// by [gap]. Used for ceiling boundaries, gas-switch stems, ghost profiles,
/// and the mean-depth line.
Path dashedPath(Path source, {required double dash, required double gap}) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length);
      result.addPath(metric.extractPath(distance, end), Offset.zero);
      distance += dash + gap;
    }
  }
  return result;
}

/// Lays out [text] once; callers paint via `painter.paint(canvas, offset)`.
TextPainter layoutLabel(String text, TextStyle style, TextDirection direction) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
  )..layout();
  return painter;
}
