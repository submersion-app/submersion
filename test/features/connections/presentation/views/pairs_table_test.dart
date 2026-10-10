import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/pairs_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('ann'), label: 'Ann', diveCount: 9),
    ConnectionNode(ref: _b('bob'), label: 'Bob', diveCount: 4),
    ConnectionNode(ref: _b('cy'), label: 'Cy', diveCount: 2),
  ],
  edges: [
    ConnectionEdge(
      source: _b('ann'),
      target: _b('bob'),
      weight: 2,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(2021),
    ),
    ConnectionEdge(
      source: _b('ann'),
      target: _b('cy'),
      weight: 7,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
);

Future<List<GraphSelection?>> _pump(
  WidgetTester tester, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <GraphSelection?>[];
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PairsTable(
            graph: _graph,
            colors: const ConnectionKindColors({}, Colors.grey),
            selection: null,
            onSelect: picked.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('rows start by shared dives, strongest first', (tester) async {
    await _pump(tester);
    final first = tester.getTopLeft(find.text('Cy')).dy;
    final second = tester.getTopLeft(find.text('Bob')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('tapping a header sorts by it, again reverses', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sort-b')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Bob')).dy,
      lessThan(tester.getTopLeft(find.text('Cy')).dy),
    );
    await tester.tap(find.byKey(const ValueKey('sort-b')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cy')).dy,
      lessThan(tester.getTopLeft(find.text('Bob')).dy),
    );
  });

  testWidgets('tapping a row selects that pair', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.text('Cy'));
    expect(picked.single, EdgeSelection(_b('ann'), _b('cy')));
  });

  testWidgets('first shared shows only when wide', (tester) async {
    await _pump(tester);
    expect(find.text('First shared'), findsNothing);
    await _pump(tester, width: 900);
    expect(find.text('First shared'), findsOneWidget);
  });
}
