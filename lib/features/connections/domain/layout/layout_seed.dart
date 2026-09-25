import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

/// Deterministic starting positions: the same node set lays out the same way
/// on every device and in every test run.
class LayoutSeed {
  const LayoutSeed._();

  /// FNV-1a over the sorted wire names. Not `String.hashCode`, which is not
  /// guaranteed stable across platforms.
  static int seedFor(Iterable<NodeRef> refs) {
    final wires = refs.map((r) => r.wire).toList()..sort();
    var hash = 0x811C9DC5;
    for (final w in wires) {
      for (final unit in w.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0x7FFFFFFF;
      }
      hash ^= 0x2C;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Nodes on a jittered ring, in sorted order.
  static Map<NodeRef, GraphPoint> circle(
    Iterable<NodeRef> refs, {
    double radius = 200,
  }) {
    final sorted = refs.toList()..sort((a, b) => a.wire.compareTo(b.wire));
    if (sorted.isEmpty) return const {};
    final rng = math.Random(seedFor(sorted));
    final n = sorted.length;
    final out = <NodeRef, GraphPoint>{};
    for (var i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n + (rng.nextDouble() - 0.5) * 0.2;
      final r = radius * (0.8 + 0.4 * rng.nextDouble());
      out[sorted[i]] = GraphPoint(r * math.cos(angle), r * math.sin(angle));
    }
    return out;
  }
}
