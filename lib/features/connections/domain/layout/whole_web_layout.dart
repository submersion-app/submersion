import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/force_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/island_packer.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

/// One [ForceLayout] per connected component of two or more nodes, packed
/// side by side, with single nodes in a grid below them.
///
/// Packing offsets are recomputed on every frame until every island has
/// settled, then frozen, so a node the user drags afterwards stays where it
/// was dropped instead of being re-shelved.
class WholeWebLayout {
  WholeWebLayout({
    required List<NodeRef> nodes,
    required List<ConnectionEdge> edges,
    Map<NodeRef, GraphPoint> initialPositions = const {},
    int maxIterations = 300,
  }) {
    final order = {for (var i = 0; i < nodes.length; i++) nodes[i]: i};
    final comps = IslandPacker.components(nodes, edges);
    _singles = [
      for (final c in comps)
        if (c.length == 1) c.single,
    ]..sort((a, b) => order[a]!.compareTo(order[b]!));
    for (final comp in comps.where((c) => c.length > 1)) {
      final members = comp.toSet();
      _layouts.add(
        ForceLayout(
          nodes: comp,
          edges: edges
              .where(
                (e) => members.contains(e.source) && members.contains(e.target),
              )
              .toList(),
          initialPositions: {
            for (final n in comp)
              if (initialPositions[n] != null) n: initialPositions[n]!,
          },
          maxIterations: maxIterations,
        ),
      );
    }
    _offsets = List.filled(_layouts.length, GraphPoint.zero);
    _recompose();
  }

  final List<ForceLayout> _layouts = [];

  /// Nodes with no edge, in input order (the controller passes the busiest
  /// first). They need no simulation.
  late final List<NodeRef> _singles;
  final Map<NodeRef, GraphPoint> _singlePins = {};
  late List<GraphPoint> _offsets;
  bool _frozen = false;
  LayoutFrame _frame = LayoutFrame.empty;

  LayoutFrame get frame => _frame;
  bool get settled => _layouts.every((l) => l.settled);

  void advance(int iterations) {
    for (final l in _layouts) {
      l.advance(iterations);
    }
    _recompose();
  }

  /// Pins [ref] at a world-space point.
  void moveNode(NodeRef ref, GraphPoint world) {
    if (_singles.contains(ref)) {
      _singlePins[ref] = world;
      _recompose();
      return;
    }
    for (var i = 0; i < _layouts.length; i++) {
      if (_layouts[i].frame.positions.containsKey(ref)) {
        _layouts[i].moveNode(ref, world - _offsets[i]);
        _recompose();
        return;
      }
    }
  }

  void clearPins() {
    for (final l in _layouts) {
      l.clearPins();
    }
    _singlePins.clear();
    _frozen = false;
    _recompose();
  }

  void _recompose() {
    if (!_frozen) {
      _offsets = IslandPacker.pack(_layouts.map((l) => l.frame).toList());
      if (settled) _frozen = true;
    }
    final positions = <NodeRef, GraphPoint>{};
    for (var i = 0; i < _layouts.length; i++) {
      for (final entry in _layouts[i].frame.positions.entries) {
        positions[entry.key] = entry.value + _offsets[i];
      }
    }
    if (_singles.isNotEmpty) {
      const gap = 90.0;
      final packed = GraphBounds.of(positions.values);
      final cols = math.max(1, (math.sqrt(_singles.length) * 1.6).ceil());
      final x0 = positions.isEmpty ? 0.0 : packed.left;
      final y0 = positions.isEmpty ? 0.0 : packed.bottom + gap;
      for (var i = 0; i < _singles.length; i++) {
        final ref = _singles[i];
        positions[ref] =
            _singlePins[ref] ??
            GraphPoint(x0 + (i % cols) * gap, y0 + (i ~/ cols) * gap);
      }
    }
    _frame = LayoutFrame.fromPositions(positions, settled: settled);
  }
}
