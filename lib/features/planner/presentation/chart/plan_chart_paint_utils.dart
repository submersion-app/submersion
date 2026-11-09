import 'dart:math' as math;

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
///
/// There are at most [maxRows] rows, so a run of switches never walks down
/// over the profile. Once every row is taken, a pill goes on the row whose
/// pills end furthest left, where it covers the least.
List<int> gasFlagRows(
  List<({double left, double right})> spans, {
  double gap = 4,
  int maxRows = 3,
}) {
  final rows = <List<({double left, double right})>>[];
  final result = <int>[];
  for (final span in spans) {
    bool clears(({double left, double right}) other) =>
        span.left >= other.right + gap || span.right + gap <= other.left;
    var row = rows.indexWhere((placed) => placed.every(clears));
    if (row < 0 && rows.length < maxRows) {
      row = rows.length;
      rows.add([]);
    }
    if (row < 0) {
      double end(List<({double left, double right})> placed) =>
          placed.map((p) => p.right).reduce(math.max);
      row = 0;
      for (var i = 1; i < rows.length; i++) {
        if (end(rows[i]) < end(rows[row])) row = i;
      }
    }
    rows[row].add(span);
    result.add(row);
  }
  return result;
}

/// Where each gas-switch flag's pill of [sizes] goes, for stems at [xs]:
/// just right of its stem, kept inside [plot] so a switch near the end of
/// the dive does not run off the chart, on the row [gasFlagRows] gives it.
List<Rect> gasFlagPills({
  required List<double> xs,
  required List<Size> sizes,
  required Rect plot,
  double gap = 4,
  int maxRows = 3,
}) {
  assert(xs.length == sizes.length);
  final lefts = [
    for (var i = 0; i < xs.length; i++)
      math.max(plot.left, math.min(xs[i] + 4, plot.right - sizes[i].width)),
  ];
  final rows = gasFlagRows(
    [
      for (var i = 0; i < xs.length; i++)
        (left: lefts[i], right: lefts[i] + sizes[i].width),
    ],
    gap: gap,
    maxRows: maxRows,
  );
  final rowHeight = sizes.isEmpty
      ? 0.0
      : sizes.map((s) => s.height).reduce(math.max);
  return [
    for (var i = 0; i < xs.length; i++)
      Rect.fromLTWH(
        lefts[i],
        plot.top + 4 + rows[i] * (rowHeight + gap),
        sizes[i].width,
        sizes[i].height,
      ),
  ];
}
