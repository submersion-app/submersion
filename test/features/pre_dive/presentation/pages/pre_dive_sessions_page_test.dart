import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_sessions_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session(
    String id, {
    String name = 'CCR Build',
    PreDiveSessionStatus status = PreDiveSessionStatus.inProgress,
    String? diveId,
  }) => PreDiveSession(
    id: id,
    templateName: name,
    status: status,
    diveId: diveId,
    startedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem item(
    String sessionId,
    int order,
    PreDiveItemState state,
  ) => PreDiveSessionItem(
    id: '$sessionId-i$order',
    sessionId: sessionId,
    title: 'Item $order',
    sortOrder: order,
    state: state,
    createdAt: now,
    updatedAt: now,
  );

  // Overrides the per-session items family for each id so the real
  // repository-backed provider never runs during a widget test.
  List<dynamic> itemOverridesFor(Map<String, List<PreDiveSessionItem>> byId) =>
      [
        for (final entry in byId.entries)
          preDiveSessionItemsProvider(
            entry.key,
          ).overrideWith((ref) async => entry.value),
      ];

  Future<void> pumpPage(
    WidgetTester tester, {
    PreDiveSession? active,
    required List<PreDiveSession> sessions,
    Map<String, List<PreDiveSessionItem>> items = const {},
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => active),
          preDiveSessionsProvider.overrideWith((ref) async => sessions),
          ...itemOverridesFor(items),
        ],
        child: const PreDiveSessionsPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders title and start FAB', (tester) async {
    await pumpPage(tester, sessions: []);

    expect(find.text('Pre-Dive Checklists'), findsOneWidget);
    expect(find.text('Start checklist'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('empty state renders when no active and no history', (
    tester,
  ) async {
    await pumpPage(tester, sessions: []);

    expect(find.text('No checklist runs yet'), findsOneWidget);
  });

  testWidgets('active session card shows name, progress and Resume', (
    tester,
  ) async {
    final s = session('s1', name: 'Deep Air Check');
    await pumpPage(
      tester,
      active: s,
      sessions: [s],
      items: {
        's1': [
          item('s1', 0, PreDiveItemState.done),
          item('s1', 1, PreDiveItemState.pending),
          item('s1', 2, PreDiveItemState.pending),
        ],
      },
    );

    expect(find.text('Deep Air Check'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Empty state must not show when an active session is pinned.
    expect(find.text('No checklist runs yet'), findsNothing);
  });

  testWidgets('history tiles render for completed and aborted sessions', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'done1',
          name: 'Reef Dive',
          status: PreDiveSessionStatus.completed,
        ),
        session(
          'ab1',
          name: 'Wreck Dive',
          status: PreDiveSessionStatus.aborted,
        ),
      ],
      items: {
        'done1': [item('done1', 0, PreDiveItemState.done)],
        'ab1': [item('ab1', 0, PreDiveItemState.skipped)],
      },
    );

    expect(find.text('Reef Dive'), findsOneWidget);
    expect(find.text('Wreck Dive'), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.textContaining('Aborted'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('in-progress history tile shows pending icon and status', (
    tester,
  ) async {
    // A session that is in-progress but not the active one still renders in
    // history and exercises the inProgress branch of both switches.
    await pumpPage(
      tester,
      sessions: [
        session(
          'ip1',
          name: 'Solo Check',
          status: PreDiveSessionStatus.inProgress,
        ),
      ],
      items: {
        'ip1': [item('ip1', 0, PreDiveItemState.pending)],
      },
    );

    expect(find.text('Solo Check'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.byIcon(Icons.pending_outlined), findsOneWidget);
  });

  testWidgets('flagged badge appears when items are flagged', (tester) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'f1',
          name: 'Cave Check',
          status: PreDiveSessionStatus.completed,
        ),
      ],
      items: {
        'f1': [
          item('f1', 0, PreDiveItemState.done),
          item('f1', 1, PreDiveItemState.flagged),
        ],
      },
    );

    expect(find.textContaining('1 flagged'), findsOneWidget);
  });

  testWidgets('linked dive chip renders when session has a diveId', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'l1',
          name: 'Boat Dive',
          status: PreDiveSessionStatus.completed,
          diveId: 'dive-42',
        ),
      ],
      items: {
        'l1': [item('l1', 0, PreDiveItemState.done)],
      },
    );

    expect(find.text('Linked dive'), findsOneWidget);
    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.byIcon(Icons.scuba_diving), findsOneWidget);
  });

  testWidgets('loading spinner shows while sessions are pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => null),
          // Never completes: keeps the provider in a loading state.
          preDiveSessionsProvider.overrideWith(
            (ref) => Completer<List<PreDiveSession>>().future,
          ),
        ],
        child: const PreDiveSessionsPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error text shows when sessions provider fails', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => null),
          preDiveSessionsProvider.overrideWith(
            (ref) async => throw StateError('boom-loading'),
          ),
        ],
        child: const PreDiveSessionsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('boom-loading'), findsOneWidget);
  });

  testWidgets('delete menu opens confirm dialog and Cancel dismisses it', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'd1',
          name: 'Night Dive',
          status: PreDiveSessionStatus.completed,
        ),
      ],
      items: {
        'd1': [item('d1', 0, PreDiveItemState.done)],
      },
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirmation dialog is shown with its body copy.
    expect(find.text('Delete this checklist record?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog dismissed; no repository call made.
    expect(find.text('Delete this checklist record?'), findsNothing);
  });

  testWidgets('tapping Resume navigates to the session runner route', (
    tester,
  ) async {
    final s = session('r1', name: 'Resume Me');
    final router = GoRouter(
      initialLocation: '/pre-dive-sessions',
      routes: [
        GoRoute(
          path: '/pre-dive-sessions',
          builder: (context, state) => const PreDiveSessionsPage(),
        ),
        GoRoute(
          path: '/pre-dive-sessions/:id',
          builder: (context, state) =>
              Scaffold(body: Text('runner-${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => s),
          preDiveSessionsProvider.overrideWith((ref) async => [s]),
          preDiveSessionItemsProvider('r1').overrideWith(
            (ref) async => [item('r1', 0, PreDiveItemState.pending)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('runner-r1'), findsOneWidget);
  });
}
