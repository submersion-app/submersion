import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_caption.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_renderer.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

int _u32(Uint8List b, int at) =>
    (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

void main() {
  final graph = ConnectionGraph(
    nodes: [
      ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 5),
      ConnectionNode(
        ref: _b('b'),
        label: 'Bob',
        diveCount: 2,
        photo: Uint8List.fromList([1, 2, 3]), // not an image
      ),
    ],
    edges: [
      ConnectionEdge(
        source: _b('a'),
        target: _b('b'),
        weight: 3,
        firstDiveAt: DateTime.utc(2020),
        lastDiveAt: DateTime.utc(2024),
      ),
    ],
  );
  final frame = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('b'): const GraphPoint(120, 40),
  }, settled: true);
  const caption = ConnectionsShareCaption(
    title: 'Dive circle',
    details: 'All dives, 2009 to 2026. 2 nodes and 1 connections',
  );

  testWidgets('renders a 1080 x 1350 PNG', (tester) async {
    final png = await tester.runAsync(
      () => ConnectionsShareRenderer.render(
        graph: graph,
        frame: frame,
        highlight: HighlightMode.groups,
        groups: LabelPropagation.communities(graph),
        caption: caption,
      ),
    );
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
    expect(_u32(png, 16), 1080);
    expect(_u32(png, 20), 1350);
  });

  testWidgets('a bad photo and a missing icon still render', (tester) async {
    final png = await tester.runAsync(
      () => ConnectionsShareRenderer.renderWithAssets(
        graph: graph,
        frame: frame,
        highlight: HighlightMode.byKind,
        groups: GraphGroups.empty,
        caption: caption,
        appIconAsset: 'assets/icon/missing.png',
      ),
    );
    expect(_u32(png!, 16), 1080);
    expect(_u32(png, 20), 1350);
  });
}
