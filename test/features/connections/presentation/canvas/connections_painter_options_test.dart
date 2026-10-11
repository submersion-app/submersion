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
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

/// Records every canvas call by name; a label draws one halo rounded rect.
class _Recording implements Canvas {
  final calls = <Invocation>[];
  int count(Symbol name) => calls.where((c) => c.memberName == name).length;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return null;
  }
}

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
  LayoutFrame frame({List<LayoutGuide> guides = const []}) =>
      LayoutFrame.fromPositions(
        {
          _b('a'): const GraphPoint(0, 0),
          _b('b'): const GraphPoint(300, 0),
          _b('c'): const GraphPoint(0, 300),
        },
        settled: true,
        guides: guides,
      );

  _Recording paint({
    LabelMode labels = LabelMode.auto,
    EdgeMode edges = EdgeMode.weighted,
    NodeSizeMode nodeSize = NodeSizeMode.byDives,
    GraphSelection? selection,
    double scale = 1,
    List<LayoutGuide> guides = const [],
  }) {
    final rec = _Recording();
    ConnectionsPainter(
      graph: graph,
      frame: frame(guides: guides),
      viewport: GraphViewport(scale: scale, offset: const Offset(50, 50)),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
      haloColor: Colors.white,
      selection: selection,
      maxLabelsAtLowZoom: 1,
      labels: labels,
      edges: edges,
      nodeSize: nodeSize,
      kindNames: const {ConnectionKind.buddy: 'Buddies'},
    ).paint(rec, const Size(800, 800));
    return rec;
  }

  test('labels off draws none but the selected node', () {
    expect(paint(labels: LabelMode.off).count(#drawRRect), 0);
    // Ann is linked to Bob; with Ann selected only Ann keeps a label.
    expect(
      paint(
        labels: LabelMode.off,
        selection: NodeSelection(_b('a')),
      ).count(#drawRRect),
      1,
    );
  });

  test('labels all ignores the low-zoom cap', () {
    expect(paint(scale: 0.3).count(#drawRRect), 1);
    expect(paint(scale: 0.3, labels: LabelMode.all).count(#drawRRect), 3);
  });

  test('selected-only edges appear only for the selection', () {
    expect(paint(edges: EdgeMode.selectedOnly).count(#drawLine), 0);
    expect(
      paint(
        edges: EdgeMode.selectedOnly,
        selection: NodeSelection(_b('a')),
      ).count(#drawLine),
      1,
    );
  });

  test('thin edges are one pixel', () {
    final line = paint(
      edges: EdgeMode.thin,
    ).calls.singleWhere((c) => c.memberName == #drawLine);
    expect((line.positionalArguments[2] as Paint).strokeWidth, 1);
  });

  test('uniform node size draws every disc at the same radius', () {
    final radii = paint(nodeSize: NodeSizeMode.uniform).calls
        .where((c) => c.memberName == #drawCircle)
        .map((c) => c.positionalArguments[1] as double)
        .toSet();
    expect(radii, {14.0});
  });

  test('guides are drawn as text', () {
    final without = paint().count(#drawParagraph);
    final withGuides = paint(
      guides: const [
        YearGuide(2020, GraphPoint(0, -70)),
        LaneGuide(ConnectionKind.buddy, GraphPoint(-70, 0)),
      ],
    ).count(#drawParagraph);
    expect(withGuides - without, 2);
  });

  test('shouldRepaint reacts to every display option', () {
    // Frames compare by identity, so every painter shares one.
    final shared = frame();
    ConnectionsPainter p({
      LabelMode labels = LabelMode.auto,
      EdgeMode edges = EdgeMode.weighted,
      NodeSizeMode nodeSize = NodeSizeMode.byDives,
    }) => ConnectionsPainter(
      graph: graph,
      frame: shared,
      viewport: const GraphViewport(),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12),
      labels: labels,
      edges: edges,
      nodeSize: nodeSize,
    );
    expect(p().shouldRepaint(p(labels: LabelMode.off)), isTrue);
    expect(p().shouldRepaint(p(edges: EdgeMode.thin)), isTrue);
    expect(p().shouldRepaint(p(nodeSize: NodeSizeMode.uniform)), isTrue);
    expect(p().shouldRepaint(p()), isFalse);
  });

  test('every option paints into a real canvas without throwing', () {
    final recorder = ui.PictureRecorder();
    ConnectionsPainter(
      graph: graph,
      frame: frame(guides: const [YearGuide(2020, GraphPoint(0, -70))]),
      viewport: const GraphViewport(),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12),
      labels: LabelMode.all,
      edges: EdgeMode.selectedOnly,
      nodeSize: NodeSizeMode.uniform,
    ).paint(Canvas(recorder), const Size(400, 400));
    recorder.endRecording().dispose();
  });

  test('a lane label never starts left of the canvas', () {
    final rec = _Recording();
    ConnectionsPainter(
      graph: graph,
      frame: frame(
        guides: const [LaneGuide(ConnectionKind.buddy, GraphPoint(-170, 0))],
      ),
      // Nodes sit at 100 px and more; only the lane label nears the edge.
      viewport: const GraphViewport(offset: Offset(100, 100)),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12),
      labels: LabelMode.off,
      kindNames: const {ConnectionKind.buddy: 'A very long kind name'},
    ).paint(rec, const Size(400, 400));
    final offsets = rec.calls
        .where((c) => c.memberName == #drawParagraph)
        .map((c) => c.positionalArguments[1] as Offset);
    expect(offsets.every((o) => o.dx >= 0), isTrue);
  });

  test('guide text follows a change of language with the same graph', () {
    final cache = <String, TextPainter>{};
    void paintIn(String lane) {
      final recorder = ui.PictureRecorder();
      ConnectionsPainter(
        graph: graph,
        frame: frame(
          guides: const [LaneGuide(ConnectionKind.buddy, GraphPoint(-70, 0))],
        ),
        viewport: const GraphViewport(offset: Offset(200, 200)),
        colors: const ConnectionKindColors({}, Colors.grey),
        labelStyle: const TextStyle(fontSize: 12),
        kindNames: {ConnectionKind.buddy: lane},
        guideCache: cache,
      ).paint(Canvas(recorder), const Size(400, 400));
      recorder.endRecording().dispose();
    }

    paintIn('Buddies');
    paintIn('Tauchpartner');
    expect(
      cache.values.map((p) => p.text!.toPlainText()),
      contains('Tauchpartner'),
    );
  });

  test('a guide moved by a new spacing reuses its laid-out text', () {
    final cache = <String, TextPainter>{};
    void paintAt(double x) {
      final recorder = ui.PictureRecorder();
      ConnectionsPainter(
        graph: graph,
        frame: frame(
          guides: [LaneGuide(ConnectionKind.buddy, GraphPoint(x, 0))],
        ),
        viewport: const GraphViewport(offset: Offset(200, 200)),
        colors: const ConnectionKindColors({}, Colors.grey),
        labelStyle: const TextStyle(fontSize: 12),
        kindNames: const {ConnectionKind.buddy: 'Buddies'},
        guideCache: cache,
      ).paint(Canvas(recorder), const Size(400, 400));
      recorder.endRecording().dispose();
    }

    paintAt(-70);
    paintAt(-140);
    expect(cache, hasLength(1));
  });

  test('year labels thin out when zoomed out so they never collide', () {
    final years = [
      for (var y = 2000; y <= 2010; y++)
        YearGuide(y, GraphPoint((y - 2000) * 170.0, -70)),
    ];
    int yearLabels(double scale) {
      int paragraphs(List<LayoutGuide> guides) {
        final rec = _Recording();
        ConnectionsPainter(
          graph: graph,
          frame: frame(guides: guides),
          viewport: GraphViewport(scale: scale, offset: const Offset(100, 100)),
          colors: const ConnectionKindColors({}, Colors.grey),
          labelStyle: const TextStyle(fontSize: 12),
          labels: LabelMode.off,
        ).paint(rec, const Size(2000, 800));
        return rec.count(#drawParagraph);
      }

      return paragraphs(years) - paragraphs(const []);
    }

    expect(yearLabels(1), 11);
    final zoomedOut = yearLabels(0.1);
    expect(zoomedOut, lessThan(11));
    expect(zoomedOut, greaterThanOrEqualTo(2));
  });

  test('zoomed out, the latest year keeps its label', () {
    final years = [
      for (var y = 2000; y <= 2010; y++)
        YearGuide(y, GraphPoint((y - 2000) * 170.0, -70)),
    ];
    final cache = <String, TextPainter>{};
    final rec = _Recording();
    const scale = 0.1;
    ConnectionsPainter(
      graph: ConnectionGraph.empty,
      frame: LayoutFrame.fromPositions(const {}, settled: true, guides: years),
      viewport: const GraphViewport(scale: scale, offset: Offset(100, 100)),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12),
      guideCache: cache,
    ).paint(rec, const Size(2000, 800));
    final width = cache.values.first.width;
    double centreOf(int year) => 100 + (year - 2000) * 170 * scale;
    final drawn = rec.calls
        .where((c) => c.memberName == #drawParagraph)
        .map((c) => (c.positionalArguments[1] as Offset).dx + width / 2)
        .toList();
    expect(drawn.any((x) => (x - centreOf(2010)).abs() < 0.5), isTrue);
    // Every pair of drawn labels keeps the label's width apart.
    final sorted = [...drawn]..sort();
    for (var k = 1; k < sorted.length; k++) {
      expect(sorted[k] - sorted[k - 1], greaterThanOrEqualTo(width));
    }
  });

  test('two years too close to label both keep only the latest', () {
    final rec = _Recording();
    final cache = <String, TextPainter>{};
    ConnectionsPainter(
      graph: ConnectionGraph.empty,
      frame: LayoutFrame.fromPositions(
        const {},
        settled: true,
        guides: const [
          YearGuide(2020, GraphPoint(0, -70)),
          YearGuide(2021, GraphPoint(170, -70)),
        ],
      ),
      viewport: const GraphViewport(scale: 0.1, offset: Offset(100, 100)),
      colors: const ConnectionKindColors({}, Colors.grey),
      labelStyle: const TextStyle(fontSize: 12),
      guideCache: cache,
    ).paint(rec, const Size(800, 800));
    expect(rec.count(#drawParagraph), 1);
  });
}
