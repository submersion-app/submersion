import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/pages/connections_page.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
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
          return ConnectionsPage(
            lensId: q['lens'],
            kindAName: q['a'],
            kindBName: q['b'],
            focusWire: q['focus'],
          );
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionGraphProvider.overrideWith((ref, budget) async {
          seenFocus?.add(ref.read(connectionsFocusProvider));
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
      expect(find.text('Dive circle'), findsOneWidget);
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
    expect(c.read(connectionsLensProvider).lensId, 'where');
    expect(c.read(connectionsFocusProvider), _b('jane'));
    expect(c.read(connectionsSelectionProvider)?.toString(), contains('jane'));
  });

  testWidgets('a focus outside the lens opens unfocused with a snackbar', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      size: const Size(732, 1000),
      location: '/connections?lens=circle&focus=site:s1',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(connectionsFocusProvider), isNull);
    expect(find.text('That item is no longer in the log.'), findsOneWidget);
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
    expect(c.read(connectionsFocusProvider), isNull);
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

  testWidgets('an empty lens keeps the lens chips and filter controls', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(732, 1000),
      graph: ConnectionGraph.empty,
    );
    expect(find.text('Dive circle'), findsOneWidget);
    expect(find.text('Who dives where'), findsOneWidget);
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
}
