import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

import '../../../../helpers/contrast_ratio.dart';

// One node of every kind that has an accent, all the same size, linked in a
// ring. Buddies draw initials; every other kind draws its icon.
final _nodes = [
  for (final kind in ConnectionKind.values)
    if (kind.accentFeatureId != null)
      ConnectionNode(
        ref: NodeRef(kind, kind.name),
        label: 'Node ${kind.name}',
        diveCount: 10,
      ),
];

final _edges = [
  for (var i = 0; i < _nodes.length; i++)
    ConnectionEdge(
      source: _nodes[i].ref,
      target: _nodes[(i + 1) % _nodes.length].ref,
      weight: 1,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    ),
];

/// Paints one frame and returns the painter with the glyph cache it filled.
({ConnectionsPainter painter, Map<(NodeRef, int), TextPainter> glyphs}) _paint(
  FeatureAccentColors palette, {
  HighlightMode highlight = HighlightMode.byKind,
  Map<NodeRef, int> groupOf = const {},
  Map<(NodeRef, int), TextPainter>? cache,
  GraphSelection? selection,
  Color? haloColor,
}) {
  final graph = ConnectionGraph(nodes: _nodes, edges: _edges);
  final layout = WholeWebLayout(
    nodes: _nodes.map((n) => n.ref).toList(),
    edges: _edges,
  )..advance(300);
  final viewport = const GraphViewport().fitted(
    layout.frame.bounds,
    const Size(900, 900),
  );
  final glyphs = cache ?? <(NodeRef, int), TextPainter>{};
  final painter = ConnectionsPainter(
    graph: graph,
    frame: layout.frame,
    viewport: viewport,
    colors: ConnectionKindColors.fromPalette(palette, Colors.teal),
    labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
    nodeSize: NodeSizeMode.uniform,
    highlight: highlight,
    groupOf: groupOf,
    initialsCache: glyphs,
    selection: selection,
    haloColor: haloColor,
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(900, 900));
  recorder.endRecording().dispose();
  return (painter: painter, glyphs: glyphs);
}

/// Every glyph the painter drew, with its contrast against its own disc.
/// An icon is cached under a negative size; initials under a positive one.
///
/// With a [page], nodes outside [lit] are dimmed: their disc paints at 35%
/// over the page, so that is the colour their glyph has to read on.
List<String> _unreadable(
  ConnectionsPainter painter,
  Map<(NodeRef, int), TextPainter> glyphs, {
  Color? page,
  Set<NodeRef>? lit,
}) {
  final failures = <String>[];
  for (final MapEntry(key: (ref, size), value: tp) in glyphs.entries) {
    final node = _nodes.firstWhere((n) => n.ref == ref);
    final opaque = painter.fillFor(node);
    final fill = page == null || lit == null || lit.contains(ref)
        ? opaque
        : Color.alphaBlend(opaque.withValues(alpha: 0.35), page);
    final ratio = contrastRatio(tp.text!.style!.color!, fill);
    // Icons are marks (3:1); initials are text (4.5:1).
    final minimum = size < 0 ? 3.0 : 4.5;
    if (ratio < minimum) {
      failures.add('${ref.kind.name}: ${ratio.toStringAsFixed(2)}:1');
    }
  }
  return failures;
}

void main() {
  // Glyphs were fixed white. The dark palette's pastel accents (sites
  // 0xFF81C784, buddies 0xFFA5C8AE) left them at about 2:1, and the share
  // image always uses the dark palette.
  for (final (name, palette) in [
    ('light', FeatureAccentColors.light),
    ('dark', FeatureAccentColors.dark),
  ]) {
    test('every node glyph reads on its disc in the $name palette', () {
      final (:painter, :glyphs) = _paint(palette);
      expect(glyphs, isNotEmpty, reason: 'no glyph was drawn');
      expect(glyphs.keys.map((k) => k.$2.isNegative).toSet(), {
        true,
        false,
      }, reason: 'both icons and initials should be drawn');
      expect(_unreadable(painter, glyphs), isEmpty);
    });
  }

  test('glyphs read on the group colours too', () {
    final (:painter, :glyphs) = _paint(
      FeatureAccentColors.dark,
      highlight: HighlightMode.groups,
      groupOf: {for (var i = 0; i < _nodes.length; i++) _nodes[i].ref: i},
    );
    expect(_unreadable(painter, glyphs), isEmpty);
  });

  // The glyph cache outlives a frame: switching the highlight mode repaints
  // the same nodes on new fills, so a glyph picked for the old fill must not
  // be reused.
  test('a cached glyph follows its node to a new fill', () {
    final cache = <(NodeRef, int), TextPainter>{};
    _paint(FeatureAccentColors.light, cache: cache);
    final (:painter, :glyphs) = _paint(FeatureAccentColors.dark, cache: cache);
    expect(_unreadable(painter, glyphs), isEmpty);
  });

  // With a node selected, every unlit node dims to 35% over the page. On the
  // dark page a pastel disc composites to a dark colour, so the glyph picked
  // for the opaque pastel (black) vanished there.
  test('glyphs read on dimmed discs while a node is selected', () {
    const page = Color(0xFF111318);
    final selection = NodeSelection(_nodes.first.ref);
    final (:painter, :glyphs) = _paint(
      FeatureAccentColors.dark,
      selection: selection,
      haloColor: page,
    );
    final lit = {
      _nodes.first.ref,
      ...ConnectionsPainter.neighboursOf(painter.graph, selection),
    };
    expect(lit.length, lessThan(_nodes.length), reason: 'nothing was dimmed');
    expect(_unreadable(painter, glyphs, page: page, lit: lit), isEmpty);
  });

  // The glyph colour follows the kind colours, so a palette change alone
  // (light to dark) must repaint. The canvas builds a new ConnectionKindColors
  // every frame, so an unchanged palette must not.
  test('a palette change repaints, an equal palette does not', () {
    final graph = ConnectionGraph(nodes: _nodes, edges: _edges);
    final layout = WholeWebLayout(
      nodes: _nodes.map((n) => n.ref).toList(),
      edges: _edges,
    )..advance(300);
    final viewport = const GraphViewport().fitted(
      layout.frame.bounds,
      const Size(900, 900),
    );
    ConnectionsPainter painterFor(FeatureAccentColors palette) =>
        ConnectionsPainter(
          graph: graph,
          frame: layout.frame,
          viewport: viewport,
          colors: ConnectionKindColors.fromPalette(palette, Colors.teal),
          labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
        );

    final light = painterFor(FeatureAccentColors.light);

    expect(painterFor(FeatureAccentColors.dark).shouldRepaint(light), isTrue);
    expect(painterFor(FeatureAccentColors.light).shouldRepaint(light), isFalse);
  });
}
