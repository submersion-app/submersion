import 'dart:math' as math;

import '../entities/connection_edge.dart';
import '../entities/node_ref.dart';
import 'graph_point.dart';
import 'layout_frame.dart';
import 'layout_seed.dart';

/// Fruchterman-Reingold style force layout, stepped by the caller.
///
/// Pairwise repulsion, spring attraction along edges (ideal length shrinks
/// with the logarithm of the weight), a weak pull to the origin, and a
/// temperature that cools linearly to zero over [maxIterations]. Deterministic
/// for a given node set and initial positions.
class ForceLayout {
  ForceLayout({
    required List<NodeRef> nodes,
    required List<ConnectionEdge> edges,
    Map<NodeRef, GraphPoint> initialPositions = const {},
    Set<NodeRef> pinned = const {},
    this.maxIterations = 300,
    this.settleEpsilon = 0.5,
  }) : _nodes = List.unmodifiable(nodes),
       _pinned = {...pinned} {
    final nodeSet = _nodes.toSet();
    _edges = edges
        .where((e) => nodeSet.contains(e.source) && nodeSet.contains(e.target))
        .toList();
    _index = {for (var i = 0; i < _nodes.length; i++) _nodes[i]: i};
    _area = math.max(40000.0, 12000.0 * _nodes.length);
    _k = math.sqrt(_area / math.max(1, _nodes.length));
    _temperature = math.sqrt(_area) / 10;
    _positions = _seed(initialPositions);
    _seedPositions = List.of(_positions);
    _frame = _snapshot();
  }

  final int maxIterations;
  final double settleEpsilon;

  final List<NodeRef> _nodes;
  late final List<ConnectionEdge> _edges;
  late final Map<NodeRef, int> _index;
  late final double _area;
  late final double _k;
  late final List<GraphPoint> _seedPositions;
  late List<GraphPoint> _positions;
  final Set<NodeRef> _pinned;
  late double _temperature;
  int _iteration = 0;
  double _lastMaxDisplacement = double.infinity;
  late LayoutFrame _frame;

  LayoutFrame get frame => _frame;
  int get iteration => _iteration;
  Set<NodeRef> get pinned => Set.unmodifiable(_pinned);

  bool get settled =>
      _nodes.length <= 1 ||
      _iteration >= maxIterations ||
      (_iteration > 0 && _lastMaxDisplacement < settleEpsilon);

  /// Known positions are kept; new nodes start at the centroid of their
  /// already-placed neighbours, or on the seed ring when they have none.
  List<GraphPoint> _seed(Map<NodeRef, GraphPoint> initial) {
    final missing = _nodes.where((n) => !initial.containsKey(n)).toList();
    final ring = LayoutSeed.circle(missing, radius: _k * 2);
    final out = List<GraphPoint>.filled(_nodes.length, GraphPoint.zero);
    for (var i = 0; i < _nodes.length; i++) {
      final n = _nodes[i];
      final known = initial[n];
      if (known != null && known.isFinite) {
        out[i] = known;
        continue;
      }
      var sum = GraphPoint.zero;
      var count = 0;
      for (final e in _edges) {
        final other = e.otherEnd(n);
        final p = other == null ? null : initial[other];
        if (p != null && p.isFinite) {
          sum = sum + p;
          count++;
        }
      }
      out[i] = count > 0
          ? sum.scaled(1 / count) + (ring[n] ?? GraphPoint.zero).scaled(0.15)
          : ring[n] ?? GraphPoint.zero;
    }
    return out;
  }

  void advance(int iterations) {
    for (var s = 0; s < iterations && !settled; s++) {
      _step();
    }
    _frame = _snapshot();
  }

  void _step() {
    final n = _nodes.length;
    final disp = List<GraphPoint>.filled(n, GraphPoint.zero);
    final k2 = _k * _k;

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var delta = _positions[i] - _positions[j];
        var d = delta.length;
        if (d < 0.01) {
          // Coincident nodes: nudge apart deterministically by index.
          final angle = (i * 7 + j * 13) % 360 * math.pi / 180;
          delta = GraphPoint(math.cos(angle), math.sin(angle));
          d = 1.0;
        }
        final force = k2 / d;
        final push = delta.scaled(force / d);
        disp[i] = disp[i] + push;
        disp[j] = disp[j] - push;
      }
    }

    for (final e in _edges) {
      final i = _index[e.source]!;
      final j = _index[e.target]!;
      final delta = _positions[i] - _positions[j];
      final d = math.max(delta.length, 0.01);
      final ideal = _k / (1 + math.log(e.weight.toDouble()));
      final force = d * d / ideal;
      final pull = delta.scaled(force / d);
      disp[i] = disp[i] - pull;
      disp[j] = disp[j] + pull;
    }

    var maxMove = 0.0;
    for (var i = 0; i < n; i++) {
      if (_pinned.contains(_nodes[i])) continue;
      final gravity = _positions[i].scaled(-0.02);
      final total = disp[i] + gravity;
      final len = total.length;
      if (len == 0) continue;
      final step = math.min(len, _temperature);
      var next = _positions[i] + total.scaled(step / len);
      if (!next.isFinite) next = _seedPositions[i];
      final moved = next.distanceTo(_positions[i]);
      if (moved > maxMove) maxMove = moved;
      _positions[i] = next;
    }

    _iteration++;
    _lastMaxDisplacement = maxMove;
    _temperature = math.sqrt(_area) / 10 * (1 - _iteration / maxIterations);
  }

  void pin(NodeRef ref, GraphPoint at) {
    final i = _index[ref];
    if (i == null) return;
    _positions[i] = at;
    _pinned.add(ref);
    _lastMaxDisplacement = double.infinity;
    _temperature = math.max(_temperature, _k / 4);
    if (_iteration >= maxIterations) _iteration = maxIterations ~/ 2;
    _frame = _snapshot();
  }

  /// Alias for [pin]: a dragged node stays where it was dropped.
  void moveNode(NodeRef ref, GraphPoint at) => pin(ref, at);

  void unpin(NodeRef ref) => _pinned.remove(ref);

  void clearPins() {
    _pinned.clear();
    _lastMaxDisplacement = double.infinity;
    _temperature = math.max(_temperature, _k / 4);
    if (_iteration >= maxIterations) _iteration = maxIterations ~/ 2;
  }

  LayoutFrame _snapshot() => LayoutFrame.fromPositions({
    for (var i = 0; i < _nodes.length; i++) _nodes[i]: _positions[i],
  }, settled: settled);
}
