import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/tracks/application/tracks_match_controller.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_match_snackbar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/test_app.dart';

Future<void> _show(WidgetTester tester, TracksMatchOutcome outcome) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTracksMatchOutcome(
                messenger: ScaffoldMessenger.of(context),
                l10n: context.l10n,
                router: GoRouter.of(context),
                outcome: outcome,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dives/match-sites',
        builder: (context, state) =>
            Scaffold(body: Text('MATCH-SITES ${state.extra}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    testAppRouter(router: router, locale: const Locale('en')),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

final NavTrackLinkProposal _proposal = (
  route: NavTrack(
    id: 'r1',
    source: NavTrackSource.seacraftEnc,
    startTime: 0,
    endTime: 1,
    pointCount: 2,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
  dive: Dive(id: 'd1', dateTime: DateTime.utc(2026)),
);

void main() {
  testWidgets('reports positioned dives and offers the site review', (
    tester,
  ) async {
    await _show(
      tester,
      const TracksMatchOutcome(positionedDiveIds: ['d1', 'd2'], failed: false),
    );
    expect(find.text('2 dives positioned'), findsOneWidget);

    await tester.tap(find.text('Review site matches'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH-SITES [d1, d2]'), findsOneWidget);
  });

  testWidgets('nothing new says so, with no review action', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(positionedDiveIds: [], failed: false),
    );
    expect(find.text('No dives matched a recorded track'), findsOneWidget);
    expect(find.text('Review site matches'), findsNothing);
  });

  testWidgets('a failure says so', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(positionedDiveIds: [], failed: true),
    );
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  // #4851: Match also links the underwater tracks the diver confirmed.
  testWidgets('reports underwater tracks linked', (tester) async {
    await _show(
      tester,
      TracksMatchOutcome(
        positionedDiveIds: const [],
        failed: false,
        linkProposals: [_proposal, _proposal],
        linkedTrackCount: 2,
      ),
    );
    expect(find.text('2 underwater tracks linked'), findsOneWidget);
    expect(find.text('Review site matches'), findsNothing);
  });

  testWidgets('reports positioned dives and linked tracks together', (
    tester,
  ) async {
    await _show(
      tester,
      TracksMatchOutcome(
        positionedDiveIds: const ['d1', 'd2'],
        failed: false,
        linkProposals: [_proposal],
        linkedTrackCount: 1,
      ),
    );
    expect(
      find.text('2 dives positioned · 1 underwater track linked'),
      findsOneWidget,
    );
    expect(find.text('Review site matches'), findsOneWidget);
  });

  testWidgets('tracks offered but not linked, with nothing positioned, say '
      'nothing: the diver has just answered the dialog', (tester) async {
    await _show(
      tester,
      TracksMatchOutcome(
        positionedDiveIds: const [],
        failed: false,
        linkProposals: [_proposal],
      ),
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a part that failed still reports what was linked', (
    tester,
  ) async {
    await _show(
      tester,
      TracksMatchOutcome(
        positionedDiveIds: const [],
        failed: true,
        linkProposals: [_proposal, _proposal],
        linkedTrackCount: 1,
      ),
    );
    expect(
      find.text(
        '1 underwater track linked · Something went wrong. Please try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Link that could link nothing says so', (tester) async {
    await _show(
      tester,
      TracksMatchOutcome(
        positionedDiveIds: const [],
        failed: false,
        linkProposals: [_proposal],
      ).afterLinking(linked: 0, failed: false),
    );
    expect(find.text('0 underwater tracks linked'), findsOneWidget);
  });

  testWidgets('declining clears the message an earlier press left', (
    tester,
  ) async {
    await _show(
      tester,
      const TracksMatchOutcome(positionedDiveIds: ['d1', 'd2'], failed: false),
    );
    expect(find.text('2 dives positioned'), findsOneWidget);

    final context = tester.element(find.text('go'));
    showTracksMatchOutcome(
      messenger: ScaffoldMessenger.of(context),
      l10n: context.l10n,
      router: GoRouter.of(context),
      outcome: TracksMatchOutcome(
        positionedDiveIds: const [],
        failed: false,
        linkProposals: [_proposal],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 dives positioned'), findsNothing);
  });
}
