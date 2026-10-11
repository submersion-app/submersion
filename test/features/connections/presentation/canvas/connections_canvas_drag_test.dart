import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

const _me = NodeRef(ConnectionKind.buddy, 'me');

const _graph = ConnectionGraph(
  nodes: [ConnectionNode(ref: _me, label: 'Me', diveCount: 4)],
  edges: [],
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
    ..setGraph(_graph, layout: ConnectionsLayout.radial, focus: _me);
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
          colors: const ConnectionKindColors({}, Colors.grey),
          onSelect: widget.onSelect,
          onFocus: widget.onFocus,
        ),
      ),
    ),
  );
}

ConnectionsLayoutController _controller(WidgetTester tester) =>
    (tester.state(find.byType(_Host)) as _HostState).controller;

void main() {
  testWidgets('a mouse press-drag on a node moves it and selects it', (
    tester,
  ) async {
    GraphSelection? selected;
    await tester.pumpWidget(
      _Host(onSelect: (s) => selected = s, onFocus: (_) {}),
    );
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    final g = await tester.startGesture(centre, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    // Lets the double-tap recognizer's timer run out.
    await tester.pump(const Duration(milliseconds: 500));
    final p = _controller(tester).frame.positions[_me]!;
    expect(p.x, greaterThan(20));
    expect(selected, const NodeSelection(_me));
  });

  testWidgets('a mouse drag on empty canvas pans and leaves the node', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final corner =
        tester.getTopLeft(find.byType(ConnectionsCanvas)) +
        const Offset(20, 20);
    final g = await tester.startGesture(corner, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    // Lets the double-tap recognizer's timer run out.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_controller(tester).frame.positions[_me], GraphPoint.zero);
  });

  testWidgets('a touch long-press then drag still moves the node', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    final g = await tester.startGesture(centre);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    // Lets the double-tap recognizer's timer run out.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_controller(tester).frame.positions[_me]!.x, greaterThan(20));
  });

  testWidgets('a mouse click selects and a double click centres', (
    tester,
  ) async {
    GraphSelection? selected;
    NodeRef? focused;
    await tester.pumpWidget(
      _Host(onSelect: (s) => selected = s, onFocus: (r) => focused = r),
    );
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    await tester.tapAt(centre, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(selected, const NodeSelection(_me));
    await tester.tapAt(centre, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(centre, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(focused, _me);
  });

  testWidgets('the cursor is a grab hand over a node', (tester) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ConnectionsCanvas)));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.grab,
    );
  });

  testWidgets('a click that wobbles a few pixels is still a click', (
    tester,
  ) async {
    NodeRef? focused;
    await tester.pumpWidget(
      _Host(onSelect: (_) {}, onFocus: (r) => focused = r),
    );
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    Future<void> wobblyClick() async {
      final g = await tester.startGesture(
        centre,
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(4, 0));
      await g.up();
    }

    await wobblyClick();
    await tester.pump(const Duration(milliseconds: 50));
    await wobblyClick();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_controller(tester).frame.positions[_me], GraphPoint.zero);
    expect(focused, _me);
  });

  testWidgets('the node under the press is dragged even if it moves away', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(onSelect: (_) {}, onFocus: (_) {}));
    await tester.pumpAndSettle();
    final centre = tester.getCenter(find.byType(ConnectionsCanvas));
    final g = await tester.startGesture(centre, kind: PointerDeviceKind.mouse);
    // A settling layout carries the node off before the drag begins.
    _controller(tester).moveNode(_me, const GraphPoint(900, 900));
    await tester.pump();
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      _controller(tester).frame.positions[_me],
      isNot(const GraphPoint(900, 900)),
    );
  });
}
