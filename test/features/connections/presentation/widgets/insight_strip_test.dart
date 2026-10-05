import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/presentation/widgets/insight_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('ana'), label: 'Ana', diveCount: 9),
    ConnectionNode(ref: _b('bo'), label: 'Bo', diveCount: 7),
  ],
  edges: [
    ConnectionEdge(
      source: _b('ana'),
      target: _b('bo'),
      weight: 7,
      firstDiveAt: DateTime(2016, 3, 4),
      lastDiveAt: DateTime(2018, 6, 1),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<InsightTile> tiles,
  ConnectionGraph? graph,
  ValueChanged<GraphSelection>? onSelect,
  VoidCallback? onGroups,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InsightStrip(
            graph: graph ?? _graph,
            tiles: tiles,
            onSelect: onSelect ?? (_) {},
            onGroups: onGroups ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('tiles name their facts, select, and switch to groups', (
    tester,
  ) async {
    final selected = <GraphSelection>[];
    var groups = 0;
    final c = await _pump(
      tester,
      tiles: GraphInsights.of(
        _graph,
        groups: LabelPropagation.communities(_graph),
      ),
      onSelect: selected.add,
      onGroups: () => groups++,
    );
    final units = UnitFormatter(c.read(settingsProvider));
    expect(find.text('Most connected'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Ana and Bo, 7 dives'), findsOneWidget);
    expect(
      find.text(
        'Ana and Bo, since ${units.formatMonthYear(DateTime(2016, 3, 4))}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Ana and Bo, last ${units.formatMonthYear(DateTime(2018, 6, 1))}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('insight-strongestPair')));
    expect(selected.single, EdgeSelection(_b('ana'), _b('bo')));

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('insight-groups')),
      find.byType(ListView),
      const Offset(-200, 0),
    );
    expect(find.text('1 group'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('insight-groups')));
    expect(groups, 1);
  });

  testWidgets('around mode names the far end', (tester) async {
    await _pump(
      tester,
      tiles: GraphInsights.of(
        _graph,
        focus: _b('ana'),
        groups: GraphGroups.empty,
      ),
    );
    expect(find.text('Closest'), findsOneWidget);
    expect(find.text('Bo, 7 dives together'), findsOneWidget);
    expect(find.textContaining('Bo, since'), findsOneWidget);
  });

  testWidgets('no tiles, no strip', (tester) async {
    await _pump(tester, tiles: const [], graph: ConnectionGraph.empty);
    expect(find.byType(Card), findsNothing);
  });
}
