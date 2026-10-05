import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  double textScale = 1,
  Locale? locale,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('insight-driftingApart')),
      find.byType(ListView),
      const Offset(-200, 0),
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
  testWidgets('a pair of full names and a date fit on the tile', (
    tester,
  ) async {
    final long = ConnectionGraph(
      nodes: [
        ConnectionNode(ref: _b('ana'), label: 'Ana Reyes', diveCount: 9),
        ConnectionNode(ref: _b('bo'), label: 'Bo Lindqvist', diveCount: 7),
      ],
      edges: [
        ConnectionEdge(
          source: _b('ana'),
          target: _b('bo'),
          weight: 31,
          firstDiveAt: DateTime(2016, 3, 4),
          lastDiveAt: DateTime(2018, 6, 1),
        ),
      ],
    );
    // The test font draws every glyph one em wide, about twice a real
    // font, so half scale stands in for real text metrics.
    await _pump(
      tester,
      graph: long,
      tiles: GraphInsights.of(long, groups: GraphGroups.empty),
      textScale: 0.5,
    );
    for (final kind in ['strongestPair', 'newest', 'driftingApart']) {
      final value = find.descendant(
        of: find.byKey(ValueKey('insight-$kind')),
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(value.last);
      expect(paragraph.didExceedMaxLines, isFalse, reason: kind);
    }
    // At full scale the value wraps onto its second line inside the strip.
    await _pump(
      tester,
      graph: long,
      tiles: GraphInsights.of(long, groups: GraphGroups.empty),
    );
    expect(tester.takeException(), isNull);
    final value = find.descendant(
      of: find.byKey(const ValueKey('insight-strongestPair')),
      matching: find.byType(RichText),
    );
    expect(tester.widget<RichText>(value.last).maxLines, 2);
  });
  testWidgets('every tile carries an icon', (tester) async {
    await _pump(
      tester,
      tiles: GraphInsights.of(
        _graph,
        groups: LabelPropagation.communities(_graph),
      ),
    );
    for (final kind in ['mostConnected', 'strongestPair', 'newest']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('insight-$kind')),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
        reason: kind,
      );
    }
  });

  testWidgets('large text grows the strip instead of clipping it', (
    tester,
  ) async {
    await _pump(
      tester,
      tiles: GraphInsights.of(
        _graph,
        groups: LabelPropagation.communities(_graph),
      ),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(InsightStrip));
    expect(InsightStrip.heightOf(context), greaterThan(InsightStrip.height));
  });
  testWidgets('the Closest value is punctuated for its language', (
    tester,
  ) async {
    await _pump(
      tester,
      tiles: GraphInsights.of(
        _graph,
        focus: _b('ana'),
        groups: GraphGroups.empty,
      ),
      locale: const Locale('zh'),
    );
    expect(find.text('Bo，共同潜水 7 次'), findsOneWidget);
  });
}
