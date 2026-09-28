import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/whole_web_layout.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

void main() {
  test('painting 160 labelled nodes 30 times stays cheap', () {
    final nodes = [
      for (var i = 0; i < 160; i++)
        ConnectionNode(
          ref: NodeRef(ConnectionKind.buddy, 'n$i'),
          label: 'Buddy number $i',
          diveCount: 1 + i % 40,
        ),
    ];
    final edges = <ConnectionEdge>[];
    for (var i = 0; i < 600; i++) {
      final a = nodes[(i * 7) % 160].ref;
      final b = nodes[(i * 13 + 1) % 160].ref;
      if (a == b) continue;
      edges.add(
        ConnectionEdge(
          source: a,
          target: b,
          weight: 1 + i % 5,
          firstDiveAt: DateTime.utc(2024),
          lastDiveAt: DateTime.utc(2024),
        ),
      );
    }
    final graph = ConnectionGraph(nodes: nodes, edges: edges);
    final layout = WholeWebLayout(
      nodes: nodes.map((n) => n.ref).toList(),
      edges: edges,
    )..advance(300);
    final viewport = const GraphViewport().fitted(
      layout.frame.bounds,
      const Size(1200, 800),
    );
    const colors = ConnectionKindColors({}, Colors.teal);
    final labelCache = <NodeRef, TextPainter>{};
    final sw = Stopwatch()..start();
    for (var i = 0; i < 30; i++) {
      final recorder = ui.PictureRecorder();
      ConnectionsPainter(
        graph: graph,
        frame: layout.frame,
        viewport: viewport,
        colors: colors,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black),
        labelCache: labelCache,
      ).paint(Canvas(recorder), const Size(1200, 800));
      recorder.endRecording().dispose();
    }
    sw.stop();
    // Loose bound: a regression to per-frame paragraph layout for every
    // node shows as a multiple; a slow CI shard does not flake.
    expect(
      sw.elapsedMilliseconds,
      lessThan(3000),
      reason: '30 paints took ${sw.elapsedMilliseconds} ms',
    );
    expect(labelCache.length, 160, reason: 'labels are laid out once');
  });
}
