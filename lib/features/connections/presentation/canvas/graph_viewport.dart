import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/connections/domain/layout/graph_point.dart';

/// Graph-space to screen-space transform: `screen = graph * scale + offset`.
class GraphViewport {
  const GraphViewport({this.scale = 1, this.offset = Offset.zero});

  static const double minScale = 0.15;
  static const double maxScale = 6;

  final double scale;
  final Offset offset;

  Offset toScreen(GraphPoint p) =>
      Offset(p.x * scale + offset.dx, p.y * scale + offset.dy);

  GraphPoint toGraph(Offset s) =>
      GraphPoint((s.dx - offset.dx) / scale, (s.dy - offset.dy) / scale);

  /// Scale so [bounds] fits inside [size] less [padding], centred.
  GraphViewport fitted(GraphBounds bounds, Size size, {double padding = 48}) {
    final w = math.max(1.0, bounds.width);
    final h = math.max(1.0, bounds.height);
    final raw = bounds.isEmpty
        ? 1.0
        : math.min(
            (size.width - 2 * padding) / w,
            (size.height - 2 * padding) / h,
          );
    final s = raw.clamp(minScale, maxScale);
    final c = bounds.center;
    return GraphViewport(
      scale: s,
      offset: Offset(size.width / 2 - c.x * s, size.height / 2 - c.y * s),
    );
  }

  /// Multiplies the scale by [factor] keeping the graph point under [focal]
  /// fixed on screen.
  GraphViewport zoomedAt(double factor, Offset focal) {
    final next = (scale * factor).clamp(minScale, maxScale);
    final ratio = next / scale;
    return GraphViewport(scale: next, offset: focal - (focal - offset) * ratio);
  }

  GraphViewport panned(Offset delta) =>
      GraphViewport(scale: scale, offset: offset + delta);

  /// Keeps at least [minVisible] px of the graph inside [size] on each axis.
  GraphViewport clampedTo(
    GraphBounds bounds,
    Size size, {
    double minVisible = 48,
  }) {
    if (bounds.isEmpty) return this;
    final left = bounds.left * scale + offset.dx;
    final right = bounds.right * scale + offset.dx;
    final top = bounds.top * scale + offset.dy;
    final bottom = bounds.bottom * scale + offset.dy;
    var dx = 0.0;
    var dy = 0.0;
    if (right < minVisible) dx = minVisible - right;
    if (left > size.width - minVisible) dx = size.width - minVisible - left;
    if (bottom < minVisible) dy = minVisible - bottom;
    if (top > size.height - minVisible) dy = size.height - minVisible - top;
    if (dx == 0 && dy == 0) return this;
    return GraphViewport(scale: scale, offset: offset + Offset(dx, dy));
  }

  /// Fits [bounds] plus screen-space overhangs (node radii and labels that
  /// extend past the node centres) inside [size] less [margin], centred.
  GraphViewport fittedWithOverhang(
    GraphBounds bounds,
    Size size, {
    required double left,
    required double top,
    required double right,
    required double bottom,
    double margin = 24,
  }) {
    final availW = math.max(1.0, size.width - 2 * margin - left - right);
    final availH = math.max(1.0, size.height - 2 * margin - top - bottom);
    final w = math.max(1.0, bounds.width);
    final h = math.max(1.0, bounds.height);
    final s = bounds.isEmpty
        ? 1.0
        : math.min(availW / w, availH / h).clamp(minScale, maxScale);
    final boxW = bounds.width * s;
    final boxH = bounds.height * s;
    final x0 = margin + left + (availW - boxW) / 2;
    final y0 = margin + top + (availH - boxH) / 2;
    return GraphViewport(
      scale: s,
      offset: Offset(x0 - bounds.left * s, y0 - bounds.top * s),
    );
  }

  bool isCloseTo(GraphViewport other) =>
      (scale / other.scale - 1).abs() < 0.01 &&
      (offset - other.offset).distance < 1;
}
