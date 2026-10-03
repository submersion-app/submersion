import 'package:clock/clock.dart';
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

Trip _resortTrip() => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 6),
  endDate: DateTime(2026, 3, 10),
  tripType: TripType.resort,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// An updateDay that records the day it was given.
class _RecordingItineraryRepo extends ItineraryDayRepository {
  final updated = <ItineraryDay>[];
  @override
  Future<void> updateDay(ItineraryDay day) async => updated.add(day);
}

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

  testWidgets('an empty itinerary explains itself and offers Generate', (
    tester,
  ) async {
    await _pumpTab(tester, trip: _resortTrip(), days: const []);
    expect(
      find.text('No itinerary yet. Generate one from the trip dates.'),
      findsOneWidget,
    );
    expect(find.text('Generate itinerary'), findsOneWidget);
    expect(find.text('No dives'), findsNothing);
  });

  testWidgets('a partial itinerary offers Fill in missing days above the '
      'list', (tester) async {
    await _pumpTab(tester, trip: _resortTrip(), days: staleRows);
    expect(find.text('Fill in missing days'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('a day ahead with a plan says how many dives', (tester) async {
    final planned = _row(
      'p',
      DateTime(2026, 3, 9),
      4,
    ).copyWith(plannedDives: 3);
    await withClock(Clock.fixed(DateTime(2026, 3, 6, 10)), () async {
      await _pumpTab(tester, trip: _resortTrip(), days: [planned]);
    });
    expect(find.text('3 dives planned'), findsOneWidget);
  });

  testWidgets('off a boat the sheet labels the place Location and offers '
      'land day types', (tester) async {
    await _pumpTab(tester, trip: _resortTrip(), days: staleRows);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Port / Anchorage'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    expect(find.text('Travel').hitTestable(), findsOneWidget);
    expect(find.text('Rest').hitTestable(), findsOneWidget);
    expect(find.text('Embark').hitTestable(), findsNothing);
  });

  testWidgets('on a boat the sheet keeps Port / Anchorage and the maritime '
      'types', (tester) async {
    await _pumpTab(tester, trip: _trip(DateTime(2026, 3, 6)), days: staleRows);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Port / Anchorage'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    expect(find.text('Embark').hitTestable(), findsOneWidget);
    expect(find.text('Travel').hitTestable(), findsOneWidget);
  });

  testWidgets('a sea day on a resort trip keeps its type', (tester) async {
    final sea = ItineraryDay(
      id: 'sea',
      tripId: 'trip-1',
      dayNumber: 2,
      date: DateTime(2026, 3, 7),
      dayType: DayType.seaDay,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final repo = _RecordingItineraryRepo();
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: [sea],
      extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    // The dropdown shows the stored value even though a resort trip does
    // not offer it.
    expect(find.text('Sea Day'), findsWidgets);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.updated.single.dayType, DayType.seaDay);
  });

  testWidgets(
    'the sheet saves planned dives, and a dive day at 0 keeps its type',
    (tester) async {
      final repo = _RecordingItineraryRepo();
      await _pumpTab(
        tester,
        trip: _resortTrip(),
        days: staleRows,
        extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('itinerary-planned-dives')),
        '0',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.updated.single.plannedDives, 0);
      // The spec: saving as Dive day with 0 keeps the type; the story still
      // reads it as a planned rest day (TripStoryDay.isPlannedRest).
      expect(repo.updated.single.dayType, DayType.diveDay);
    },
  );

  testWidgets('saving a day as Rest plans it at none', (tester) async {
    final repo = _RecordingItineraryRepo();
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.updated.single.dayType, DayType.rest);
    expect(repo.updated.single.plannedDives, 0);
  });

  testWidgets('a non-number in planned dives is refused in place', (
    tester,
  ) async {
    final repo = _RecordingItineraryRepo();
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      'two',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a whole number of dives, or leave it blank.'),
      findsOneWidget,
    );
    expect(repo.updated, isEmpty);
  });

  testWidgets('a Rest day switched to Dive day goes back to the estimate', (
    tester,
  ) async {
    final rest = ItineraryDay(
      id: 'r',
      tripId: 'trip-1',
      dayNumber: 2,
      date: DateTime(2026, 3, 7),
      dayType: DayType.rest,
      plannedDives: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final repo = _RecordingItineraryRepo();
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: [rest],
      extra: [itineraryDayRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dive Day').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.updated.single.dayType, DayType.diveDay);
    expect(repo.updated.single.plannedDives, isNull);
  });

  testWidgets('a past day does not claim its plan is still to come', (
    tester,
  ) async {
    final past = _row('p', DateTime(2026, 3, 7), 2).copyWith(plannedDives: 3);
    final ahead = _row('a', DateTime(2026, 3, 9), 4).copyWith(plannedDives: 2);
    await withClock(Clock.fixed(DateTime(2026, 3, 8, 10)), () async {
      await _pumpTab(tester, trip: _resortTrip(), days: [past, ahead]);
    });
    expect(find.text('3 dives planned'), findsNothing);
    expect(find.text('2 dives planned'), findsOneWidget);
  });

  testWidgets('on a Rest day the planned dives field reads 0 and is locked', (
    tester,
  ) async {
    await _pumpTab(tester, trip: _resortTrip(), days: staleRows);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      '2',
    );
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest').hitTestable());
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('itinerary-planned-dives')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.enabled, isFalse);
    expect(field.controller!.text, '0');
  });
}
