import 'package:flutter/gestures.dart';
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
import 'package:submersion/features/connections/presentation/views/table_parts.dart';

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

Future<List<GraphSelection?>> _pump(
  WidgetTester tester, {
  ConnectionGraph? graph,
  GraphSelection? selection,
}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <GraphSelection?>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ConnectionsMatrix(
          graph: graph ?? _graph,
          colors: const ConnectionKindColors({}, Colors.grey),
          selection: selection,
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
      find.bySemanticsLabel('Matrix, rows: 2, columns: 1, connections: 2'),
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

  testWidgets('the last row scrolls clear of the year play pill', (
    tester,
  ) async {
    final buddies = [
      for (var i = 0; i < 30; i++)
        ConnectionNode(ref: _b('b$i'), label: 'B$i', diveCount: 30 - i),
    ];
    await _pump(
      tester,
      graph: ConnectionGraph(
        nodes: [...buddies, _graph.nodes.first],
        edges: [for (final b in buddies) _e(b.ref, _s('reef'), 1)],
      ),
    );
    await tester.drag(find.byType(ConnectionsMatrix), const Offset(0, -3000));
    await tester.pump();
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connections-matrix-paint')),
                )
                .painter!
            as MatrixPainter;
    const viewport = 600 - MatrixGeometry.columnHeader;
    expect(
      painter.scroll.dy,
      30 * MatrixGeometry.cell - viewport + kTableEndPadding,
    );
  });

  testWidgets('headers read in the ambient direction', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ConnectionsMatrix(
              graph: _graph,
              colors: const ConnectionKindColors({}, Colors.grey),
              selection: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connections-matrix-paint')),
                )
                .painter!
            as MatrixPainter;
    expect(painter.textDirection, TextDirection.rtl);
  });

  testWidgets('a change of direction lays the cached text out again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> pumpIn(TextDirection direction) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: ConnectionsMatrix(
              graph: _graph,
              colors: const ConnectionKindColors({}, Colors.grey),
              selection: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await pumpIn(TextDirection.ltr);
    await pumpIn(TextDirection.rtl);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connections-matrix-paint')),
                )
                .painter!
            as MatrixPainter;
    expect(painter.text.painters, isNotEmpty);
    expect(painter.text.painters.values.map((p) => p.textDirection).toSet(), {
      TextDirection.rtl,
    });
  });

  testWidgets(
    'a selection reaches the painter, and a blank cell selects nothing',
    (tester) async {
      final picked = await _pump(
        tester,
        selection: EdgeSelection(_b('ann'), _s('reef')),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('connections-matrix-paint')),
                  )
                  .painter!
              as MatrixPainter;
      expect(painter.selectedEdge?.weight, 3);
      await _pump(tester, selection: NodeSelection(_b('bob')));
      final tinted =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('connections-matrix-paint')),
                  )
                  .painter!
              as MatrixPainter;
      expect(tinted.selectedNode, _b('bob'));
      // The corner above the row headers selects nothing.
      final origin = tester.getTopLeft(find.byType(ConnectionsMatrix));
      await tester.tapAt(origin + const Offset(10, 10));
      expect(picked, isEmpty);
    },
  );

  testWidgets('a mouse wheel scrolls a matrix taller than the view', (
    tester,
  ) async {
    final buddies = [
      for (var i = 0; i < 30; i++)
        ConnectionNode(ref: _b('b$i'), label: 'B$i', diveCount: 30 - i),
    ];
    await _pump(
      tester,
      graph: ConnectionGraph(
        nodes: [...buddies, _graph.nodes.first],
        edges: [for (final b in buddies) _e(b.ref, _s('reef'), 1)],
      ),
    );
    final centre = tester.getCenter(find.byType(ConnectionsMatrix));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pump();
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connections-matrix-paint')),
                )
                .painter!
            as MatrixPainter;
    expect(painter.scroll.dy, 100);
  });
}
