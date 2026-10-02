import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

void main() {
  testWidgets('reports both counts and offers the site review', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(
        positionedDiveIds: ['d1', 'd2'],
        linkedUnderwaterIds: ['r1'],
        anyFailed: false,
      ),
    );
    expect(
      find.text('Dives positioned: 2 · Underwater tracks linked: 1'),
      findsOneWidget,
    );

    await tester.tap(find.text('Review site matches'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH-SITES [d1, d2]'), findsOneWidget);
  });

  testWidgets('underwater links alone offer no site review', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(
        positionedDiveIds: [],
        linkedUnderwaterIds: ['r1'],
        anyFailed: false,
      ),
    );
    expect(
      find.text('Dives positioned: 0 · Underwater tracks linked: 1'),
      findsOneWidget,
    );
    expect(find.text('Review site matches'), findsNothing);
  });

  testWidgets('nothing new says so', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(
        positionedDiveIds: [],
        linkedUnderwaterIds: [],
        anyFailed: false,
      ),
    );
    expect(find.text('No new matches'), findsOneWidget);
  });

  testWidgets('a failure says so even when the other sweep matched', (
    tester,
  ) async {
    await _show(
      tester,
      const TracksMatchOutcome(
        positionedDiveIds: [],
        linkedUnderwaterIds: ['r1'],
        anyFailed: true,
      ),
    );
    expect(
      find.text('Some tracks could not be matched. Try again.'),
      findsOneWidget,
    );
  });
}
