import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
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

/// An updateDay that fails the way a locked database does.
class _FailingItineraryRepo extends ItineraryDayRepository {
  @override
  Future<void> updateDay(ItineraryDay day) async {
    throw StateError('database is locked');
  }
}

/// [reload], when given, is what every itinerary load after the first
/// returns, so a test can hold a reload open; [tripAfter] is likewise what
/// every trip read after the first returns.
Future<void> _pumpTab(
  WidgetTester tester, {
  required Trip? trip,
  required List<ItineraryDay> days,
  Future<List<ItineraryDay>>? reload,
  Trip? tripAfter,
  Object? loadError,
  List<Object> extra = const [],
}) async {
  var loads = 0;
  var tripReads = 0;
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        tripByIdProvider('trip-1').overrideWith(
          (ref) async =>
              tripReads++ == 0 || tripAfter == null ? trip : tripAfter,
        ),
        itineraryDaysProvider('trip-1').overrideWith((ref) async {
          if (loadError != null) throw loadError;
          return loads++ == 0 || reload == null ? days : reload;
        }),
        divesForTripProvider(
          'trip-1',
        ).overrideWith((ref) async => const <Dive>[]),
        ...extra,
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

  testWidgets('renumbers the open tab when the trip start moves', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      trip: _trip(DateTime(2026, 3, 7)),
      days: staleRows,
      // The trip as a later read sees it: the start moved a day earlier, as
      // a sync from another device would move it.
      tripAfter: _trip(DateTime(2026, 3, 6)),
    );
    expect(find.text('Day 3'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(TripItineraryTab)),
    ).invalidate(tripByIdProvider('trip-1'));
    await tester.pumpAndSettle();

    expect(find.text('Day 4'), findsOneWidget);
    expect(find.text('Day 3'), findsNothing);
  });

  testWidgets('keeps the list on screen while an edit reloads it', (
    tester,
  ) async {
    final pending = Completer<List<ItineraryDay>>();
    await _pumpTab(
      tester,
      trip: _trip(DateTime(2026, 3, 6)),
      days: staleRows,
      reload: pending.future,
    );

    // What the edit sheet does on save.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TripItineraryTab)),
    );
    container.invalidate(itineraryDaysProvider('trip-1'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Day 4'), findsOneWidget);
  });

  testWidgets('shows the stored numbers when the trip is gone', (tester) async {
    // Nothing to number from: the rows are listed as the repository returns
    // them (by date), under their stored numbers.
    await _pumpTab(tester, trip: null, days: staleRows);

    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 3'), findsOneWidget);
  });

  testWidgets('a failed itinerary load says so without the exception', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      trip: _trip(DateTime(2026, 3, 6)),
      days: staleRows,
      loadError: StateError('database is locked'),
    );

    expect(find.text("Couldn't load the itinerary."), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });

  testWidgets('a failed day save says so without the exception', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      trip: _trip(DateTime(2026, 3, 6)),
      days: staleRows,
      extra: [
        itineraryDayRepositoryProvider.overrideWithValue(
          _FailingItineraryRepo(),
        ),
      ],
    );

    await tester.tap(find.text('Day 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save the day. Try again."), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });
}
