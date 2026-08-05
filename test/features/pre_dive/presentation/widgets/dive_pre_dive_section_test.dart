import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/dive_pre_dive_section.dart';

import '../../../../helpers/test_app.dart';

/// Overrides only the affordance methods the section reaches through; the
/// superclass constructor is cheap (no DB touched until a query runs).
class _FakeSessionRepo extends PreDiveSessionRepository {
  _FakeSessionRepo({this.unlinked = const []});

  final List<PreDiveSession> unlinked;
  String? unlinkedFrom;
  (String, String)? linked;

  @override
  Future<List<PreDiveSession>> getUnlinkedSessions({String? diverId}) async =>
      unlinked;

  @override
  Future<void> unlinkFromDive(String sessionId) async {
    unlinkedFrom = sessionId;
  }

  @override
  Future<void> linkToDive(String sessionId, String diveId) async {
    linked = (sessionId, diveId);
  }
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Dive dive({bool planned = false}) =>
      Dive(id: 'd1', dateTime: now, isPlanned: planned);

  final linkedSession = PreDiveSession(
    id: 's1',
    templateName: 'BWRAF Buddy Check',
    diveId: 'd1',
    startedAt: now,
    completedAt: now,
    status: PreDiveSessionStatus.completed,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem flaggedItem() => PreDiveSessionItem(
    id: 'i1',
    sessionId: 's1',
    title: 'Weights',
    state: PreDiveItemState.flagged,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpSection(
    WidgetTester tester, {
    required Dive d,
    PreDiveSession? session,
    List<PreDiveSessionItem> items = const [],
    PreDiveSessionRepository? repo,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          if (repo != null)
            preDiveSessionRepositoryProvider.overrideWithValue(repo),
          preDiveSessionForDiveProvider(
            'd1',
          ).overrideWith((ref) async => session),
          preDiveSessionItemsProvider('s1').overrideWith((ref) async => items),
        ],
        child: DivePreDiveSection(dive: d),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('linked dive shows the session with Unlink menu', (tester) async {
    await pumpSection(tester, d: dive(), session: linkedSession);
    expect(find.text('BWRAF Buddy Check'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Unlink'), findsOneWidget);
  });

  testWidgets('unlinked planned dive offers Run', (tester) async {
    await pumpSection(tester, d: dive(planned: true));
    expect(find.text('Run pre-dive checklist'), findsOneWidget);
    expect(find.text('Link a checklist session'), findsNothing);
  });

  testWidgets('unlinked logged dive offers Link', (tester) async {
    await pumpSection(tester, d: dive());
    expect(find.text('Link a checklist session'), findsOneWidget);
    expect(find.text('Run pre-dive checklist'), findsNothing);
  });

  testWidgets('linked session with flags shows flag icon and badge', (
    tester,
  ) async {
    await pumpSection(
      tester,
      d: dive(),
      session: linkedSession,
      items: [flaggedItem()],
    );
    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.textContaining('1 flagged'), findsOneWidget);
  });

  testWidgets('unclean session (no flags) shows check icon, no badge', (
    tester,
  ) async {
    await pumpSection(tester, d: dive(), session: linkedSession);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsNothing);
    expect(find.textContaining('flagged'), findsNothing);
  });

  testWidgets('selecting Unlink calls repository.unlinkFromDive', (
    tester,
  ) async {
    final repo = _FakeSessionRepo();
    await pumpSection(tester, d: dive(), session: linkedSession, repo: repo);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();

    expect(repo.unlinkedFrom, 's1');
  });

  testWidgets('Link with no candidates shows a snackbar', (tester) async {
    final repo = _FakeSessionRepo(unlinked: const []);
    await pumpSection(tester, d: dive(), repo: repo);

    await tester.tap(find.text('Link a checklist session'));
    await tester.pumpAndSettle();

    expect(find.text('No unlinked checklist sessions'), findsOneWidget);
  });

  testWidgets('Link with candidates opens picker and links the choice', (
    tester,
  ) async {
    final candidate = PreDiveSession(
      id: 's2',
      templateName: 'Second Rig',
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final repo = _FakeSessionRepo(unlinked: [candidate]);
    await pumpSection(tester, d: dive(), repo: repo);

    await tester.tap(find.text('Link a checklist session'));
    await tester.pumpAndSettle();
    expect(find.text('Second Rig'), findsOneWidget);

    await tester.tap(find.text('Second Rig'));
    await tester.pumpAndSettle();

    expect(repo.linked, ('s2', 'd1'));
  });

  testWidgets('tapping the linked row navigates to the session', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: DivePreDiveSection(dive: dive())),
        ),
        GoRoute(
          path: '/pre-dive-sessions/:id',
          builder: (context, state) =>
              Scaffold(body: Text('SESSION ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          preDiveSessionForDiveProvider(
            'd1',
          ).overrideWith((ref) async => linkedSession),
          preDiveSessionItemsProvider(
            's1',
          ).overrideWith((ref) async => <PreDiveSessionItem>[]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('SESSION s1'), findsOneWidget);
  });
}
