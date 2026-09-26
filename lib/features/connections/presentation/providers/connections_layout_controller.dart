import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

enum GraphLayoutMode { web, ego }

/// Owns the live layout and advances it a bounded number of iterations per
/// frame until it settles. Listeners repaint on every notification.
class ConnectionsLayoutController extends ChangeNotifier {
  ConnectionsLayoutController({
    required TickerProvider vsync,
    this.iterationsPerTick = 12,
  }) {
    _ticker = vsync.createTicker(_onTick);
  }

  final int iterationsPerTick;
  late final Ticker _ticker;

  ConnectionGraph _graph = ConnectionGraph.empty;
  GraphLayoutMode _mode = GraphLayoutMode.web;
  WholeWebLayout? _web;
  LayoutFrame _frame = LayoutFrame.empty;

  LayoutFrame get frame => _frame;
  GraphLayoutMode get mode => _mode;
  bool get settled => _web?.settled ?? true;

  /// Replaces the graph. In web mode the previous frame seeds the new layout
  /// when [warmStart] is true, so existing nodes barely move.
  void setGraph(
    ConnectionGraph graph, {
    required GraphLayoutMode mode,
    NodeRef? focus,
    bool warmStart = true,
  }) {
    final previous = _frame.positions;
    _graph = graph;
    _mode = mode;
    if (mode == GraphLayoutMode.ego && focus != null) {
      _web = null;
      _frame = RadialLayout.compute(
        focus: focus,
        nodes: graph.nodes,
        edges: graph.edges,
      );
      _stopTicker();
      notifyListeners();
      return;
    }
    _web = WholeWebLayout(
      nodes: _byDives(graph),
      edges: graph.edges,
      initialPositions: warmStart ? previous : const {},
    );
    _frame = _web!.frame;
    _syncTicker();
    notifyListeners();
  }

  void moveNode(NodeRef ref, GraphPoint to) {
    final web = _web;
    if (web == null) return;
    web.moveNode(ref, to);
    _frame = web.frame;
    _syncTicker();
    notifyListeners();
  }

  /// Clears pins and lays the current graph out again from its seed.
  void relayout() {
    if (_mode == GraphLayoutMode.ego) return;
    _web = WholeWebLayout(nodes: _byDives(_graph), edges: _graph.edges);
    _frame = _web!.frame;
    _syncTicker();
    notifyListeners();
  }

  /// One tick's worth of work without a ticker, for tests.
  void stepForTest([int? iterations]) =>
      _advance(iterations ?? iterationsPerTick);

  void _onTick(Duration _) => _advance(iterationsPerTick);

  void _advance(int iterations) {
    final web = _web;
    if (web == null || web.settled) {
      _stopTicker();
      return;
    }
    web.advance(iterations);
    _frame = web.frame;
    if (web.settled) _stopTicker();
    notifyListeners();
  }

  void _syncTicker() {
    if (settled) {
      _stopTicker();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _stopTicker() {
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Busiest first, then by name, so the island grid leads with the
  /// entities the diver knows best.
  static List<NodeRef> _byDives(ConnectionGraph graph) =>
      ([...graph.nodes]..sort((a, b) {
            final byDives = b.diveCount.compareTo(a.diveCount);
            return byDives != 0 ? byDives : a.label.compareTo(b.label);
          }))
          .map((n) => n.ref)
          .toList();
}
