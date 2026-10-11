import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';
import 'package:submersion/features/connections/presentation/views/matrix_painter.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);

void main() {
  test('header and count text is laid out once and reused across frames', () {
    final model = MatrixModel.of(
      ConnectionGraph(
        nodes: [
          ConnectionNode(ref: _b('ann'), label: 'Ann', diveCount: 2),
          ConnectionNode(ref: _s('reef'), label: 'Reef', diveCount: 2),
        ],
        edges: [
          ConnectionEdge(
            source: _b('ann'),
            target: _s('reef'),
            weight: 2,
            firstDiveAt: DateTime.utc(2024),
            lastDiveAt: DateTime.utc(2024),
          ),
        ],
      ),
    );
    final cache = MatrixTextCache();
    void frame(Offset scroll) {
      final recorder = ui.PictureRecorder();
      MatrixPainter(
        model: model,
        scroll: scroll,
        colors: const ConnectionKindColors({}, Colors.grey),
        textStyle: const TextStyle(fontSize: 11, color: Colors.black),
        fill: Colors.blue,
        onFill: Colors.white,
        grid: Colors.grey,
        tint: Colors.yellow,
        headerBackground: Colors.white,
        text: cache,
      ).paint(Canvas(recorder), const Size(400, 400));
      recorder.endRecording().dispose();
    }

    frame(Offset.zero);
    final first = {...cache.painters};
    expect(first, isNotEmpty);
    frame(const Offset(0, 1));
    expect(cache.painters.length, first.length);
    for (final MapEntry(:key, :value) in first.entries) {
      expect(identical(cache.painters[key], value), isTrue);
    }
  });
}
