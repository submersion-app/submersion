import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_morph.dart';
import 'package:submersion/features/connections/domain/layout/pinned_frame.dart';
import 'package:submersion/features/connections/domain/layout/static_layouts.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';

/// How long a refocus or layout morph and its camera glide take.
const Duration kRefocusDuration = Duration(milliseconds: 450);
const Curve kRefocusCurve = Curves.easeInOutCubic;

/// Owns the live layout. The web and clusters layouts advance a bounded
/// number of iterations per frame until they settle (so a big map never
/// blocks a frame); every other layout is computed at once and morphs in
/// from the previous frame. Dragged nodes are pinned
/// until the graph, the layout or the spacing changes, or [relayout].
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
  ConnectionsLayout _layout = ConnectionsLayout.web;

  /// Groups the caller already found for [_graph], reused by clusters
  /// instead of running label propagation again.
  GraphGroups? _groups;
  double _spacing = 1;
  WholeWebLayout? _web;

  /// A static layout's computed frame, before pins.
  LayoutFrame? _base;
  Map<NodeRef, GraphPoint> _pins = const {};
  LayoutFrame _frame = LayoutFrame.empty;

  /// The morph in flight, if any.
  LayoutFrame? _morphFrom;
  LayoutFrame? _morphTo;
  GraphPoint? _morphOrigin;
  Duration _morphElapsed = Duration.zero;

  LayoutFrame get frame => _frame;
  ConnectionsLayout get layout => _layout;
  bool get settled => _morphTo == null && (_web?.settled ?? true);

  /// Whether [relayout] would change anything: a live layout can always be
  /// laid out again; a computed one only while something is pinned. A
  /// separate listenable, so the button listening to it does not rebuild on
  /// every simulation tick.
  final ValueNotifier<bool> canRelayout = ValueNotifier(false);

  @override
  void notifyListeners() {
    canRelayout.value = _web != null || _pins.isNotEmpty;
    super.notifyListeners();
  }

  /// Replaces the graph, the layout or the spacing, releasing every pin.
  /// The web layout warm-starts from the previous frame when [warmStart]
  /// is true, so existing nodes barely move. Any other layout morphs from
  /// the previous frame over [kRefocusDuration] when [animate] is true, new
  /// nodes growing out of the focus.
  void setGraph(
    ConnectionGraph graph, {
    required ConnectionsLayout layout,
    NodeRef? focus,
    double spacing = 1,
    bool warmStart = true,
    bool animate = false,
    GraphGroups? groups,
  }) {
    final previous = _frame;
    _groups = groups;
    _graph = graph;
    _layout = layout;
    _spacing = spacing;
    _pins = const {};
    _morphTo = null;
    _morphFrom = null;
    if (_isLive(layout)) {
      _base = null;
      final web = _liveLayout(
        initialPositions: warmStart ? previous.positions : const {},
      );
      _web = web;
      _frame = web.frame;
      _syncTicker();
      notifyListeners();
      return;
    }
    _web = null;
    final target = StaticLayouts.compute(
      layout,
      graph: graph,
      focus: focus,
      spacing: spacing,
    );
    _base = target;
    if (animate && previous.positions.isNotEmpty) {
      _morphFrom = previous;
      _morphTo = target;
      _morphOrigin = focus == null
          ? null
          : previous.positions[focus] ?? target.positions[focus];
      _morphElapsed = Duration.zero;
      _frame = LayoutMorph.at(
        from: previous,
        to: target,
        t: 0,
        origin: _morphOrigin,
      );
      _stopTicker();
      _ticker.start();
    } else {
      _frame = target;
      _stopTicker();
    }
    notifyListeners();
  }

  /// Puts [ref] at [to] and keeps it there. A morph in flight finishes at
  /// once first, so the pin lands on the layout the diver is heading to.
  void moveNode(NodeRef ref, GraphPoint to) {
    final web = _web;
    if (web != null) {
      web.moveNode(ref, to);
      _frame = web.frame;
      _syncTicker();
      notifyListeners();
      return;
    }
    final base = _base;
    if (base == null) return;
    if (_morphTo != null) {
      _morphTo = null;
      _morphFrom = null;
      _stopTicker();
    }
    _pins = {..._pins, ref: to};
    _frame = PinnedFrame.apply(base, _pins);
    notifyListeners();
  }

  /// Releases every pin: the web lays the graph out again from its seed, a
  /// static layout returns to its computed frame.
  void relayout() {
    if (_isLive(_layout)) {
      final web = _liveLayout();
      _web = web;
      _frame = web.frame;
      _syncTicker();
      notifyListeners();
      return;
    }
    final base = _base;
    if (base == null || _pins.isEmpty) return;
    _pins = const {};
    _frame = base;
    notifyListeners();
  }

  /// Brings the layout to rest at once: a morph jumps to its target and a
  /// running force layout iterates until it settles. The share image paints
  /// this, so it never catches nodes mid-move or half grown in.
  LayoutFrame settleNow() {
    if (settled) return _frame;
    final target = _morphTo;
    if (target != null) {
      _frame = target;
      _morphTo = null;
      _morphFrom = null;
    } else {
      final web = _web!;
      // The force layout caps its own iterations, so this always ends.
      while (!web.settled) {
        web.advance(iterationsPerTick);
      }
      _frame = web.frame;
    }
    _stopTicker();
    notifyListeners();
    return _frame;
  }

  /// One tick's worth of work without a ticker, for tests: [iterations] of
  /// the force layout, or [elapsed] of the morph.
  void stepForTest([int? iterations, Duration elapsed = Duration.zero]) {
    if (_morphTo != null) {
      _advanceMorph(_morphElapsed + elapsed);
      return;
    }
    _advance(iterations ?? iterationsPerTick);
  }

  void _onTick(Duration elapsed) {
    if (_morphTo != null) {
      _advanceMorph(elapsed);
      return;
    }
    _advance(iterationsPerTick);
  }

  void _advanceMorph(Duration elapsed) {
    final to = _morphTo!;
    _morphElapsed = elapsed;
    final raw = elapsed.inMicroseconds / kRefocusDuration.inMicroseconds;
    if (raw >= 1) {
      _frame = to;
      _morphTo = null;
      _morphFrom = null;
      _stopTicker();
    } else {
      _frame = LayoutMorph.at(
        from: _morphFrom!,
        to: to,
        t: kRefocusCurve.transform(raw),
        origin: _morphOrigin,
      );
    }
    notifyListeners();
  }

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
    canRelayout.dispose();
    super.dispose();
  }

  static bool _isLive(ConnectionsLayout layout) =>
      layout == ConnectionsLayout.web || layout == ConnectionsLayout.clusters;

  /// A force layout over the current graph: one island per connected
  /// component for web, one per label-propagation group for clusters.
  WholeWebLayout _liveLayout({
    Map<NodeRef, GraphPoint> initialPositions = const {},
  }) {
    final order = _byDives(_graph);
    List<List<NodeRef>>? islands;
    if (_layout == ConnectionsLayout.clusters) {
      final groupOf = (_groups ?? LabelPropagation.communities(_graph)).groupOf;
      final byGroup = <int, List<NodeRef>>{};
      for (final ref in order) {
        final g = groupOf[ref];
        if (g != null) byGroup.putIfAbsent(g, () => []).add(ref);
      }
      islands = [for (final g in byGroup.keys.toList()..sort()) byGroup[g]!];
    }
    return WholeWebLayout(
      nodes: order,
      edges: _graph.edges,
      initialPositions: initialPositions,
      spacing: _spacing,
      islands: islands,
    );
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
