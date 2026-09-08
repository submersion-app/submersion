import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/pre_dive_dashboard_card.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session() => PreDiveSession(
    id: 's1',
    templateName: 'CCR Build',
    startedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem item(int order, PreDiveItemState state) =>
      PreDiveSessionItem(
        id: 'i$order',
        sessionId: 's1',
        title: 'Item $order',
        sortOrder: order,
        state: state,
        createdAt: now,
        updatedAt: now,
      );

  PreDiveChecklistTemplate builtIn() => PreDiveChecklistTemplate(
    id: 'b1',
    name: 'BWRAF',
    isBuiltIn: true,
    builtinKey: 'b1',
    createdAt: now,
    updatedAt: now,
  );

  Trip trip() => Trip(
    id: 't1',
    name: 'Red Sea',
    startDate: now,
    endDate: now.add(const Duration(days: 7)),
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    PreDiveSession? active,
    List<PreDiveSession> sessions = const [],
    List<PreDiveChecklistTemplate>? templates,
    List<PreDiveSessionItem> items = const [],
    ({Trip trip, int done, int total})? tripChecklist,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => active),
          preDiveSessionsProvider.overrideWith((ref) async => sessions),
          preDiveTemplatesProvider.overrideWith(
            (ref) async => templates ?? [builtIn()],
          ),
          preDiveSessionItemsProvider('s1').overrideWith((ref) async => items),
          homeTripChecklistProvider.overrideWith((ref) async => tripChecklist),
        ],
        child: const PreDiveDashboardCard(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hidden when unused (built-ins alone do not surface it)', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('Start pre-dive check'), findsNothing);
    expect(find.text('Pre-Dive Check'), findsNothing);
  });

  testWidgets('active session shows Resume with progress', (tester) async {
    final s = session();
    await pumpCard(
      tester,
      active: s,
      sessions: [s],
      items: [
        item(0, PreDiveItemState.done),
        item(1, PreDiveItemState.pending),
        item(2, PreDiveItemState.pending),
      ],
    );
    expect(find.text('Resume - 1 of 3'), findsOneWidget);
  });

  testWidgets('history without an active session shows Start', (tester) async {
    final s = session();
    await pumpCard(tester, sessions: [s]);
    expect(find.text('Start pre-dive check'), findsOneWidget);
  });

  group('trip checklists get their own row rather than the pre-dive one', () {
    testWidgets('a trip checklist alone surfaces the card', (tester) async {
      // Pre-dive is unused here: before this row existed the card stayed
      // hidden and the trip list had no home surface at all.
      await pumpCard(tester, tripChecklist: (trip: trip(), done: 2, total: 5));
      expect(find.text('Checklists'), findsOneWidget);
      expect(find.text('Trip: Red Sea'), findsOneWidget);
      expect(find.text('2 of 5 to-dos done'), findsOneWidget);
      expect(find.text('Start pre-dive check'), findsNothing);
    });

    testWidgets('both rows are labelled apart when both apply', (tester) async {
      await pumpCard(
        tester,
        sessions: [session()],
        tripChecklist: (trip: trip(), done: 0, total: 3),
      );
      expect(find.text('Pre-dive'), findsOneWidget);
      expect(find.text('Start pre-dive check'), findsOneWidget);
      expect(find.text('Trip: Red Sea'), findsOneWidget);
      expect(find.text('0 of 3 to-dos done'), findsOneWidget);
    });

    testWidgets('the trip row opens that trip', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PreDiveDashboardCard()),
          GoRoute(
            path: '/trips/:tripId',
            builder: (_, state) =>
                Scaffold(body: Text('TRIP ${state.pathParameters['tripId']}')),
          ),
        ],
      );
      await tester.pumpWidget(
        testAppRouter(
          router: router,
          locale: const Locale('en'),
          overrides: [
            preDiveActiveSessionProvider.overrideWith((ref) async => null),
            preDiveSessionsProvider.overrideWith((ref) async => const []),
            preDiveTemplatesProvider.overrideWith((ref) async => [builtIn()]),
            homeTripChecklistProvider.overrideWith(
              (ref) async => (trip: trip(), done: 1, total: 4),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 of 4 to-dos done'));
      await tester.pumpAndSettle();

      expect(find.text('TRIP t1'), findsOneWidget);
    });

    testWidgets('no trip checklist leaves the pre-dive row alone', (
      tester,
    ) async {
      await pumpCard(tester, sessions: [session()]);
      expect(find.text('Start pre-dive check'), findsOneWidget);
      expect(find.textContaining('Trip:'), findsNothing);
    });
  });
}
