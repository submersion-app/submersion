import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingRepo extends ItineraryDayRepository {
  final saved = <ItineraryDay>[];
  @override
  Future<void> saveAll(List<ItineraryDay> days) async => saved.addAll(days);
}

class _FailingRepo extends ItineraryDayRepository {
  @override
  Future<void> saveAll(List<ItineraryDay> days) async =>
      throw StateError('database is locked');
}

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

Future<_RecordingRepo> _pump(
  WidgetTester tester, {
  required Trip trip,
  required List<ItineraryDay> days,
  ItineraryDayRepository? failing,
}) async {
  final repo = _RecordingRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itineraryDayRepositoryProvider.overrideWithValue(failing ?? repo),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripItineraryGenerateButton(trip: trip, days: days),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('with no rows it offers Generate and writes every day typed '
      'for the trip', (tester) async {
    final repo = await _pump(tester, trip: _trip(TripType.resort), days: []);
    expect(find.text('Generate itinerary'), findsOneWidget);
    await tester.tap(find.text('Generate itinerary'));
    await tester.pumpAndSettle();
    expect(repo.saved.map((d) => d.dayType), [
      DayType.travel,
      DayType.diveDay,
      DayType.diveDay,
      DayType.travel,
    ]);
  });

  testWidgets('a liveaboard generates embark and disembark', (tester) async {
    final repo = await _pump(
      tester,
      trip: _trip(TripType.liveaboard),
      days: [],
    );
    await tester.tap(find.text('Generate itinerary'));
    await tester.pumpAndSettle();
    expect(repo.saved.first.dayType, DayType.embark);
    expect(repo.saved.last.dayType, DayType.disembark);
  });

  testWidgets('with some rows it offers Fill in missing days and adds only '
      'the missing dates', (tester) async {
    final repo = await _pump(
      tester,
      trip: _trip(TripType.resort),
      days: [_row(DateTime(2026, 10, 15))],
    );
    expect(find.text('Generate itinerary'), findsNothing);
    expect(find.text('Fill in missing days'), findsOneWidget);
    await tester.tap(find.text('Fill in missing days'));
    await tester.pumpAndSettle();
    expect(repo.saved.map((d) => d.date.day), [14, 16, 17]);
  });

  testWidgets('with every date covered it renders nothing', (tester) async {
    await _pump(
      tester,
      trip: _trip(TripType.resort),
      days: [for (var d = 14; d <= 17; d++) _row(DateTime(2026, 10, d))],
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('a failed Generate says so without the exception', (
    tester,
  ) async {
    await _pump(
      tester,
      trip: _trip(TripType.resort),
      days: [],
      failing: _FailingRepo(),
    );
    await tester.tap(find.text('Generate itinerary'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't generate the itinerary. Try again."),
      findsOneWidget,
    );
    expect(find.textContaining('database is locked'), findsNothing);
    // The button is back for another try.
    expect(find.text('Generate itinerary'), findsOneWidget);
  });
}
