import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A position in graph space. Deliberately not `dart:ui` Offset so the layout
/// layer stays free of Flutter.
class GraphPoint extends Equatable {
  const GraphPoint(this.x, this.y);

  static const zero = GraphPoint(0, 0);

  final double x;
  final double y;

  GraphPoint operator +(GraphPoint o) => GraphPoint(x + o.x, y + o.y);
  GraphPoint operator -(GraphPoint o) => GraphPoint(x - o.x, y - o.y);
  GraphPoint scaled(double f) => GraphPoint(x * f, y * f);

  double get length => math.sqrt(x * x + y * y);
  double distanceTo(GraphPoint o) => (this - o).length;
  bool get isFinite => x.isFinite && y.isFinite;

  @override
  List<Object?> get props => [x, y];
}

class GraphBounds extends Equatable {
  const GraphBounds(this.left, this.top, this.right, this.bottom);

  static const zero = GraphBounds(0, 0, 0, 0);

  final double left;
  final double top;
  final double right;
  final double bottom;

  factory GraphBounds.of(Iterable<GraphPoint> points) {
    var first = true;
    var l = 0.0, t = 0.0, r = 0.0, b = 0.0;
    for (final p in points) {
      if (first) {
        l = r = p.x;
        t = b = p.y;
        first = false;
        continue;
      }
      if (p.x < l) l = p.x;
      if (p.x > r) r = p.x;
      if (p.y < t) t = p.y;
      if (p.y > b) b = p.y;
    }
    return first ? zero : GraphBounds(l, t, r, b);
  }

  double get width => right - left;
  double get height => bottom - top;
  bool get isEmpty => width == 0 && height == 0;
  GraphPoint get center => GraphPoint((left + right) / 2, (top + bottom) / 2);

  GraphBounds inflate(double pad) =>
      GraphBounds(left - pad, top - pad, right + pad, bottom + pad);

  GraphBounds translate(double dx, double dy) =>
      GraphBounds(left + dx, top + dy, right + dx, bottom + dy);

  @override
  List<Object?> get props => [left, top, right, bottom];
}
