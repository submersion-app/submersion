import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/panel/connections_panel.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart'
    show diveFilterProvider;
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_panel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');
const _graph = ConnectionGraph(
  nodes: [ConnectionNode(ref: _jane, label: 'Jane', diveCount: 3)],
  edges: [],
);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsYearSpanProvider.overrideWith(
          (ref) async => (first: 2019, last: 2024),
        ),
        connectionsSelectionDiveIdsProvider.overrideWith(
          (ref, s) async => ['d1'],
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(
            children: [
              Expanded(child: SizedBox()),
              SizedBox(
                width: 340,
                child: ConnectionsPanel(
                  viewTab: Text('VIEW_TAB'),
                  graph: _graph,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  // The All filters sheet lists tags and other entities from the database.
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('opens on the View tab', (tester) async {
    await _pump(tester);
    expect(find.text('VIEW_TAB'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('the Filter tab shows the slider, chips and actions', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('connections-tab-filter')));
    await tester.pumpAndSettle();
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('No filters are active.'), findsOneWidget);

    c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
      startDate: DateTime(2021),
      endDate: DateTime(2023, 12, 31),
      favoritesOnly: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Filter (2)'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(2));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsFilterProvider).hasActiveFilters, isFalse);

    await tester.tap(find.text('All filters'));
    await tester.pumpAndSettle();
    expect(find.byType(RefinePanel), findsOneWidget);
  });

  // Code review: Connections' panel writes the Connections filter only.
  testWidgets('All filters applies to the Connections filter only', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.read(diveFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 30,
    );
    c.read(connectionsFilterProvider.notifier).state = const DiveFilterState(
      favoritesOnly: true,
    );
    await tester.tap(find.byKey(const ValueKey('connections-tab-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kRefineClearAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kRefineApplyKey));
    await tester.pumpAndSettle();
    expect(c.read(connectionsFilterProvider), const DiveFilterState());
    expect(c.read(diveFilterProvider), const DiveFilterState(minDepth: 30));
  });

  testWidgets('a selection opens Details and clearing it goes back', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('connections-tab-filter')));
    await tester.pumpAndSettle();

    c.read(connectionsSelectionProvider.notifier).state = const NodeSelection(
      _jane,
    );
    await tester.pumpAndSettle();
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('Centre here'), findsOneWidget);

    c.read(connectionsSelectionProvider.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  testWidgets('Details without a selection shows the hint', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('connections-tab-details')));
    await tester.pumpAndSettle();
    expect(find.text('Tap a node or a line to see details.'), findsOneWidget);
  });

  testWidgets('an axis without a chip still counts as an active filter', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('connections-tab-filter')));
    await tester.pumpAndSettle();
    c.read(connectionsFilterProvider.notifier).state = const DiveFilterState(
      minRating: 4,
    );
    await tester.pumpAndSettle();
    expect(find.text('Filter (1)'), findsOneWidget);
    expect(find.text('No filters are active.'), findsNothing);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsFilterProvider).hasActiveFilters, isFalse);
  });
}
