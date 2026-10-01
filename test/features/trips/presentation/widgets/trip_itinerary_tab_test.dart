import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Trip _trip(DateTime start) => Trip(
  id: 'trip-1',
  name: 'Red Sea',
  startDate: start,
  endDate: DateTime(2026, 3, 10),
  tripType: TripType.liveaboard,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ItineraryDay _row(String id, DateTime date, int storedNumber) => ItineraryDay(
  id: id,
  tripId: 'trip-1',
  dayNumber: storedNumber,
  date: date,
  dayType: DayType.diveDay,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> _pumpTab(
  WidgetTester tester, {
  required Trip trip,
  required List<ItineraryDay> days,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        tripByIdProvider('trip-1').overrideWith((ref) async => trip),
        itineraryDaysProvider('trip-1').overrideWith((ref) async => days),
        divesForTripProvider(
          'trip-1',
        ).overrideWith((ref) async => const <Dive>[]),
      ].cast(),
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TripItineraryTab(tripId: 'trip-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // #2664: rows written when the trip started on the 7th, and the start has
  // since moved a day earlier.
  final staleRows = [
    _row('a', DateTime(2026, 3, 7), 1),
    _row('b', DateTime(2026, 3, 9), 3),
  ];

  testWidgets('numbers days from the trip start, not the stored number', (
    tester,
  ) async {
    await _pumpTab(tester, trip: _trip(DateTime(2026, 3, 6)), days: staleRows);

    expect(find.text('Day 2'), findsOneWidget);
    expect(find.text('Day 4'), findsOneWidget);
    expect(find.text('Day 1'), findsNothing);
    expect(find.text('Day 3'), findsNothing);
  });

  testWidgets('the edit sheet names the renumbered day', (tester) async {
    await _pumpTab(tester, trip: _trip(DateTime(2026, 3, 6)), days: staleRows);

    await tester.tap(find.text('Day 4'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Day 4'), findsOneWidget);
  });
}
