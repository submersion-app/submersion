import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/views/table_header_bar.dart';
import 'package:submersion/features/connections/presentation/widgets/insight_strip.dart';
import 'package:submersion/features/connections/presentation/widgets/timeline_control.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('jane'), label: 'Jane', diveCount: 3),
    ConnectionNode(ref: _b('ken'), label: 'Ken', diveCount: 2),
    ConnectionNode(ref: _b('lone'), label: 'Lone', diveCount: 1),
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
        connectionsDateSpanProvider.overrideWith(
          (ref) async =>
              (start: DateTime(2019, 1, 1), end: DateTime(2024, 12, 31)),
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
  testWidgets('the chosen layout and spacing reach the layout controller', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.withLayout(ConnectionsLayout.columns, around: false));
    await tester.pumpAndSettle();
    final canvas = tester.widget<ConnectionsCanvas>(
      find.byType(ConnectionsCanvas),
    );
    expect(canvas.controller.layout, ConnectionsLayout.columns);
  });

  testWidgets('hide unconnected removes the lone node from the canvas only', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.copyWith(hideUnconnected: true));
    await tester.pumpAndSettle();
    final canvas = tester.widget<ConnectionsCanvas>(
      find.byType(ConnectionsCanvas),
    );
    expect(canvas.graph.nodes.map((n) => n.ref.id), isNot(contains('lone')));
    expect(
      canvas.controller.frame.positions.keys.map((r) => r.id),
      isNot(contains('lone')),
    );
  });

  testWidgets('the styling reaches the canvas', (tester) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    await c
        .read(connectionsDisplayProvider.notifier)
        .update(
          (d) => d.copyWith(
            labels: LabelMode.off,
            nodeSize: NodeSizeMode.uniform,
            edges: EdgeMode.thin,
          ),
        );
    await tester.pumpAndSettle();
    final canvas = tester.widget<ConnectionsCanvas>(
      find.byType(ConnectionsCanvas),
    );
    expect(canvas.labels, LabelMode.off);
    expect(canvas.nodeSize, NodeSizeMode.uniform);
    expect(canvas.edges, EdgeMode.thin);
  });

  testWidgets('around mode shows Lay out again only while a node is pinned', (
    tester,
  ) async {
    await _pump(
      tester,
      location: '/insights/connections?mode=around&focus=buddy:jane',
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Lay out again'), findsNothing);
    final canvas = tester.widget<ConnectionsCanvas>(
      find.byType(ConnectionsCanvas),
    );
    canvas.controller.moveNode(_b('ken'), const GraphPoint(1, 1));
    await tester.pump();
    expect(find.byTooltip('Lay out again'), findsOneWidget);
    await tester.tap(find.byTooltip('Lay out again'));
    await tester.pump();
    expect(find.byTooltip('Lay out again'), findsNothing);
  });

  testWidgets(
    'a table view hides the graph chrome and keeps the timeline bar',
    (tester) async {
      final c = await _pump(tester);
      await tester.pumpAndSettle();
      await c
          .read(connectionsDisplayProvider.notifier)
          .update((d) => d.copyWith(view: ConnectionsViewKind.pairs));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionsCanvas), findsNothing);
      expect(find.byType(InsightStrip), findsNothing);
      expect(find.byKey(const ValueKey('connections-share')), findsNothing);
      expect(find.byTooltip('Lay out again'), findsNothing);
      expect(find.byType(ConnectionsTimelineBar), findsOneWidget);
      expect(find.byType(TableHeaderBar), findsOneWidget);
      expect(find.byKey(const ValueKey('connections-display')), findsNothing);
    },
  );

  testWidgets('a static map layout with nothing pinned offers no relayout', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Lay out again'), findsOneWidget);
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.withLayout(ConnectionsLayout.columns, around: false));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Lay out again'), findsNothing);
  });

  testWidgets('a hidden selected node does not dim the canvas', (tester) async {
    final c = await _pump(tester);
    await tester.pumpAndSettle();
    c.read(connectionsSelectionProvider.notifier).state = NodeSelection(
      _b('lone'),
    );
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.copyWith(hideUnconnected: true));
    await tester.pumpAndSettle();
    final canvas = tester.widget<ConnectionsCanvas>(
      find.byType(ConnectionsCanvas),
    );
    expect(canvas.selection, isNull);
  });
}
