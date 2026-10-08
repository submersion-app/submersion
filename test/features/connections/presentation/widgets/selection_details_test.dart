import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_details.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
const _reef = NodeRef(ConnectionKind.site, 'reef');
const _night = NodeRef(ConnectionKind.tag, 'night');

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
    const ConnectionNode(ref: _reef, label: 'Reef', diveCount: 1),
    const ConnectionNode(ref: _night, label: 'Night', diveCount: 1),
  ],
  edges: [
    ConnectionEdge(
      source: _b('jane'),
      target: _b('ken'),
      weight: 2,
      firstDiveAt: DateTime.utc(2024, 1, 10),
      lastDiveAt: DateTime.utc(2024, 3, 5),
    ),
    ConnectionEdge(
      source: _b('jane'),
      target: _reef,
      weight: 1,
      firstDiveAt: DateTime.utc(2024, 2, 1),
      lastDiveAt: DateTime.utc(2024, 2, 1),
    ),
    // Ties Reef on weight but dived more recently, so it ranks first.
    ConnectionEdge(
      source: _b('jane'),
      target: _night,
      weight: 1,
      firstDiveAt: DateTime.utc(2024, 6, 1),
      lastDiveAt: DateTime.utc(2024, 6, 1),
    ),
  ],
);

String _stat(WidgetTester tester, String id) {
  final tile = find.byKey(ValueKey('connections-stat-$id'));
  expect(tile, findsOneWidget, reason: 'stat tile $id');
  return tester
      .widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)))
      .map((t) => t.data)
      .join('|');
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  GraphSelection selection, {
  List<String> diveIds = const ['d1', 'd2'],
}) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    initialLocation: '/insights/connections',
    routes: [
      GoRoute(
        path: '/insights/connections',
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
        locale: const Locale('en'),
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
  // The line's dates go through DateFormat, which reads the process-global
  // Intl.defaultLocale; pin it and put it back for the next file.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('a node shows its kind, label, role subtitle and stat tiles', (
    tester,
  ) async {
    await _pump(tester, NodeSelection(_b('jane')));
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('Instructor'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('connections-details-kind')),
        matching: find.text('Buddy'),
      ),
      findsOneWidget,
    );
    expect(_stat(tester, 'dives'), '3|Dives');
    expect(_stat(tester, 'connections'), '3|Connections');
  });

  testWidgets('top connections list kind, count and a bar per row', (
    tester,
  ) async {
    await _pump(tester, NodeSelection(_b('jane')));
    expect(find.text('Top connections'), findsOneWidget);
    final ken = find.byKey(ValueKey('connections-top-${_b('ken').wire}'));
    final reef = find.byKey(ValueKey('connections-top-${_reef.wire}'));
    expect(find.descendant(of: ken, matching: find.text('Ken')), findsOne);
    expect(find.descendant(of: ken, matching: find.text('Buddy')), findsOne);
    expect(find.descendant(of: ken, matching: find.text('2')), findsOne);
    expect(find.descendant(of: reef, matching: find.text('Site')), findsOne);
    double bar(Finder row) => tester
        .widget<LinearProgressIndicator>(
          find.descendant(
            of: row,
            matching: find.byType(LinearProgressIndicator),
          ),
        )
        .value!;
    expect(bar(ken), 1.0);
    expect(bar(reef), 0.5);
    // Strongest first; a tie goes to the more recent, as in the summary.
    final night = find.byKey(ValueKey('connections-top-${_night.wire}'));
    expect(tester.getTopLeft(ken).dy, lessThan(tester.getTopLeft(night).dy));
    expect(tester.getTopLeft(night).dy, lessThan(tester.getTopLeft(reef).dy));
  });

  testWidgets('a stat tile reads as one item to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, NodeSelection(_b('jane')));
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('connections-stat-dives')))
          .label,
      '3\nDives',
    );
    handle.dispose();
  });

  testWidgets('tapping a top connection selects the line between the two', (
    tester,
  ) async {
    final container = await _pump(tester, NodeSelection(_b('jane')));
    await tester.tap(find.byKey(ValueKey('connections-top-${_reef.wire}')));
    await tester.pump();
    expect(
      container.read(connectionsSelectionProvider),
      EdgeSelection(_b('jane'), _reef),
    );
  });

  testWidgets('a top connection is a labelled button a screen reader can tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final container = await _pump(tester, NodeSelection(_b('jane')));
    final row = find.byKey(ValueKey('connections-top-${_reef.wire}'));
    final node = tester.getSemantics(row);
    expect(node.label, 'Reef, Site, 1 dive');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Reef, Site, 1 dive'));
    await tester.pump();
    expect(
      container.read(connectionsSelectionProvider),
      EdgeSelection(_b('jane'), _reef),
    );
    handle.dispose();
  });

  testWidgets('the actions are spaced and never wrap into each other', (
    tester,
  ) async {
    await _pump(tester, NodeSelection(_b('jane')));
    final show = tester.getRect(
      find.byKey(const ValueKey('connections-action-showDives')),
    );
    final open = tester.getRect(
      find.byKey(const ValueKey('connections-action-open')),
    );
    final centre = tester.getRect(
      find.byKey(const ValueKey('connections-action-centre')),
    );
    expect(open.top - show.bottom, greaterThanOrEqualTo(8));
    expect(centre.top, open.top);
    expect(centre.left - open.right, greaterThanOrEqualTo(8));
    expect(open.width, closeTo(centre.width, 0.5));
    expect(show.left, open.left);
    expect(show.right, centre.right);
  });

  testWidgets('Open and Centre here share a height when a label wraps', (
    tester,
  ) async {
    // The panel's content width, where the test font wraps Centre here.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(308, 900);
    addTearDown(tester.view.reset);
    await _pump(tester, NodeSelection(_b('jane')));
    final open = tester.getRect(
      find.byKey(const ValueKey('connections-action-open')),
    );
    final centre = tester.getRect(
      find.byKey(const ValueKey('connections-action-centre')),
    );
    expect(centre.height, open.height);
  });

  testWidgets('a node without a detail page offers Centre here at full width', (
    tester,
  ) async {
    await _pump(tester, const NodeSelection(_night));
    expect(find.byKey(const ValueKey('connections-action-open')), findsNothing);
    final show = tester.getRect(
      find.byKey(const ValueKey('connections-action-showDives')),
    );
    final centre = tester.getRect(
      find.byKey(const ValueKey('connections-action-centre')),
    );
    expect(centre.width, show.width);
  });

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

  testWidgets('a line shows both ends with kinds, dives and first/last', (
    tester,
  ) async {
    // The panel's width, where the dates must shrink to fit their tiles.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(308, 900);
    addTearDown(tester.view.reset);
    await _pump(tester, EdgeSelection(_b('jane'), _reef));
    final ends = find.byKey(const ValueKey('connections-details-ends'));
    expect(find.descendant(of: ends, matching: find.text('Jane')), findsOne);
    expect(find.descendant(of: ends, matching: find.text('Reef')), findsOne);
    expect(find.descendant(of: ends, matching: find.text('Buddy')), findsOne);
    expect(find.descendant(of: ends, matching: find.text('Site')), findsOne);
    expect(_stat(tester, 'dives'), '1|Dives');
    expect(_stat(tester, 'first'), startsWith('Feb 1, 2024|'));
    expect(_stat(tester, 'first'), endsWith('|First'));
    expect(_stat(tester, 'last'), endsWith('|Last'));
    Rect tile(String id) =>
        tester.getRect(find.byKey(ValueKey('connections-stat-$id')));
    expect(tile('first').height, tile('dives').height);
    expect(tile('last').top, tile('dives').top);
    expect(find.text('Centre here'), findsNothing);
    expect(find.text('Open'), findsNothing);
    expect(find.text('Top connections'), findsNothing);
  });
}
