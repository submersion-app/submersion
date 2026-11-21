import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Trip _trip(TripType type) => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 10, 14),
  endDate: DateTime(2026, 10, 17),
  tripType: type,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ItineraryDay _row(DateTime date) => ItineraryDay(
  id: 'r-${date.day}',
  tripId: 'trip-1',
  dayNumber: 1,
  date: date,
  dayType: DayType.portDay,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Pumps the button and answers what it hands its hold: the trip page
/// holds those days in its sitting until Save (issue #4527).
Future<List<List<ItineraryDay>>> _pump(
  WidgetTester tester, {
  required Trip trip,
  required List<ItineraryDay> days,
}) async {
  final held = <List<ItineraryDay>>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripItineraryGenerateButton(
            trip: trip,
            days: days,
            hold: held.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return held;
}

void main() {
  testWidgets('with no rows it offers Generate and holds every day typed '
      'for the trip', (tester) async {
    final held = await _pump(tester, trip: _trip(TripType.resort), days: []);
    expect(find.text('Generate itinerary'), findsOneWidget);
    await tester.tap(find.text('Generate itinerary'));
    await tester.pumpAndSettle();
    expect(held.single.map((d) => d.dayType), [
      DayType.travel,
      DayType.diveDay,
      DayType.diveDay,
      DayType.travel,
    ]);
  });

  testWidgets('a liveaboard generates embark and disembark', (tester) async {
    final held = await _pump(
      tester,
      trip: _trip(TripType.liveaboard),
      days: [],
    );
    await tester.tap(find.text('Generate itinerary'));
    await tester.pumpAndSettle();
    expect(held.single.first.dayType, DayType.embark);
    expect(held.single.last.dayType, DayType.disembark);
  });

  testWidgets('with some rows it offers Fill in missing days and holds only '
      'the missing dates', (tester) async {
    final held = await _pump(
      tester,
      trip: _trip(TripType.resort),
      days: [_row(DateTime(2026, 10, 15))],
    );
    expect(find.text('Generate itinerary'), findsNothing);
    expect(find.text('Fill in missing days'), findsOneWidget);
    await tester.tap(find.text('Fill in missing days'));
    await tester.pumpAndSettle();
    expect(held.single.map((d) => d.date.day), [14, 16, 17]);
  });

  testWidgets('with every date covered it renders nothing', (tester) async {
    await _pump(
      tester,
      trip: _trip(TripType.resort),
      days: [for (var d = 14; d <= 17; d++) _row(DateTime(2026, 10, d))],
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
