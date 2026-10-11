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
import 'package:submersion/features/connections/presentation/views/entities_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'package:submersion/features/connections/presentation/views/table_parts.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(
      ref: _b('ann'),
      label: 'Ann',
      diveCount: 9,
      firstDiveAt: DateTime.utc(2019),
    ),
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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EntitiesTable(
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
  testWidgets('rows start by dives, busiest first', (tester) async {
    await _pump(tester);
    expect(
      tester.getTopLeft(find.text('Ann')).dy,
      lessThan(tester.getTopLeft(find.text('Bob')).dy),
    );
  });

  testWidgets('sorting by connections puts Ann first', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sort-links')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Ann')).dy,
      lessThan(tester.getTopLeft(find.text('Cy')).dy),
    );
  });

  testWidgets('tapping a row selects that entity', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.text('Bob'));
    expect(picked.single, NodeSelection(_b('bob')));
  });

  testWidgets(
    'a sort on a hidden column falls back to the default until widened',
    (tester) async {
      bool above(String a, String b) =>
          tester.getTopLeft(find.text(a)).dy <
          tester.getTopLeft(find.text(b)).dy;

      await _pump(tester, width: 900);
      await tester.tap(find.byKey(const ValueKey('sort-strongest')));
      await tester.pumpAndSettle();
      expect(above('Bob', 'Ann'), isTrue, reason: 'strongest, A to Z');

      await _pump(tester);
      expect(above('Ann', 'Bob'), isTrue, reason: 'dives, busiest first');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sort-dives')),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );

      await _pump(tester, width: 900);
      expect(above('Bob', 'Ann'), isTrue, reason: 'the choice comes back');
    },
  );

  testWidgets('wide adds kind, strongest connection and first dive', (
    tester,
  ) async {
    await _pump(tester, width: 900);
    expect(find.text('Strongest connection'), findsOneWidget);
    expect(find.text('Cy (7)'), findsOneWidget);
    expect(find.text('First dive'), findsOneWidget);
  });

  testWidgets('the list ends clear of the year play pill', (tester) async {
    await _pump(tester);
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      const EdgeInsets.only(bottom: kTableEndPadding),
    );
  });
}
