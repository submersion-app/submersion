import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

final _trip = Trip(
  id: 't1',
  name: 'Red Sea Liveaboard',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 3, 8),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  /// Opens the trip list's search page the way its app bar does, inside a
  /// router so a tapped result can navigate.
  Future<void> openSearch(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showSearch(
                context: context,
                delegate: TripSearchDelegate(context.l10n),
              ),
              child: const Text('open search'),
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) =>
              Text('detail ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...await getBaseOverrides(),
          tripSearchProvider.overrideWith((ref, q) async => [_trip]),
          ...extra,
        ],
      ),
    );
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'red');
    await tester.pumpAndSettle();
  }

  // Issue #3377: a tapped result closed the search before opening the trip,
  // so back from the trip landed on the full list, not the results.
  testWidgets('a tap opens the trip, and back returns to the results', (
    tester,
  ) async {
    await openSearch(tester);

    await tester.tap(find.text('Red Sea Liveaboard'));
    await tester.pumpAndSettle();
    expect(find.text('detail t1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Red Sea Liveaboard'), findsOneWidget);
    expect(find.text('open search'), findsNothing);
  });

  testWidgets('a side trip found by search names its larger trip', (
    tester,
  ) async {
    final egypt = Trip(
      id: 'p',
      name: 'Egypt 2026',
      startDate: DateTime(2026, 2, 20),
      endDate: DateTime(2026, 3, 10),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await openSearch(
      tester,
      extra: [parentTripProvider('t1').overrideWith((ref) async => egypt)],
    );
    expect(find.textContaining('Part of Egypt 2026'), findsOneWidget);
  });
}
