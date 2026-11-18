import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_under_way_cards.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// The two cards that matter while a trip is under way, kept together because
/// two pages of the story show them: what is left in the cylinders, and how
/// long until the no-fly window before the flight home.
void main() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  Trip trip({
    required DateTime start,
    required DateTime end,
    DateTime? returnFlightAt,
  }) => Trip(
    id: 't1',
    name: 'Bonaire',
    startDate: start,
    endDate: end,
    tripType: TripType.resort,
    returnFlightAt: returnFlightAt,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pump(WidgetTester tester, Trip trip) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          tripCylinderStatesProvider('t1').overrideWith(
            (ref) async => [
              foldCylinderState(
                cylinder: TripCylinder(
                  id: 'c1',
                  tripId: 't1',
                  label: 'Truck 1',
                  createdAt: now,
                  updatedAt: now,
                ),
                events: const [],
                uses: const [],
              ),
            ],
          ),
          tripFillForecastProvider('t1').overrideWith((ref) async => null),
          tripFlightWindowProvider('t1').overrideWith(
            (ref) async => FlightWindowStatus(
              state: FlightWindowState.open,
              flightAt: DateTime.utc(2126, 8, 10, 9),
              deadline: DateTime.utc(2126, 8, 9, 15),
              category: NoFlyCategory.repetitive,
              interval: const Duration(hours: 18),
            ),
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: TripUnderWayCards(trip: trip)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const cylinders = Key('trip-cylinders-summary');

  testWidgets('a finished trip shows neither card', (tester) async {
    await pump(
      tester,
      trip(start: day(-10), end: day(-3), returnFlightAt: day(-3)),
    );

    expect(find.byKey(cylinders), findsNothing);
    expect(find.byType(TripFlightCountdownCard), findsNothing);
  });

  testWidgets('a trip under way with a return flight shows the cylinders, '
      'then the countdown', (tester) async {
    await pump(
      tester,
      trip(start: day(-1), end: day(1), returnFlightAt: day(1)),
    );

    expect(find.byKey(cylinders), findsOneWidget);
    expect(find.byType(TripFlightCountdownCard), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(cylinders)).dy,
      lessThan(tester.getTopLeft(find.byType(TripFlightCountdownCard)).dy),
    );
  });

  testWidgets('a trip under way with no return flight shows no countdown', (
    tester,
  ) async {
    await pump(tester, trip(start: day(-1), end: day(1)));

    expect(find.byKey(cylinders), findsOneWidget);
    expect(find.byType(TripFlightCountdownCard), findsNothing);
  });
}
