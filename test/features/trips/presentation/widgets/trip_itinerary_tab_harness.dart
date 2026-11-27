/// The trip itinerary tab's shared harness: trip and day fixtures, and
/// [pumpTab], which shows the tab read only or in an open sitting.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
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

Trip trip(DateTime start) => Trip(
  id: 'trip-1',
  name: 'Red Sea',
  startDate: start,
  endDate: DateTime(2026, 3, 10),
  tripType: TripType.liveaboard,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ItineraryDay row(String id, DateTime date, int storedNumber) => ItineraryDay(
  id: id,
  tripId: 'trip-1',
  dayNumber: storedNumber,
  date: date,
  dayType: DayType.diveDay,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Trip resortTrip() => Trip(
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
typedef Sitting = ({EditSession<Trip> session, FakeItineraryDays store});

/// The trip page's slots for an open sitting on [trip], with no frames.
TripCardSlots slots(Trip trip, EditSession<Trip> session) => TripCardSlots(
  shown: trip,
  layout: trip,
  session: session,
  frame: (_, child) => child,
  dayPlanFrame: (_, child) => child,
  showsWhileEmpty: (_) => false,
  openCard: (_) {},
  unlockAt: (_) => session,
  isOpen: (_) => false,
);

/// The day [id] as [sitting] holds it.
ItineraryDay heldDay(Sitting sitting, String id) => tripItineraryDays(
  sitting.store,
).current(sitting.session)!.singleWhere((d) => d.id == id);

/// What Save writes for the days the sheet changed.
Future<List<ItineraryDay>> savedDays(Sitting sitting) async {
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
Future<Sitting?> pumpTab(
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
  Sitting? sitting;
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
                  slots: slots(trip!, sitting.session),
                  child: const TripItineraryTab(tripId: 'trip-1'),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sitting;
}
