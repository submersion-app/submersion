import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/view_tab.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _kiyan = NodeRef(ConnectionKind.buddy, 'kiyan');
const _sharon = NodeRef(ConnectionKind.buddy, 'sharon');
const _pier = NodeRef(ConnectionKind.site, 'pier');

final _graph = ConnectionGraph(
  nodes: [
    const ConnectionNode(
      ref: _kiyan,
      label: 'Kiyan Griffin',
      diveCount: 34,
      hop: 0,
    ),
    const ConnectionNode(
      ref: _sharon,
      label: 'Sharon Patterson',
      diveCount: 20,
      hop: 1,
    ),
    const ConnectionNode(ref: _pier, label: 'Salt Pier', diveCount: 14, hop: 1),
  ],
  edges: [
    ConnectionEdge(
      source: _kiyan,
      target: _sharon,
      weight: 12,
      firstDiveAt: DateTime.utc(2021),
      lastDiveAt: DateTime.utc(2025),
    ),
    ConnectionEdge(
      source: _kiyan,
      target: _pier,
      weight: 9,
      firstDiveAt: DateTime.utc(2021),
      lastDiveAt: DateTime.utc(2025),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ConnectionGraph? graph,
  List<Override> extra = const [],
  List<Species> species = const [],
}) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        savedConnectionMapsProvider.overrideWith((ref) async => const []),
        connectionsSearchProvider.overrideWith(
          (ref, text) async => text.toLowerCase().startsWith('sal')
              ? [
                  const ConnectionNode(
                    ref: _pier,
                    label: 'Salt Pier',
                    diveCount: 14,
                  ),
                ]
              : const [],
        ),
        allSpeciesProvider.overrideWith((ref) async => species),
        diveTypesProvider.overrideWith((ref) async => const []),
        ...extra,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ViewTab(graph: graph ?? _graph)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('map mode shows presets, editor and the map summary', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('preset-circle')), findsOneWidget);
    expect(find.text('Custom map'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Kiyan Griffin'), findsOneWidget);
    expect(
      find.text('Kiyan Griffin and Sharon Patterson, 12 dives'),
      findsOneWidget,
    );
  });

  testWidgets('around mode: search, centre, hops and kind chips', (
    tester,
  ) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.centreOn(_kiyan));
    await tester.pumpAndSettle();

    expect(find.text('Centred on'), findsOneWidget);
    expect(find.text('Buddies (1)'), findsOneWidget);
    expect(find.text('Sites (1)'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('entity-search')), 'Sal');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-hit-site:pier')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).focus, _pier);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('hops')),
        matching: find.text('2'),
      ),
    );
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).hops, 2);

    await tester.tap(find.byKey(const ValueKey('around-kind-species')));
    await tester.pumpAndSettle();
    expect(
      c.read(connectionsViewProvider).aroundKinds,
      isNot(contains(ConnectionKind.species)),
    );
  });

  testWidgets('a search with no hits says so', (tester) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withMode(ConnectionsMode.around));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('entity-search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('Summary'), findsNothing, reason: 'no centre, no summary');
  });

  testWidgets('a kind cut by the budget still counts on its chip', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      graph: _graph.copyWith(
        hiddenNodeCount: 12,
        hiddenByKind: {ConnectionKind.species: 12},
      ),
    );
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.centreOn(_kiyan));
    await tester.pumpAndSettle();
    expect(find.text('Species (12)'), findsOneWidget);
  });

  testWidgets('search finds a built-in species by its translated name', (
    tester,
  ) async {
    const shark = NodeRef(ConnectionKind.species, 'sp_whale_shark');
    final c = await _pump(
      tester,
      species: const [
        Species(
          id: 'sp_whale_shark',
          commonName: 'WS',
          category: SpeciesCategory.shark,
          isBuiltIn: true,
        ),
      ],
      extra: [
        connectionsNodesByWireProvider.overrideWith(
          (ref, wires) async => wires == shark.wire
              ? [const ConnectionNode(ref: shark, label: 'WS', diveCount: 3)]
              : const [],
        ),
      ],
    );
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withMode(ConnectionsMode.around));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entity-search')),
      'whale',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('search-hit-species:sp_whale_shark')),
      findsOneWidget,
    );
    expect(find.text('Whale Shark'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('search-hit-species:sp_whale_shark')),
    );
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).focus, shark);
  });
}
