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

/// The row each gas-switch flag's pill sits on, counted down from the top of
/// the plot, for pills spanning [spans] horizontally: the first row where it
/// clears every pill already there by [gap], so switches close in time
/// (EAN40 on the way up, EAN80 at the stop a minute later) never print over
/// each other (issue #4078).
List<int> gasFlagRows(
  List<({double left, double right})> spans, {
  double gap = 4,
}) {
  final rows = <List<({double left, double right})>>[];
  final result = <int>[];
  for (final span in spans) {
    bool clears(({double left, double right}) other) =>
        span.left >= other.right + gap || span.right + gap <= other.left;
    var row = rows.indexWhere((placed) => placed.every(clears));
    if (row < 0) {
      row = rows.length;
      rows.add([]);
    }
    rows[row].add(span);
    result.add(row);
  }
  return result;
}
