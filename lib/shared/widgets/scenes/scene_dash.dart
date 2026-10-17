import 'package:flutter/painting.dart';

/// A copy of [source] cut into dashes of length [dash] separated by [gap].
///
/// [phase] moves the whole pattern forward along the path, so a growing
/// phase makes the dashes creep from the path's start towards its end. It
/// wraps modulo `dash + gap`.
Path dashedPath(
  Path source, {
  required double dash,
  required double gap,
  double phase = 0,
}) {
  final period = dash + gap;
  final shift = phase % period;
  final result = Path();
  for (final metric in source.computeMetrics()) {
    for (var start = shift - period; start < metric.length; start += period) {
      final from = start < 0 ? 0.0 : start;
      final to = start + dash > metric.length ? metric.length : start + dash;
      if (to > from) {
        result.addPath(metric.extractPath(from, to), Offset.zero);
      }
    }
  }
  return result;
}
