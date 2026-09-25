import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('me'), label: 'Me', diveCount: 9),
    ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3),
  ],
  edges: [
    ConnectionEdge(
      source: _b('me'),
      target: _b('jane'),
      weight: 3,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
);

class _Host extends StatefulWidget {
  const _Host({required this.onSelect, required this.onFocus});
  final ValueChanged<GraphSelection?> onSelect;
  final ValueChanged<NodeRef> onFocus;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final controller = ConnectionsLayoutController(vsync: this)
    ..setGraph(_graph, mode: GraphLayoutMode.ego, focus: _b('me'));
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: ConnectionsCanvas(
          graph: _graph,
          controller: controller,
          colors: const ConnectionKindColors({
            ConnectionKind.buddy: Colors.pink,
          }, Colors.grey),
          onSelect: widget.onSelect,
          onFocus: widget.onFocus,
          semanticsLabel: '2 nodes',
        ),
      ),
    ),
  );
}

ConnectionsPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('connections-canvas-paint')),
  );
  return paint.painter! as ConnectionsPainter;
}

void main() {
  testWidgets('tap on the focus node selects it, tap on empty clears', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final selections = <GraphSelection?>[];
    await tester.pumpWidget(_Host(onSelect: selections.add, onFocus: (_) {}));
    await tester.pump();
    final painter = _painter(tester);
    final centre = painter.viewport.toScreen(
      painter.frame.positions[_b('me')]!,
    );
    final origin = tester.getTopLeft(find.byType(ConnectionsCanvas));
    await tester.tapAt(origin + centre);
    // A single tap resolves only after the double-tap window closes.
    await tester.pump(const Duration(milliseconds: 400));
    expect(selections.last, NodeSelection(_b('me')));
    await tester.tapAt(origin + const Offset(5, 395));
    await tester.pump(const Duration(milliseconds: 400));
    expect(selections.last, isNull);
  });

  testWidgets('double tap on a node asks for focus', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final focused = <NodeRef>[];
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: focused.add));
    await tester.pump();
    final painter = _painter(tester);
    final jane = painter.viewport.toScreen(
      painter.frame.positions[_b('jane')]!,
    );
    final origin = tester.getTopLeft(find.byType(ConnectionsCanvas));
    await tester.tapAt(origin + jane);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(origin + jane);
    await tester.pump(const Duration(milliseconds: 400));
    expect(focused, [_b('jane')]);
  });

  testWidgets('exposes a semantics label', (tester) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pump();
    expect(find.bySemanticsLabel('2 nodes'), findsOneWidget);
  });
}
