import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

class ConnectionsHitTester {
  const ConnectionsHitTester._();

  /// The nearest node whose drawn radius (never below [minRadius]) plus
  /// [slop] contains [point], in screen space.
  static NodeRef? hitNode(
    Offset point, {
    required LayoutFrame frame,
    required GraphViewport viewport,
    required double Function(NodeRef ref) radiusOf,
    double slop = 12,
    double minRadius = 18,
  }) {
    NodeRef? best;
    var bestDistance = double.infinity;
    for (final entry in frame.positions.entries) {
      final d = (viewport.toScreen(entry.value) - point).distance;
      final reach = math.max(radiusOf(entry.key), minRadius) + slop;
      if (d <= reach && d < bestDistance) {
        best = entry.key;
        bestDistance = d;
      }
    }
    return best;
  }

  /// The nearest edge whose segment passes within [tolerance] of [point].
  static ConnectionEdge? hitEdge(
    Offset point, {
    required LayoutFrame frame,
    required GraphViewport viewport,
    required List<ConnectionEdge> edges,
    double tolerance = 10,
  }) {
    ConnectionEdge? best;
    var bestDistance = double.infinity;
    for (final e in edges) {
      final a = frame.positions[e.source];
      final b = frame.positions[e.target];
      if (a == null || b == null) continue;
      final d = distanceToSegment(
        point,
        viewport.toScreen(a),
        viewport.toScreen(b),
      );
      if (d <= tolerance && d < bestDistance) {
        best = e;
        bestDistance = d;
      }
    }
    return best;
  }

  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    final proj = a + ab * t;
    return (p - proj).distance;
  }
}
