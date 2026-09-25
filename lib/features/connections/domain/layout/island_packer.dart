import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

/// Connected components and shelf packing of their bounding boxes.
class IslandPacker {
  const IslandPacker._();

  /// Components ordered by size descending, then by their smallest wire name,
  /// so the order is stable for equal sizes. Members keep [nodes] order.
  static List<List<NodeRef>> components(
    List<NodeRef> nodes,
    List<ConnectionEdge> edges,
  ) {
    final adjacency = <NodeRef, List<NodeRef>>{for (final n in nodes) n: []};
    for (final e in edges) {
      if (!adjacency.containsKey(e.source) ||
          !adjacency.containsKey(e.target)) {
        continue;
      }
      adjacency[e.source]!.add(e.target);
      adjacency[e.target]!.add(e.source);
    }
    final order = {for (var i = 0; i < nodes.length; i++) nodes[i]: i};
    final seen = <NodeRef>{};
    final out = <List<NodeRef>>[];
    for (final start in nodes) {
      if (!seen.add(start)) continue;
      final comp = <NodeRef>[start];
      final queue = [start];
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        for (final next in adjacency[cur]!) {
          if (seen.add(next)) {
            comp.add(next);
            queue.add(next);
          }
        }
      }
      comp.sort((a, b) => order[a]!.compareTo(order[b]!));
      out.add(comp);
    }
    String key(List<NodeRef> c) =>
        c.map((r) => r.wire).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    out.sort((a, b) {
      final bySize = b.length.compareTo(a.length);
      return bySize != 0 ? bySize : key(a).compareTo(key(b));
    });
    return out;
  }

  /// Offsets that place each frame's bounds on shelves without overlap,
  /// largest area first. The row width grows with the total area so the
  /// result is roughly square.
  static List<GraphPoint> pack(List<LayoutFrame> frames, {double gap = 60}) {
    if (frames.isEmpty) return const [];
    final order = List<int>.generate(frames.length, (i) => i)
      ..sort((i, j) {
        final a = frames[i].bounds.inflate(gap / 2);
        final b = frames[j].bounds.inflate(gap / 2);
        final byArea = (b.width * b.height).compareTo(a.width * a.height);
        return byArea != 0 ? byArea : i.compareTo(j);
      });
    var totalArea = 0.0;
    var widest = 0.0;
    for (final f in frames) {
      final b = f.bounds.inflate(gap / 2);
      totalArea += b.width * b.height;
      widest = math.max(widest, b.width);
    }
    final rowLimit = math.max(widest, math.sqrt(totalArea) * 1.4);
    final offsets = List<GraphPoint>.filled(frames.length, GraphPoint.zero);
    var x = 0.0, y = 0.0, rowHeight = 0.0;
    for (final i in order) {
      final b = frames[i].bounds.inflate(gap / 2);
      if (x > 0 && x + b.width > rowLimit) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      offsets[i] = GraphPoint(x - b.left, y - b.top);
      x += b.width;
      rowHeight = math.max(rowHeight, b.height);
    }
    return offsets;
  }
}
