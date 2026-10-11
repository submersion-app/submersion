import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/pages/connections_table_area.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

Future<void> _pump(
  WidgetTester tester,
  ConnectionGraph graph, {
  bool loading = false,
  ConnectionsViewKind view = ConnectionsViewKind.pairs,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConnectionsTableArea(
            view: view,
            graph: graph,
            colors: const ConnectionKindColors({}, Colors.grey),
            selection: null,
            onSelect: (_) {},
            onShowAll: null,
            bottomInset: 0,
            timelineBar: const SizedBox.shrink(),
            loading: loading,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the count line reads naturally for one of each', (tester) async {
    await _pump(
      tester,
      ConnectionGraph(
        nodes: [
          ConnectionNode(ref: _b('a'), label: 'Ann', diveCount: 1),
          ConnectionNode(ref: _b('b'), label: 'Bob', diveCount: 1),
        ],
        edges: [
          ConnectionEdge(
            source: _b('a'),
            target: _b('b'),
            weight: 1,
            firstDiveAt: DateTime.utc(2024),
            lastDiveAt: DateTime.utc(2024),
          ),
        ],
      ),
    );
    expect(find.text('2 entities • 1 connection'), findsOneWidget);
  });

  testWidgets('the loading bar is announced', (tester) async {
    await _pump(tester, ConnectionGraph.empty, loading: true);
    expect(find.bySemanticsLabel('Loading connections'), findsOneWidget);
  });

  testWidgets('each view kind shows its own widget', (tester) async {
    for (final (view, key) in [
      (ConnectionsViewKind.pairs, 'connections-view-pairs'),
      (ConnectionsViewKind.entities, 'connections-view-entities'),
      (ConnectionsViewKind.matrix, 'connections-view-matrix'),
    ]) {
      await _pump(tester, ConnectionGraph.empty, view: view);
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: view.name);
    }
  });
}
