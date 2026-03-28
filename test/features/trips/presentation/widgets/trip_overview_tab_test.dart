import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_overview_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('TripOverviewTab bottomTime coverage', () {
    final trip = Trip(
      id: 'trip-1',
      name: 'Test Trip',
      startDate: DateTime(2026, 3, 25),
      endDate: DateTime(2026, 3, 30),
      tripType: TripType.resort,
      notes: '',
      createdAt: DateTime(2026, 3, 20),
      updatedAt: DateTime(2026, 3, 20),
    );

    final tripWithStats = TripWithStats(
      trip: trip,
      diveCount: 2,
      totalBottomTime: 75 * 60,
      maxDepth: 30.0,
    );

    final dives = [
      createTestDiveWithBottomTime(
        id: 'trip-dive-1',
        diveNumber: 1,
        bottomTime: const Duration(minutes: 45),
        maxDepth: 25.0,
      ),
      createTestDiveWithBottomTime(
        id: 'trip-dive-2',
        diveNumber: 2,
        bottomTime: const Duration(minutes: 30),
        maxDepth: 20.0,
      ),
    ];

    testWidgets('renders dives with bottomTime in overview', (tester) async {
      final overrides = await getBaseOverrides();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: TripOverviewTab(tripWithStats: tripWithStats)),
          ),
          GoRoute(
            path: '/dives/:id',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesForTripProvider(trip.id).overrideWith((ref) async => dives),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show bottomTime values in dive list
      expect(find.text('45min'), findsOneWidget);
      expect(find.text('30min'), findsOneWidget);
    });
  });
}
