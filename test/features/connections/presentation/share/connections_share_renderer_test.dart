import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
        fontFamily: 'NoSuchFont',
      ),
    );
    expect(_u32(png!, 16), 1080);
    expect(_u32(png, 20), 1350);
  });
  test('the caption and app mark swap sides in right-to-left languages', () {
    // Paragraph offsets in paint order: title, details, then the app name.
    List<Offset> offsets(TextDirection d) {
      final out = <Offset>[];
      expect(
        (Canvas c) => ConnectionsShareRenderer.paintCaption(
          c,
          ConnectionsShareRenderer.logicalSize,
          caption,
          null,
          null,
          d,
        ),
        paints..everything((method, args) {
          if (method == #drawParagraph) out.add(args[1] as Offset);
          return true;
        }),
      );
      return out;
    }

    final ltr = offsets(TextDirection.ltr);
    final rtl = offsets(TextDirection.rtl);
    expect(ltr, hasLength(3));
    expect(rtl, hasLength(3));
    expect(ltr[0].dx, 16, reason: 'left-to-right text starts at the left');
    expect(ltr[2].dx, greaterThan(ltr[0].dx), reason: 'mark on the right');
    expect(rtl[2].dx, lessThan(rtl[0].dx), reason: 'mark moves to the left');
    expect(rtl[0].dx, greaterThan(ltr[0].dx), reason: 'text moves right');
  });
  testWidgets('a real photo and the app icon are drawn in', (tester) async {
    final png = await tester.runAsync(() async {
      // A small solid image stands in for a buddy photo.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 8, 8),
        Paint()..color = const Color(0xFF336699),
      );
      final image = await recorder.endRecording().toImage(8, 8);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final withPhoto = ConnectionGraph(
        nodes: [
          graph.nodes.first,
          ConnectionNode(
            ref: _b('b'),
            label: 'Bob',
            diveCount: 2,
            photo: bytes!.buffer.asUint8List(),
          ),
        ],
        edges: graph.edges,
      );
      return ConnectionsShareRenderer.renderWithAssets(
        graph: withPhoto,
        frame: frame,
        highlight: HighlightMode.byKind,
        groups: GraphGroups.empty,
        caption: caption,
      );
    });
    expect(_u32(png!, 16), 1080);
    expect(_u32(png, 20), 1350);
  });
}
