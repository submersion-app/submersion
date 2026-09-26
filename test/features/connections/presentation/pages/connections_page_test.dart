import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3),
    ConnectionNode(ref: _b('ken'), label: 'Ken', diveCount: 2),
  ],
  edges: [
    ConnectionEdge(
      source: _b('jane'),
      target: _b('ken'),
      weight: 2,
      firstDiveAt: DateTime.utc(2024),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
  hiddenNodeCount: 3,
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  ConnectionGraph? graph,
  Object? error,
  String location = '/connections',
  List<Override> extraOverrides = const [],
  List<NodeRef?>? seenFocus,
  List<int>? seenBudgets,
  Future<ConnectionGraph> Function(Ref ref)? builder,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/connections',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ConnectionsPage(args: ConnectionsRouteArgs.fromQuery(q));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionGraphProvider.overrideWith((ref, budget) async {
          seenFocus?.add(ref.read(connectionsViewProvider).focus);
          seenBudgets?.add(budget);
          if (builder != null) return builder(ref);
          if (error != null) throw error;
          return graph ?? _graph;
        }),
        ...extraOverrides,
        connectionsYearSpanProvider.overrideWith(
          (ref) async => (first: 2019, last: 2024),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(
    tester.element(find.byType(ConnectionsPage)),
  );
}

void main() {
  testWidgets(
    'phone layout: chips, canvas, legend, hidden chip; no side panel',
    (tester) async {
      await _pump(tester, size: const Size(732, 1000));
      expect(
        find.byKey(const ValueKey('connections-canvas-paint')),
        findsOneWidget,
      );
      expect(
        find.text('Legend'),
        findsNothing,
        reason: 'compact legend is icon-only',
      );
      expect(find.text('3 more not shown'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connections-selection-panel')),
        findsNothing,
      );
    },
  );

  testWidgets('wide layout shows the side panel with the hint', (tester) async {
    await _pump(tester, size: const Size(1200, 800));
    expect(
      find.byKey(const ValueKey('connections-selection-panel')),
      findsOneWidget,
    );
    expect(find.text('Tap a node or a line to see details.'), findsOneWidget);
  });

  testWidgets('a deep link applies the lens and focus', (tester) async {
    final c = await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=where&focus=buddy:jane',
    );
    expect(c.read(connectionsViewProvider).presetId, 'where');
    expect(c.read(connectionsViewProvider).focus, _b('jane'));
    expect(c.read(connectionsSelectionProvider)?.toString(), contains('jane'));
  });

  testWidgets('a site focus from a buddy lens centres on the site', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=circle&focus=site:s1',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      c.read(connectionsViewProvider).focus,
      const NodeRef(ConnectionKind.site, 's1'),
    );
    expect(find.text('That item is no longer in the log.'), findsNothing);
  });

  testWidgets('a missing focus clears and warns', (tester) async {
    final c = await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=circle&focus=buddy:ghost',
      error: const FocusNotFoundException(
        NodeRef(ConnectionKind.buddy, 'ghost'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsViewProvider).focus, isNull);
    expect(find.text('That item is no longer in the log.'), findsOneWidget);
  });

  testWidgets('an empty buddy lens points at Data Tools', (tester) async {
    await _pump(
      tester,
      size: const Size(732, 1000),
      graph: ConnectionGraph.empty,
    );
    expect(find.textContaining('Data Tools'), findsOneWidget);
  });

  testWidgets('a load error shows retry', (tester) async {
    await _pump(tester, size: const Size(732, 1000), error: StateError('boom'));
    expect(find.text('Could not load connections.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('an empty map keeps the filter controls', (tester) async {
    await _pump(
      tester,
      size: const Size(732, 1000),
      graph: ConnectionGraph.empty,
    );
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.textContaining('Data Tools'), findsOneWidget);
  });

  testWidgets('an empty result under an active filter blames the filter', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(732, 1000),
      graph: ConnectionGraph.empty,
      extraOverrides: [
        connectionsFilterProvider.overrideWith(
          (ref) => const DiveFilterState(siteId: 's1'),
        ),
      ],
    );
    expect(find.text('Nothing matches the current filter.'), findsOneWidget);
    expect(find.textContaining('Data Tools'), findsNothing);
    expect(find.byTooltip('Clear filter'), findsOneWidget);
  });

  testWidgets('a deep link focus is applied before the first graph load', (
    tester,
  ) async {
    final seen = <NodeRef?>[];
    await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=circle&focus=buddy:jane',
      seenFocus: seen,
    );
    expect(seen, isNotEmpty);
    expect(seen.first, _b('jane'), reason: 'no whole-web query before ego');
  });

  testWidgets('a focus that vanishes twice is reset both times', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=circle&focus=buddy:ghost',
      builder: (ref) async {
        final focus = ref.watch(connectionsViewProvider).focus;
        if (focus != null) throw FocusNotFoundException(focus);
        return _graph;
      },
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsViewProvider).focus, isNull);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.centreOn(_b('ghost2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsViewProvider).focus, isNull);
  });

  testWidgets('show all raises the budget without asking when it fits', (
    tester,
  ) async {
    final budgets = <int>[];
    await _pump(tester, size: const Size(732, 1000), seenBudgets: budgets);
    await tester.tap(find.text('3 more not shown'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AlertDialog), findsNothing);
    expect(budgets.last, ConnectionsPage.maxBudget);
  });

  testWidgets('show all asks above the ceiling, then offers no action', (
    tester,
  ) async {
    final budgets = <int>[];
    await _pump(
      tester,
      size: const Size(732, 1000),
      graph: _graph.copyWith(hiddenNodeCount: 500),
      seenBudgets: budgets,
    );
    await tester.tap(find.text('500 more not shown'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Show all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(budgets.last, ConnectionsPage.maxBudget);
    expect(find.text('500 more not shown'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('the exit-focus action has its own tooltip', (tester) async {
    await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=circle&focus=buddy:jane',
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Back to the whole map'), findsOneWidget);
    expect(find.byTooltip('Lay out again'), findsNothing);
  });

  testWidgets('the canvas semantics name the selected node', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _pump(tester, size: const Size(1280, 800));
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(
      _b('jane'),
    );
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Selected: Jane')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the selection card fits a 732 px phone', (tester) async {
    final c = await _pump(tester, size: const Size(732, 1000));
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(
      _b('jane'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('connections-selection-card')),
      findsOneWidget,
    );
    expect(find.text('Show dives'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
