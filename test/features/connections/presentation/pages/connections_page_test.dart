import 'dart:async';

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
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
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

const _phone = Size(732, 1000);
const _desktop = Size(1280, 800);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Size size = _desktop,
  String location = '/connections',
  FutureOr<ConnectionGraph> Function(Ref ref, int budget)? graph,
  List<Override> extra = const [],
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
        builder: (_, state) => ConnectionsPage(
          args: ConnectionsRouteArgs.fromQuery(state.uri.queryParameters),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionGraphProvider.overrideWith(
          (ref, budget) async => graph == null ? _graph : graph(ref, budget),
        ),
        connectionsYearSpanProvider.overrideWith(
          (ref) async => (first: 2019, last: 2024),
        ),
        savedConnectionMapsProvider.overrideWith((ref) async => const []),
        connectionsSelectionDiveIdsProvider.overrideWith(
          (ref, s) async => ['d1'],
        ),
        ...extra,
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
  testWidgets('desktop: canvas and the tabbed panel', (tester) async {
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('connections-canvas-paint')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('connections-panel')), findsOneWidget);
    expect(find.text('Whole map'), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-sheet')), findsNothing);
  });

  testWidgets('phone: canvas and the panel in a sheet', (tester) async {
    await _pump(tester, size: _phone);
    expect(find.byKey(const ValueKey('connections-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('connections-panel')), findsOneWidget);
    expect(find.text('3 more not shown'), findsOneWidget);
  });

  testWidgets('a deep link centres the view and selects the entity', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      location: '/connections?mode=around&focus=buddy:jane',
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsViewProvider).mode, ConnectionsMode.around);
    expect(c.read(connectionsViewProvider).focus, _b('jane'));
    expect(c.read(connectionsSelectionProvider), NodeSelection(_b('jane')));
  });

  testWidgets('a phase 1 link still works', (tester) async {
    final c = await _pump(tester, location: '/connections?lens=where');
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsViewProvider).presetId, 'where');
  });

  testWidgets('around mode without a centre prompts and keeps the search', (
    tester,
  ) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withMode(ConnectionsMode.around));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('centre the map on it'), findsOneWidget);
    expect(find.byKey(const ValueKey('entity-search')), findsOneWidget);
  });

  testWidgets('an empty buddy map keeps the panel and points at Data Tools', (
    tester,
  ) async {
    await _pump(tester, graph: (ref, budget) => ConnectionGraph.empty);
    expect(find.byKey(const ValueKey('connections-panel')), findsOneWidget);
    expect(find.textContaining('Data Tools'), findsOneWidget);
  });

  testWidgets('an empty result under a filter blames the filter', (
    tester,
  ) async {
    await _pump(
      tester,
      graph: (ref, budget) => ConnectionGraph.empty,
      extra: [
        connectionsFilterProvider.overrideWith(
          (ref) => const DiveFilterState(siteId: 's1'),
        ),
      ],
    );
    expect(find.text('Nothing matches the current filter.'), findsOneWidget);
  });

  testWidgets('a load error shows retry', (tester) async {
    await _pump(tester, graph: (ref, budget) => throw StateError('boom'));
    expect(find.text('Could not load connections.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a vanished centre resets, warns once, and resets again', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      location: '/connections?mode=around&focus=buddy:ghost',
      graph: (ref, budget) {
        final focus = ref.watch(connectionsViewProvider).focus;
        if (focus != null) throw FocusNotFoundException(focus);
        return _graph;
      },
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsViewProvider).focus, isNull);
    expect(find.text('That item is no longer in the log.'), findsOneWidget);
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
    await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) {
        budgets.add(budget);
        return _graph;
      },
    );
    await tester.tap(find.text('3 more not shown'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AlertDialog), findsNothing);
    expect(budgets.last, ConnectionsPage.maxBudget);
  });

  testWidgets('show all asks above the ceiling, then offers no action', (
    tester,
  ) async {
    await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) => _graph.copyWith(hiddenNodeCount: 500),
    );
    await tester.tap(find.text('500 more not shown'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Show all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('leaving around mode has its own tooltip', (tester) async {
    await _pump(tester, location: '/connections?mode=around&focus=buddy:jane');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Back to the whole map'), findsOneWidget);
  });

  testWidgets('the canvas semantics name the selection', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _pump(tester);
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(
      _b('jane'),
    );
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Selected: Jane')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a reload keeps the canvas mounted and shows progress', (
    tester,
  ) async {
    final pending = Completer<ConnectionGraph>();
    var calls = 0;
    final c = await _pump(
      tester,
      graph: (ref, budget) {
        ref.watch(connectionsViewProvider);
        calls++;
        return calls == 1 ? _graph : pending.future;
      },
    );
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withHops(2).centreOn(_b('jane')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('connections-canvas-paint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('connections-reload-progress')),
      findsOneWidget,
    );
    pending.complete(_graph);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('connections-reload-progress')),
      findsNothing,
    );
  });

  testWidgets('on a phone a selection opens Details in the sheet', (
    tester,
  ) async {
    final c = await _pump(tester, size: _phone);
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(
      _b('jane'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Centre here'), findsOneWidget);
  });

  testWidgets('a view that drops the selected node clears the selection', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      graph: (ref, budget) {
        final view = ref.watch(connectionsViewProvider);
        return view.presetId == 'reef'
            ? const ConnectionGraph(
                nodes: [
                  ConnectionNode(
                    ref: NodeRef(ConnectionKind.site, 's1'),
                    label: 'Reef',
                    diveCount: 4,
                  ),
                ],
                edges: [],
              )
            : _graph;
      },
    );
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(
      _b('jane'),
    );
    await tester.pump();
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('reef')!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsSelectionProvider), isNull);
  });
}
