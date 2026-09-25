import '../entities/connection_edge.dart';
import '../entities/node_ref.dart';
import 'force_layout.dart';
import 'graph_point.dart';
import 'island_packer.dart';
import 'layout_frame.dart';

/// One [ForceLayout] per connected component, packed side by side.
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
    final comps = IslandPacker.components(nodes, edges);
    for (final comp in comps) {
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
    _frame = LayoutFrame.fromPositions(positions, settled: settled);
  }
}
