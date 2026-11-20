import 'package:clock/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_slots.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../pages/trip_detail_page_unlock_harness.dart';

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

/// The trip page's sitting the tab acts in (issue #4527): its session, and
/// the itinerary store its held writes go to at Save.
typedef _Sitting = ({EditSession<Trip> session, FakeItineraryDays store});

/// The trip page's slots for an open sitting on [trip], with no frames.
TripCardSlots _slots(Trip trip, EditSession<Trip> session) => TripCardSlots(
  shown: trip,
  layout: trip,
  session: session,
  frame: (_, child) => child,
  dayPlanFrame: (_, child) => child,
  showsWhileEmpty: (_) => false,
  openCard: (_) {},
  unlockAt: (_) => session,
);

/// The day [id] as [sitting] holds it.
ItineraryDay _heldDay(_Sitting sitting, String id) => tripItineraryDays(
  sitting.store,
).current(sitting.session)!.singleWhere((d) => d.id == id);

/// What Save writes for the days the sheet changed.
Future<List<ItineraryDay>> _savedDays(_Sitting sitting) async {
  await sitting.session.runHeldWrites();
  return sitting.store.updated;
}

/// [reload], when given, is what every itinerary load after the first
/// returns, so a test can hold a reload open; [tripAfter] is likewise what
/// every trip read after the first returns.
///
/// [inSitting] pumps the tab as the unlocked trip page shows it, under its
/// slots with a sitting open on [trip] holding [days], and answers that
/// sitting; otherwise the tab only reads, and the answer is null.
Future<_Sitting?> _pumpTab(
  WidgetTester tester, {
  required Trip? trip,
  required List<ItineraryDay> days,
  Future<List<ItineraryDay>>? reload,
  Trip? tripAfter,
  Object? loadError,
  List<Dive> dives = const [],
  List<Object> extra = const [],
  TripStory? story,
  Map<int, TripDayWeather>? tripDayWeather,
  Size viewSize = const Size(800, 2000),
  bool inSitting = false,
}) async {
  _Sitting? sitting;
  if (inSitting) {
    final store = FakeItineraryDays(days);
    final session = EditSession<Trip>(trip!);
    addTearDown(session.dispose);
    await tripItineraryDays(store).load(session);
    sitting = (session: session, store: store);
  }
  var loads = 0;
  var tripReads = 0;
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides(tripDayWeather: tripDayWeather);
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
        divesForTripProvider('trip-1').overrideWith((ref) async => dives),
        // The tab reads the story only for photos and sightings; build one
        // from the same rows so it agrees with the itinerary and dives.
        tripStoryProvider('trip-1').overrideWith((ref) async {
          if (story != null) return story;
          if (trip == null) throw StateError('Trip not found: trip-1');
          return buildTripStory(
            trip: trip,
            dives: dives,
            itineraryDays: days,
            mediaByDiveId: const {},
            sightingsByDiveId: const {},
            checklistItems: const [],
            today: clock.now(),
          );
        }),
        if (sitting != null)
          itineraryDayRepositoryProvider.overrideWithValue(sitting.store),
        ...extra,
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: sitting == null
              ? const TripItineraryTab(tripId: 'trip-1')
              : TripCardSlotsScope(
                  slots: _slots(trip!, sitting.session),
                  child: const TripItineraryTab(tripId: 'trip-1'),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sitting;
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
    await _pumpTab(
      tester,
      trip: _trip(DateTime(2026, 3, 6)),
      days: staleRows,
      inSitting: true,
    );

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

    // What a Save of the sitting, or a sync, does.
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

  testWidgets('with no sitting it offers no Generate and a tapped day opens '
      'no sheet', (tester) async {
    // Some dates have no row, so a sitting would offer Fill in missing days.
    await _pumpTab(tester, trip: _resortTrip(), days: staleRows);
    expect(find.byKey(const Key('trip-itinerary-generate')), findsNothing);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('an empty itinerary explains itself and offers Generate', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: const [],
      inSitting: true,
    );
    expect(
      find.text('No itinerary yet. Generate one from the trip dates.'),
      findsOneWidget,
    );
    expect(find.text('Generate itinerary'), findsOneWidget);
    expect(find.text('No dives'), findsNothing);
  });

  testWidgets('a partial itinerary offers Fill in missing days above the '
      'list', (tester) async {
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      inSitting: true,
    );
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
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      inSitting: true,
    );
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
    await _pumpTab(
      tester,
      trip: _trip(DateTime(2026, 3, 6)),
      days: staleRows,
      inSitting: true,
    );
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
    final sitting = await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: [sea],
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    // The dropdown shows the stored value even though a resort trip does
    // not offer it.
    expect(find.text('Sea Day'), findsWidgets);
    // A note, so the sheet hands back a changed day for Save to write.
    await tester.enterText(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(EditableText),
          )
          .at(1),
      'Crossing',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await _savedDays(sitting!)).single;
    expect(saved.notes, 'Crossing');
    expect(saved.dayType, DayType.seaDay);
  });

  testWidgets(
    'the sheet saves planned dives, and a dive day at 0 keeps its type',
    (tester) async {
      final sitting = await _pumpTab(
        tester,
        trip: _resortTrip(),
        days: staleRows,
        inSitting: true,
      );
      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('itinerary-planned-dives')),
        '0',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await _savedDays(sitting!)).single;
      expect(saved.plannedDives, 0);
      // The spec: saving as Dive day with 0 keeps the type; the story still
      // reads it as a planned rest day (TripStoryDay.isPlannedRest).
      expect(saved.dayType, DayType.diveDay);
    },
  );

  testWidgets('saving a day as Rest plans it at none', (tester) async {
    final sitting = await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await _savedDays(sitting!)).single;
    expect(saved.dayType, DayType.rest);
    expect(saved.plannedDives, 0);
  });

  testWidgets('a non-number in planned dives is refused in place', (
    tester,
  ) async {
    final sitting = await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      inSitting: true,
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
    // The sheet stays open, and the sitting holds no change.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(sitting!.session.changedCardIds, isEmpty);
  });

  testWidgets('planned dives above the board cap are refused in place', (
    tester,
  ) async {
    final sitting = await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      '${kMaxPlannedDivesPerDay + 1}',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Plan at most $kMaxPlannedDivesPerDay dives a day.'),
      findsOneWidget,
    );
    // The sheet stays open, and the sitting holds no change.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(sitting!.session.changedCardIds, isEmpty);
  });

  testWidgets('planned dives at the board cap save', (tester) async {
    final sitting = await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('itinerary-planned-dives')),
      '$kMaxPlannedDivesPerDay',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_heldDay(sitting!, 'a').plannedDives, kMaxPlannedDivesPerDay);
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
    final sitting = await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: [rest],
      inSitting: true,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DayType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dive Day').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await _savedDays(sitting!)).single;
    expect(saved.dayType, DayType.diveDay);
    expect(saved.plannedDives, isNull);
  });

  testWidgets('a past day reports its plan as progress', (tester) async {
    final past = _row('p', DateTime(2026, 3, 7), 2).copyWith(plannedDives: 3);
    final ahead = _row('a', DateTime(2026, 3, 9), 4).copyWith(plannedDives: 2);
    await withClock(Clock.fixed(DateTime(2026, 3, 8, 10)), () async {
      await _pumpTab(tester, trip: _resortTrip(), days: [past, ahead]);
      // The trip is under way, so the tab opens at the next day; the past
      // day is above it.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
    });
    expect(find.text('3 dives planned'), findsNothing);
    expect(find.text('0 of 3 planned dives'), findsOneWidget);
    expect(find.text('2 dives planned'), findsOneWidget);
  });

  testWidgets('on a Rest day the planned dives field reads 0 and is locked', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      trip: _resortTrip(),
      days: staleRows,
      inSitting: true,
    );
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

  // #2875: a dive logged on a day typed Rest makes it a dive day after all,
  // the way the trip story reads a day planned at none.
  group('a Rest day with a logged dive', () {
    final rest = _row(
      'r',
      DateTime(2026, 3, 8),
      3,
    ).copyWith(dayType: DayType.rest, plannedDives: 0);

    testWidgets('reads as a Dive Day beside its dives', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [rest],
          dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        );
      });
      expect(find.text('Dive Day'), findsOneWidget);
      expect(find.text('Rest'), findsNothing);
      expect(find.byIcon(Icons.scuba_diving), findsOneWidget);
      expect(find.text('1 dive'), findsOneWidget);
    });

    testWidgets('keeps its stored type in the edit sheet', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [rest],
          dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
          inSitting: true,
        );
      });
      await tester.tap(find.text('Day 3'));
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButtonFormField<DayType>>(
        find.byType(DropdownButtonFormField<DayType>),
      );
      expect(dropdown.initialValue, DayType.rest);
    });

    testWidgets('without a dive still reads Rest', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10, 10)), () async {
        await _pumpTab(tester, trip: _resortTrip(), days: [rest]);
      });
      expect(find.text('Rest'), findsOneWidget);
      expect(find.text('Dive Day'), findsNothing);
      expect(find.byIcon(Icons.beach_access), findsOneWidget);
    });
  });

  group('richer day cards', () {
    final day = _row('r', DateTime(2026, 3, 8), 3);
    Dive dive(String id, int hour, {double? temp, int minutes = 50}) => Dive(
      id: id,
      diveNumber: hour,
      dateTime: DateTime(2026, 3, 8, hour),
      runtime: Duration(minutes: minutes),
      maxDepth: 18 + hour.toDouble(),
      waterTemp: temp,
      airTemp: 29,
    );
    MediaItem photo(String id) => MediaItem(
      id: id,
      mediaType: MediaType.photo,
      takenAt: DateTime(2026, 3, 8, 10),
      createdAt: DateTime(2026, 3, 8, 10),
      updatedAt: DateTime(2026, 3, 8, 10),
    );
    Sighting sighting(String id, String speciesId) => Sighting(
      id: id,
      diveId: 'a',
      speciesId: speciesId,
      speciesName: speciesId,
    );

    testWidgets('totals, conditions, weather and richer rows', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [day],
          dives: [dive('a', 9, temp: 26), dive('b', 14, temp: 28)],
        );
      });
      expect(find.textContaining('2 dives · 1h 40m · 32.0m'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('day-conditions-line'))).data,
        'Water 26°C to 28°C',
      );
      expect(find.text('29°C'), findsOneWidget);
      expect(find.text('09:00 · 50m · 27.0m · 26°C'), findsOneWidget);
      expect(find.text('14:00 · 50m · 32.0m · 28°C'), findsOneWidget);
    });

    testWidgets('stored weather fills in when no dive logged any', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [day],
          tripDayWeather: {
            tripDayMillis(day.date): TripDayWeather(
              id: 'w',
              tripId: 'trip-1',
              date: day.date,
              latitude: 12.1,
              longitude: -68.2,
              airTemp: 31,
              fetchedAt: DateTime(2026, 3, 8),
              createdAt: DateTime(2026, 3, 8),
              updatedAt: DateTime(2026, 3, 8),
            ),
          },
        );
      });
      expect(find.text('31°C'), findsOneWidget);
    });

    testWidgets('photos and species from the story', (tester) async {
      final trip = _resortTrip();
      final diveA = dive('a', 9);
      final story = buildTripStory(
        trip: trip,
        dives: [diveA],
        itineraryDays: [day],
        mediaByDiveId: {
          'a': DiveMediaPreview(
            items: [photo('m1'), photo('m2')],
            mediaCount: 2,
            photoCount: 2,
          ),
        },
        sightingsByDiveId: {
          'a': [
            sighting('s1', 'sp-1'),
            sighting('s2', 'sp-1'),
            sighting('s3', 'sp-2'),
          ],
        },
        checklistItems: const [],
        today: DateTime(2026, 3, 9),
      );
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: trip,
          days: [day],
          dives: [diveA],
          story: story,
        );
      });
      expect(find.text('2 photos · 2 species'), findsOneWidget);
    });

    testWidgets('no photos or species means no media line', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [day],
          dives: [dive('a', 9)],
        );
      });
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    });

    testWidgets('today is tinted and says Today', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 8, 10)), () async {
        await _pumpTab(tester, trip: _resortTrip(), days: [day]);
      });
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
      final card = tester.widget<Card>(find.byType(Card).first);
      final context = tester.element(find.byType(TripItineraryTab));
      final scheme = Theme.of(context).colorScheme;
      expect(
        (card.shape! as RoundedRectangleBorder).side.color,
        scheme.primary,
      );
      // An opaque fill, so it reads the same on any surface behind it.
      expect(card.color!.a, 1.0);
    });

    testWidgets('a past day compares logged with planned', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 9, 10)), () async {
        await _pumpTab(
          tester,
          trip: _resortTrip(),
          days: [day.copyWith(plannedDives: 3)],
          dives: [dive('a', 9)],
        );
      });
      expect(find.text('1 of 3 planned dives'), findsOneWidget);
    });
  });

  testWidgets('a dive is listed on the day it entered the water', (
    tester,
  ) async {
    // Logged at 23:50 on the 8th but entered the water after midnight: the
    // story puts it on the 9th, and so must the itinerary.
    final dive = Dive(
      id: 'late',
      dateTime: DateTime(2026, 3, 8, 23, 50),
      entryTime: DateTime(2026, 3, 9, 0, 10),
    );
    await withClock(Clock.fixed(DateTime(2026, 4, 1)), () async {
      await _pumpTab(
        tester,
        trip: _resortTrip(),
        days: [_row('n', DateTime(2026, 3, 9), 4)],
        dives: [dive],
      );
    });
    expect(find.textContaining('1 dive'), findsOneWidget);
  });
}
