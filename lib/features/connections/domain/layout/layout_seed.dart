import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
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

  /// Nodes on a jittered ring, each kind in its own contiguous sector (kinds
  /// in enum order, sectors sized by count, members in wire order). The
  /// jitter is a fraction of one member's slot, so kinds never interleave.
  static Map<NodeRef, GraphPoint> circle(
    Iterable<NodeRef> refs, {
    double radius = 200,
  }) {
    final sorted = refs.toList()..sort((a, b) => a.wire.compareTo(b.wire));
    if (sorted.isEmpty) return const {};
    final rng = math.Random(seedFor(sorted));
    final byKind = <ConnectionKind, List<NodeRef>>{};
    for (final r in sorted) {
      byKind.putIfAbsent(r.kind, () => []).add(r);
    }
    final kinds = byKind.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final n = sorted.length;
    final out = <NodeRef, GraphPoint>{};
    var start = 0.0;
    for (final k in kinds) {
      final members = byKind[k]!;
      final span = 2 * math.pi * members.length / n;
      // Slot i begins at its own start (as the phase 1 ring did), so a lone
      // node seeds at angle 0 and a warm start nudges it the same way. The
      // jitter never exceeds a tenth of one slot, so kinds cannot interleave.
      final slot = span / members.length;
      for (var i = 0; i < members.length; i++) {
        final angle =
            start +
            slot * i +
            (rng.nextDouble() - 0.5) * 0.2 * math.min(1.0, slot);
        final r = radius * (0.8 + 0.4 * rng.nextDouble());
        out[members[i]] = GraphPoint(r * math.cos(angle), r * math.sin(angle));
      }
      start += span;
    }
    return out;
  }
}
