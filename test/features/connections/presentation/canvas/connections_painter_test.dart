import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_group_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';
import 'package:submersion/features/connections/presentation/canvas/node_metrics.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_icons.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  final graph = ConnectionGraph(
    nodes: [
      ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 5),
      ConnectionNode(ref: _b('b'), label: 'Bob', diveCount: 2),
      ConnectionNode(ref: _b('c'), label: 'Cy', diveCount: 1),
    ],
    edges: [
      ConnectionEdge(
        source: _b('a'),
        target: _b('b'),
        weight: 3,
        firstDiveAt: DateTime.utc(2024),
        lastDiveAt: DateTime.utc(2024),
      ),
    ],
  );
  final frame = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('b'): const GraphPoint(100, 0),
    _b('c'): const GraphPoint(0, 100),
  }, settled: true);
  const colors = ConnectionKindColors({
    ConnectionKind.buddy: Colors.pink,
  }, Colors.grey);

  ConnectionsPainter painter({
    GraphSelection? selection,
    Map<NodeRef, ui.Image> photos = const {},
    HighlightMode highlight = HighlightMode.byKind,
    Map<NodeRef, int> groupOf = const {},
  }) => ConnectionsPainter(
    graph: graph,
    frame: frame,
    viewport: const GraphViewport(scale: 1, offset: Offset(50, 50)),
    colors: colors,
    selection: selection,
    photos: photos,
    labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
    highlight: highlight,
    groupOf: groupOf,
  );

  ui.Image image() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(Rect.largest, Paint());
    return recorder.endRecording().toImageSync(1, 1);
  }

  test('paints without throwing, with and without a selection', () {
    for (final sel in [
      null,
      NodeSelection(_b('a')),
      EdgeSelection(_b('a'), _b('b')),
    ]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter(selection: sel).paint(canvas, const Size(300, 300));
      recorder.endRecording().dispose();
    }
  });

  test('neighboursOf lists the far ends of the selected node', () {
    expect(ConnectionsPainter.neighboursOf(graph, NodeSelection(_b('a'))), {
      _b('b'),
    });
    expect(
      ConnectionsPainter.neighboursOf(graph, EdgeSelection(_b('a'), _b('b'))),
      {_b('a'), _b('b')},
    );
    expect(ConnectionsPainter.neighboursOf(graph, null), isEmpty);
  });

  test('shouldRepaint reacts to a different frame or selection', () {
    final p1 = painter();
    expect(p1.shouldRepaint(painter()), isFalse);
    expect(
      p1.shouldRepaint(painter(selection: NodeSelection(_b('a')))),
      isTrue,
    );
  });

  test('shouldRepaint reacts to a photo replaced for the same node', () {
    final before = image();
    final after = image();
    addTearDown(before.dispose);
    addTearDown(after.dispose);
    final p1 = painter(photos: {_b('a'): before});
    expect(p1.shouldRepaint(painter(photos: {_b('a'): before})), isFalse);
    expect(
      p1.shouldRepaint(painter(photos: {_b('a'): after})),
      isTrue,
      reason: 'a new photo for the same buddy must be painted',
    );
    expect(
      p1.shouldRepaint(painter(photos: {_b('b'): before})),
      isTrue,
      reason: 'the photo moved to another node',
    );
  });

  testWidgets('ConnectionKindColors.of falls back to the palette', (
    tester,
  ) async {
    late ConnectionKindColors c;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            c = ConnectionKindColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(c.colorFor(ConnectionKind.buddy), isNotNull);
    expect(c.colorFor(ConnectionKind.tag), c.fallback);
  });

  test('visible labels sit on a halo in the given colour', () {
    final p = ConnectionsPainter(
      graph: graph,
      frame: frame,
      viewport: const GraphViewport(scale: 1, offset: Offset(50, 50)),
      colors: colors,
      labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
      haloColor: Colors.white,
    );
    expect(
      (Canvas canvas) => p.paint(canvas, const Size(300, 300)),
      paints..rrect(color: Colors.white.withValues(alpha: 0.85)),
    );
  });

  test('every kind has an icon', () {
    for (final k in ConnectionKind.values) {
      expect(connectionKindIcon(k), isA<IconData>());
    }
  });
  group('highlight modes', () {
    test('by kind fills with the kind colour', () {
      expect(painter().fillFor(graph.nodes.first), Colors.pink);
    });

    test('groups fill with the group colour, later groups and loners grey', () {
      final p = painter(
        highlight: HighlightMode.groups,
        groupOf: {_b('a'): 0, _b('b'): 8},
      );
      expect(p.fillFor(graph.nodes[0]), kConnectionGroupColors[0]);
      expect(p.fillFor(graph.nodes[1]), kConnectionUngroupedColor);
      expect(p.fillFor(graph.nodes[2]), kConnectionUngroupedColor);
    });

    test('recency scales from 1 for the newest to 0.15 for the oldest', () {
      final newest = DateTime.utc(2024);
      final oldest = DateTime.utc(2014);
      expect(ConnectionsPainter.recencyFactor(newest, newest, oldest), 1);
      expect(
        ConnectionsPainter.recencyFactor(oldest, newest, oldest),
        closeTo(0.15, 1e-9),
      );
      expect(
        ConnectionsPainter.recencyFactor(DateTime.utc(2019), newest, oldest),
        closeTo(0.575, 0.01),
      );
    });

    test(
      'recency with one distinct date keeps every edge at full strength',
      () {
        final d = DateTime.utc(2024);
        expect(ConnectionsPainter.recencyFactor(d, d, d), 1);
      },
    );

    test('groups mode paints the group colour', () {
      final single = ConnectionGraph(
        nodes: [ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 5)],
        edges: const [],
      );
      final p = ConnectionsPainter(
        graph: single,
        frame: frame,
        viewport: const GraphViewport(scale: 1, offset: Offset(50, 50)),
        colors: colors,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
        highlight: HighlightMode.groups,
        groupOf: {_b('a'): 2},
      );
      expect(
        (Canvas c) => p.paint(c, const Size(300, 300)),
        paints..circle(color: kConnectionGroupColors[2]),
      );
    });

    test('recency mode fades the older edge', () {
      final g2 = ConnectionGraph(
        nodes: graph.nodes,
        edges: [
          ConnectionEdge(
            source: _b('a'),
            target: _b('b'),
            weight: 3,
            firstDiveAt: DateTime.utc(2010),
            lastDiveAt: DateTime.utc(2024),
          ),
          ConnectionEdge(
            source: _b('a'),
            target: _b('c'),
            weight: 3,
            firstDiveAt: DateTime.utc(2010),
            lastDiveAt: DateTime.utc(2014),
          ),
        ],
      );
      ConnectionsPainter make(HighlightMode m) => ConnectionsPainter(
        graph: g2,
        frame: frame,
        viewport: const GraphViewport(scale: 1, offset: Offset(50, 50)),
        colors: colors,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
        highlight: m,
      );
      final base = NodeMetrics.edgeOpacityFor(3, 3) * 1;
      final full = Colors.black.withValues(alpha: base);
      final faded = Colors.black.withValues(
        alpha:
            base *
            ConnectionsPainter.recencyFactor(
              DateTime.utc(2014),
              DateTime.utc(2024),
              DateTime.utc(2014),
            ),
      );
      expect(
        (Canvas c) => make(HighlightMode.byKind).paint(c, const Size(300, 300)),
        paints
          ..line(color: full)
          ..line(color: full),
      );
      expect(
        (Canvas c) =>
            make(HighlightMode.recency).paint(c, const Size(300, 300)),
        paints
          ..line(color: full)
          ..line(color: faded),
      );
    });

    test('a highlight change repaints', () {
      expect(
        painter(highlight: HighlightMode.recency).shouldRepaint(painter()),
        isTrue,
      );
      expect(painter(groupOf: {_b('a'): 1}).shouldRepaint(painter()), isTrue);
    });
  });
  test('every group color keeps the white node glyphs readable', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final c in [...kConnectionGroupColors, kConnectionUngroupedColor]) {
      expect(
        contrast(c, Colors.white),
        greaterThanOrEqualTo(2.5),
        reason: c.toARGB32().toRadixString(16),
      );
    }
    for (final c in kConnectionGroupColors) {
      expect(
        contrast(c, Colors.white),
        greaterThanOrEqualTo(3),
        reason: c.toARGB32().toRadixString(16),
      );
    }
  });
}
