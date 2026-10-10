import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/connections_matrix.dart';
import 'package:submersion/features/connections/presentation/views/matrix_model.dart';
import 'package:submersion/features/connections/presentation/views/matrix_painter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);
ConnectionEdge _e(NodeRef a, NodeRef b, int w) => ConnectionEdge(
  source: a,
  target: b,
  weight: w,
  firstDiveAt: DateTime.utc(2024),
  lastDiveAt: DateTime.utc(2024),
);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _s('reef'), label: 'Reef', diveCount: 3),
    ConnectionNode(ref: _b('ann'), label: 'Ann', diveCount: 5),
    ConnectionNode(ref: _b('bob'), label: 'Bob', diveCount: 2),
  ],
  edges: [_e(_b('ann'), _s('reef'), 3), _e(_b('bob'), _s('reef'), 1)],
);

Future<List<GraphSelection?>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <GraphSelection?>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ConnectionsMatrix(
          graph: _graph,
          colors: const ConnectionKindColors({}, Colors.grey),
          selection: null,
          onSelect: picked.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('tapping a cell selects the pair, a header the entity', (
    tester,
  ) async {
    final picked = await _pump(tester);
    final origin = tester.getTopLeft(find.byType(ConnectionsMatrix));
    await tester.tapAt(
      origin +
          const Offset(
            MatrixGeometry.rowHeader + 10,
            MatrixGeometry.columnHeader + 10,
          ),
    );
    await tester.tapAt(
      origin +
          const Offset(
            20,
            MatrixGeometry.columnHeader + MatrixGeometry.cell + 10,
          ),
    );
    await tester.tapAt(
      origin + const Offset(MatrixGeometry.rowHeader + 10, 40),
    );
    expect(picked, [
      EdgeSelection(_b('ann'), _s('reef')),
      NodeSelection(_b('bob')),
      NodeSelection(_s('reef')),
    ]);
  });

  testWidgets('has a summary for screen readers', (tester) async {
    await _pump(tester);
    expect(
      find.bySemanticsLabel('Matrix of 2 rows and 1 columns, 2 connections'),
      findsOneWidget,
    );
  });

  testWidgets('a drag on content smaller than the view does not move it', (
    tester,
  ) async {
    await _pump(tester);
    await tester.drag(find.byType(ConnectionsMatrix), const Offset(-100, -100));
    await tester.pump();
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connections-matrix-paint')),
                )
                .painter!
            as MatrixPainter;
    expect(painter.scroll, Offset.zero);
  });
}
