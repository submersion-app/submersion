import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_daily_breakdown.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('TripDailyBreakdown bottomTime coverage', () {
    testWidgets('computes total bottom time from dives', (tester) async {
      const tripId = 'trip-1';
      final now = DateTime(2026, 3, 28);

      final days = [
        ItineraryDay(
          id: 'day-1',
          tripId: tripId,
          dayNumber: 1,
          date: now,
          dayType: DayType.diveDay,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final dives = [
        createTestDiveWithBottomTime(
          id: 'dive-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
        ),
      ];

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            itineraryDaysProvider(tripId).overrideWith((ref) async => days),
            divesForTripProvider(tripId).overrideWith((ref) async => dives),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripDailyBreakdown(tripId: tripId)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render the breakdown with bottom time
      expect(find.byType(TripDailyBreakdown), findsOneWidget);
      // Expand the ExpansionTile to render the table
      final tile = find.byType(ExpansionTile);
      if (tile.evaluate().isNotEmpty) {
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      // Bottom time should be shown as "45min"
      expect(find.text('45min'), findsOneWidget);
    });
  });
}
