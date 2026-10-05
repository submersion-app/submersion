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
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/features/connections/presentation/widgets/insight_strip.dart';
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
  String location = '/insights/connections',
  FutureOr<ConnectionGraph> Function(Ref ref, int budget)? graph,
  List<Override> extra = const [],
  List<SavedConnectionMap> savedMaps = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/insights/connections',
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
        savedConnectionMapsProvider.overrideWith((ref) async => savedMaps),
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
      location: '/insights/connections?mode=around&focus=buddy:jane',
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsViewProvider).mode, ConnectionsMode.around);
    expect(c.read(connectionsViewProvider).focus, _b('jane'));
    expect(c.read(connectionsSelectionProvider), NodeSelection(_b('jane')));
  });

  testWidgets('a phase 1 link still works', (tester) async {
    final c = await _pump(tester, location: '/insights/connections?lens=where');
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
      location: '/insights/connections?mode=around&focus=buddy:ghost',
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
    await _pump(
      tester,
      location: '/insights/connections?mode=around&focus=buddy:jane',
    );
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

  testWidgets('an edge the new view drops clears its selection', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      graph: (ref, budget) {
        final view = ref.watch(connectionsViewProvider);
        return view.presetId == 'reef'
            ? ConnectionGraph(nodes: _graph.nodes, edges: const [])
            : _graph;
      },
    );
    c.read(connectionsSelectionProvider.notifier).state = EdgeSelection(
      _b('jane'),
      _b('ken'),
    );
    await tester.pump();
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('reef')!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsSelectionProvider), isNull);
  });

  testWidgets('a saved map edited elsewhere redraws with its new spec', (
    tester,
  ) async {
    final a = ConnectionPresets.byId('travel')!.spec;
    final b = ConnectionPresets.byId('reef')!.spec;
    final c = await _pump(
      tester,
      savedMaps: [
        SavedConnectionMap(
          id: 'bon',
          diverId: 'me',
          name: 'Bonaire',
          spec: b,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ],
    );
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applySavedMap('bon', a));
    // The saved maps change (a sync brings device B's edit).
    c.invalidate(savedConnectionMapsProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(connectionsViewProvider).mapSpec, b);
    expect(c.read(connectionsViewProvider).savedMapId, 'bon');
  });

  testWidgets('show all keeps the canvas mounted while the bigger graph '
      'loads', (tester) async {
    final bigger = Completer<ConnectionGraph>();
    await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) =>
          budget == ConnectionsPage.maxBudget ? bigger.future : _graph,
    );
    await tester.tap(find.text('3 more not shown'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('connections-canvas-paint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('connections-reload-progress')),
      findsOneWidget,
    );
    bigger.complete(_graph);
  });

  testWidgets('a failed reload keeps the canvas and says so', (tester) async {
    var calls = 0;
    final c = await _pump(
      tester,
      graph: (ref, budget) {
        ref.watch(connectionsViewProvider);
        calls++;
        if (calls > 1) throw StateError('boom');
        return _graph;
      },
    );
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('reef')!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('connections-canvas-paint')),
      findsOneWidget,
    );
    expect(find.text('Could not load connections.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('on a phone the graph stays above the sheet as it opens', (
    tester,
  ) async {
    // A centre with a ring of neighbours lays out round. Selecting a node
    // opens the sheet to half height; a fit that ignores the sheet leaves
    // the lower half of the ring behind it.
    final ring = ConnectionGraph(
      nodes: [
        ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 30, hop: 0),
        for (var i = 0; i < 12; i++)
          ConnectionNode(ref: _b('n$i'), label: 'N$i', diveCount: 3, hop: 1),
      ],
      edges: [
        for (var i = 0; i < 12; i++)
          ConnectionEdge(
            source: _b('jane'),
            target: _b('n$i'),
            weight: 2,
            firstDiveAt: DateTime.utc(2024),
            lastDiveAt: DateTime.utc(2024),
          ),
      ],
    );
    await _pump(
      tester,
      size: _phone,
      location: '/insights/connections?mode=around&focus=buddy:jane',
      graph: (ref, budget) => ring,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ConnectionsPage)),
    );
    // The deep link already selected Jane; clear it, then pick a neighbour
    // so the sheet opens as it does for a tap.
    c.read(connectionsSelectionProvider.notifier).state = null;
    await tester.pump();
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(
      _b('n0'),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('connections-canvas-paint')),
    );
    final painter = paint.painter! as ConnectionsPainter;
    final canvasHeight = tester
        .getSize(find.byKey(const ValueKey('connections-canvas-paint')))
        .height;
    final sheetTop = canvasHeight * (1 - 0.5);
    for (final p in painter.frame.positions.values) {
      expect(painter.viewport.toScreen(p).dy, lessThan(sheetTop));
    }
  });

  testWidgets('a built-in species shows its translated name', (tester) async {
    const shark = NodeRef(ConnectionKind.species, 'sp_whale_shark');
    final c = await _pump(
      tester,
      graph: (ref, budget) => ConnectionGraph(
        nodes: [
          ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3),
          // A stored name unlike the English translation proves the label
          // comes from the catalog, not the row.
          const ConnectionNode(ref: shark, label: 'WS', diveCount: 2),
        ],
        edges: [
          ConnectionEdge(
            source: _b('jane'),
            target: shark,
            weight: 2,
            firstDiveAt: DateTime.utc(2024),
            lastDiveAt: DateTime.utc(2024),
          ),
        ],
      ),
    );
    c.read(connectionsSelectionProvider.notifier).state = const NodeSelection(
      shark,
    );
    await tester.pumpAndSettle();
    expect(find.text('Whale Shark'), findsWidgets);
    expect(find.text('WS'), findsNothing);
  });

  testWidgets('Retry after a failed first load asks again', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      graph: (ref, budget) {
        calls++;
        throw StateError('boom');
      },
    );
    final before = calls;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, greaterThan(before));
  });

  testWidgets('Retry on the reload bar asks again', (tester) async {
    var calls = 0;
    final c = await _pump(
      tester,
      graph: (ref, budget) {
        ref.watch(connectionsViewProvider);
        calls++;
        if (calls > 1) throw StateError('boom');
        return _graph;
      },
    );
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('reef')!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final before = calls;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, greaterThan(before));
  });

  testWidgets('tapping and double-tapping a node select and centre it', (
    tester,
  ) async {
    final c = await _pump(tester);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final paint = find.byKey(const ValueKey('connections-canvas-paint'));
    final painter =
        tester.widget<CustomPaint>(paint).painter! as ConnectionsPainter;
    final at =
        tester.getTopLeft(paint) +
        painter.viewport.toScreen(painter.frame.positions[_b('ken')]!);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.read(connectionsSelectionProvider), NodeSelection(_b('ken')));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.read(connectionsViewProvider).focus, _b('ken'));
    expect(c.read(connectionsViewProvider).mode, ConnectionsMode.around);
  });

  testWidgets('Back to the whole map leaves Around and clears the selection', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      location: '/insights/connections?mode=around&focus=buddy:jane',
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Back to the whole map'));
    await tester.pump();
    expect(c.read(connectionsViewProvider).mode, ConnectionsMode.map);
    expect(c.read(connectionsSelectionProvider), isNull);
  });

  testWidgets('cancelling Show all keeps the budget', (tester) async {
    final budgets = <int>[];
    await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) {
        budgets.add(budget);
        return _graph.copyWith(hiddenNodeCount: 500);
      },
    );
    await tester.tap(find.text('500 more not shown'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(budgets.toSet(), {ConnectionsPage.compactBudget});
  });
  testWidgets('the insight strip selects and switches to groups', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(find.byKey(const ValueKey('connections-insights')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('insight-strongestPair')));
    await tester.pump();
    expect(
      c.read(connectionsSelectionProvider),
      EdgeSelection(_b('jane'), _b('ken')),
    );
    // The strip builds lazily; scroll it until the Groups tile exists.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('insight-groups')),
      find
          .descendant(
            of: find.byKey(const ValueKey('connections-insights')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(-200, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('insight-groups')));
    await tester.pump();
    expect(c.read(connectionsViewProvider).highlight, HighlightMode.groups);
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('connections-canvas-paint')),
    );
    final painter = paint.painter! as ConnectionsPainter;
    expect(painter.highlight, HighlightMode.groups);
    expect(painter.groupOf.length, 2);
  });

  testWidgets('the play pill sits on the canvas and a load moves play on', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      size: _phone,
      // Like the real provider, the graph reloads when the filter changes;
      // play waits for that reload before its next beat.
      graph: (ref, budget) {
        ref.watch(connectionsFilterProvider);
        return _graph;
      },
    );
    expect(find.byKey(const ValueKey('year-play-pill')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    expect(c.read(yearPlayProvider), 2019);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(YearPlayNotifier.beat);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      c.read(yearPlayProvider),
      2020,
      reason: 'the reload settled and the beat passed',
    );
    c.read(yearPlayProvider.notifier).pause();
  });
  testWidgets('the share button opens the share sheet', (tester) async {
    await _pump(tester);
    final button = find.byKey(const ValueKey('connections-share'));
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Share map image'), findsOneWidget);
    expect(find.text('Save to File'), findsOneWidget);
  });

  testWidgets('no map, no share', (tester) async {
    await _pump(tester, graph: (ref, budget) => ConnectionGraph.empty);
    final button = find.byKey(const ValueKey('connections-share'));
    expect(tester.widget<IconButton>(button).onPressed, isNull);
  });
  testWidgets('the camera keeps every node below the insight strip', (
    tester,
  ) async {
    // A tall chain fills the canvas height; a fit that ignores the strip
    // tucks the top node under it.
    final chain = ConnectionGraph(
      nodes: [
        for (var i = 0; i < 8; i++)
          ConnectionNode(ref: _b('n$i'), label: 'N$i', diveCount: 8 - i),
      ],
      edges: [
        for (var i = 0; i < 7; i++)
          ConnectionEdge(
            source: _b('n$i'),
            target: _b('n${i + 1}'),
            weight: 3,
            firstDiveAt: DateTime.utc(2020),
            lastDiveAt: DateTime.utc(2024),
          ),
      ],
    );
    await _pump(tester, size: const Size(1280, 500), graph: (ref, b) => chain);
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connections-canvas-paint')),
                )
                .painter!
            as ConnectionsPainter;
    final stripBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('connections-insights')))
        .dy;
    final canvasTop = tester
        .getTopLeft(find.byKey(const ValueKey('connections-canvas-paint')))
        .dy;
    expect(stripBottom - canvasTop, greaterThanOrEqualTo(InsightStrip.height));
    for (final n in chain.nodes) {
      final p = painter.frame.positions[n.ref]!;
      final top = painter.viewport.toScreen(p).dy - painter.radiusOf(n);
      expect(
        top,
        greaterThanOrEqualTo(stripBottom - canvasTop),
        reason: n.label,
      );
    }
  });
  testWidgets('play carries on through a year with an empty map', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) {
        final end = ref.watch(connectionsFilterProvider).endDate;
        return end != null && end.year == 2019 ? ConnectionGraph.empty : _graph;
      },
    );
    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(yearPlayProvider), 2019);
    expect(
      find.byKey(const ValueKey('year-play-pill')),
      findsOneWidget,
      reason: 'the pill stays over the empty state so play can be paused',
    );
    await tester.pump(YearPlayNotifier.beat);
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.read(yearPlayProvider), 2020);
    c.read(yearPlayProvider.notifier).pause();
  });
  testWidgets('beside the tiles, the strip band still reaches the canvas', (
    tester,
  ) async {
    final pair = ConnectionGraph(
      nodes: [
        ConnectionNode(ref: _b('a'), label: 'A', diveCount: 2),
        ConnectionNode(ref: _b('b'), label: 'B', diveCount: 1),
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
    );
    await _pump(
      tester,
      size: const Size(1800, 800),
      graph: (ref, budget) => pair,
    );
    final canvas = find.byKey(const ValueKey('connections-canvas-paint'));
    final band = tester.getRect(
      find.byKey(const ValueKey('connections-insights')),
    );
    final point = Offset(tester.getRect(canvas).right - 20, band.center.dy);
    final hit = tester.hitTestOnBinding(point);
    final target = tester.renderObject(canvas);
    expect(hit.path.any((e) => e.target == target), isTrue);
  });
  testWidgets('sharing brings a moving layout to rest first', (tester) async {
    final chain = ConnectionGraph(
      nodes: [
        for (var i = 0; i < 12; i++)
          ConnectionNode(ref: _b('n$i'), label: 'N$i', diveCount: 12 - i),
      ],
      edges: [
        for (var i = 0; i < 11; i++)
          ConnectionEdge(
            source: _b('n$i'),
            target: _b('n${i + 1}'),
            weight: 2,
            firstDiveAt: DateTime.utc(2020),
            lastDiveAt: DateTime.utc(2024),
          ),
      ],
    );
    await _pump(tester, graph: (ref, budget) => chain);
    ConnectionsPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('connections-canvas-paint')),
                )
                .painter!
            as ConnectionsPainter;
    expect(painter().frame.settled, isFalse, reason: 'still laying out');
    await tester.tap(find.byKey(const ValueKey('connections-share')));
    await tester.pump();
    expect(painter().frame.settled, isTrue);
  });
  testWidgets('with no insight tiles the overlays sit at the top', (
    tester,
  ) async {
    // Entities that share no dives: nothing for the strip to say.
    final loners = ConnectionGraph(
      nodes: [
        ConnectionNode(ref: _b('a'), label: 'A', diveCount: 2),
        ConnectionNode(ref: _b('b'), label: 'B', diveCount: 1),
      ],
      edges: const [],
      hiddenNodeCount: 3,
    );
    await _pump(tester, graph: (ref, budget) => loners);
    expect(find.byKey(const ValueKey('insight-mostConnected')), findsNothing);
    final canvasTop = tester
        .getTopLeft(find.byKey(const ValueKey('connections-canvas-paint')))
        .dy;
    final chipTop = tester.getTopLeft(find.byType(HiddenNodesChip)).dy;
    expect(chipTop - canvasTop, 12);
  });
}
