import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_routes.dart';

/// The trips list's openers of a new trip (issue #4527, phase 3, plan 11).
void main() {
  // A new trip opens on the trip page behind the phase 3 switch (issue
  // #4527, phase 3, plan 11).
  testWidgets("the pane's new trip is the page with the switch on", (
    tester,
  ) async {
    void onSaved(String id) {}
    void onCancel() {}
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
    final page = newTripPane(context, onSaved, onCancel) as TripDetailPage;
    expect(page.embedded, isTrue);
    expect(page.newTrip, isNotNull);
    expect(page.onCreated, same(onSaved));
    expect(page.onCreateCancelled, same(onCancel));
  });

  testWidgets('Add on a phone opens the new trip once created', (tester) async {
    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => openNewTrip(context),
              child: const Text('add'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop('n1'),
                  child: const Text('NEW'),
                ),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) =>
                  Scaffold(body: Text('TRIP ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEW'));
    await tester.pumpAndSettle();

    expect(find.text('TRIP n1'), findsOneWidget);
    expect(find.text('add'), findsNothing);
  });
}
