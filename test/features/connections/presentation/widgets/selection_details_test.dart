import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_details.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(
      ref: _b('jane'),
      label: 'Jane',
      diveCount: 3,
      subtitle: const RoleSubtitle('instructor'),
    ),
    ConnectionNode(ref: _b('ken'), label: 'Ken', diveCount: 2),
    ConnectionNode(ref: _b('newbie'), label: 'Newbie', diveCount: 0),
  ],
  edges: [
    ConnectionEdge(
      source: _b('jane'),
      target: _b('ken'),
      weight: 2,
      firstDiveAt: DateTime.utc(2024, 1, 10),
      lastDiveAt: DateTime.utc(2024, 3, 5),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  GraphSelection selection, {
  List<String> diveIds = const ['d1', 'd2'],
}) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: '/connections',
    routes: [
      GoRoute(
        path: '/connections',
        builder: (_, _) => Scaffold(
          body: GraphSelectionDetails(graph: _graph, selection: selection),
        ),
      ),
      GoRoute(
        path: '/dives',
        builder: (_, _) => const Scaffold(body: Text('DIVE_LIST')),
      ),
      GoRoute(
        path: '/buddies/:id',
        builder: (_, s) =>
            Scaffold(body: Text('BUDDY_${s.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsSelectionDiveIdsProvider(
          selection,
        ).overrideWith((ref) async => diveIds),
        diveRoleMapProvider.overrideWith(
          (ref) async => {
            'instructor': DiveRole(
              id: 'instructor',
              name: 'Instructor',
              isBuiltIn: true,
              createdAt: DateTime.utc(2024),
              updatedAt: DateTime.utc(2024),
            ),
          },
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(GraphSelectionDetails)),
  );
}

void main() {
  testWidgets(
    'a node shows label, role subtitle, dive count and top connections',
    (tester) async {
      await _pump(tester, NodeSelection(_b('jane')));
      expect(find.text('Jane'), findsOneWidget);
      expect(find.text('Instructor'), findsOneWidget);
      expect(find.text('3 dives'), findsOneWidget);
      expect(find.text('Top connections'), findsOneWidget);
      expect(find.textContaining('Ken'), findsOneWidget);
    },
  );

  testWidgets('Show dives sets the dive list filter and navigates', (
    tester,
  ) async {
    final container = await _pump(tester, NodeSelection(_b('jane')));
    await tester.tap(find.text('Show dives'));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider).diveIds, ['d1', 'd2']);
    expect(find.text('DIVE_LIST'), findsOneWidget);
  });

  testWidgets('Show dives is disabled when the selection has no dives', (
    tester,
  ) async {
    await _pump(tester, NodeSelection(_b('newbie')), diveIds: const []);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Show dives'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Open pushes the detail route and Centre here centres the view', (
    tester,
  ) async {
    final container = await _pump(tester, NodeSelection(_b('jane')));
    await tester.tap(find.text('Centre here'));
    await tester.pump();
    expect(container.read(connectionsViewProvider).focus, _b('jane'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('BUDDY_jane'), findsOneWidget);
  });

  testWidgets('an edge shows both names, dives together and first/last dates', (
    tester,
  ) async {
    await _pump(tester, EdgeSelection(_b('jane'), _b('ken')));
    expect(find.textContaining('Jane'), findsWidgets);
    expect(find.textContaining('Ken'), findsWidgets);
    expect(find.text('2 dives together'), findsOneWidget);
    expect(find.textContaining('First '), findsOneWidget);
    expect(find.text('Centre here'), findsNothing);
  });
}
