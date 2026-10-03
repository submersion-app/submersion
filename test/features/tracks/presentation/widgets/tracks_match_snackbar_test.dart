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
}
