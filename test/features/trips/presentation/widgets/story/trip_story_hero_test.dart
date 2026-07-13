import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Records saveAll without touching the database.
class _FakeItineraryRepo extends ItineraryDayRepository {
  List<ItineraryDay>? saved;

  @override
  Future<void> saveAll(List<ItineraryDay> days) async {
    saved = days;
  }
}

DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

Trip _trip({
  required DateTime start,
  required DateTime end,
  TripType tripType = TripType.shore,
}) {
  return Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: start,
    endDate: end,
    tripType: tripType,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TripChecklistItem _check(String id, {bool done = false, DateTime? due}) {
  return TripChecklistItem(
    id: id,
    tripId: 'trip-1',
    title: id,
    isDone: done,
    dueDate: due,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TripStory _story(
  Trip trip, {
  List<TripChecklistItem> checklist = const [],
  DateTime? today,
}) {
  return buildTripStory(
    trip: trip,
    dives: [],
    itineraryDays: [],
    mediaByDiveId: {},
    sightingsByDiveId: {},
    checklistItems: checklist,
    today: today ?? DateTime.now(),
  );
}

Future<void> pumpHero(
  WidgetTester tester,
  TripStory story, {
  VoidCallback? onScan,
  List<Override> extra = const [],
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides, ...extra].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripStoryHero(story: story, onScanForDives: onScan),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('planned liveaboard shows countdown, checklist, generate CTA', (
    tester,
  ) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(
      start: today.add(const Duration(days: 40)),
      end: today.add(const Duration(days: 47)),
      tripType: TripType.liveaboard,
    );
    final story = _story(
      trip,
      checklist: [
        _check('a', done: true),
        _check('Service regulator', due: DateTime(2026, 12, 27)),
      ],
    );
    await pumpHero(tester, story);

    expect(find.textContaining('until departure'), findsOneWidget);
    expect(find.text('1 of 2 done'), findsOneWidget);
    expect(find.text('Generate itinerary'), findsOneWidget);
  });

  testWidgets('planned shore trip hides the generate itinerary CTA', (
    tester,
  ) async {
    // generateForTrip emits embark/disembark days and only the liveaboard
    // layout has an itinerary editor, so a shore trip must not expose the CTA.
    final today = _dayOnly(DateTime.now());
    final trip = _trip(
      start: today.add(const Duration(days: 40)),
      end: today.add(const Duration(days: 47)),
    );
    await pumpHero(tester, _story(trip));

    expect(find.textContaining('until departure'), findsOneWidget);
    expect(find.text('Generate itinerary'), findsNothing);
  });

  testWidgets('in-progress trip shows day-of-trip line', (tester) async {
    // Capture now once so the trip range and injected story `today` can't
    // straddle midnight and shift the day-of-trip count.
    final now = DateTime.now();
    final today = _dayOnly(now);
    final trip = _trip(
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 2)),
    );
    final story = _story(trip, today: now);
    await pumpHero(tester, story);

    expect(find.text('Day 2 of 4'), findsOneWidget);
  });

  testWidgets('empty past trip shows empty state and fires scan callback', (
    tester,
  ) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(
      start: today.subtract(const Duration(days: 10)),
      end: today.subtract(const Duration(days: 7)),
    );
    final story = _story(trip);
    var scanned = false;
    await pumpHero(tester, story, onScan: () => scanned = true);

    expect(find.text('No dives or itinerary yet'), findsOneWidget);
    await tester.tap(find.text('Find matching dives'));
    expect(scanned, isTrue);
  });

  testWidgets('tapping Generate itinerary saves generated days', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = _dayOnly(now);
    final trip = _trip(
      start: today.add(const Duration(days: 40)),
      end: today.add(const Duration(days: 43)),
      tripType: TripType.liveaboard,
    );
    final story = _story(trip, today: now);
    final fakeRepo = _FakeItineraryRepo();
    await pumpHero(
      tester,
      story,
      extra: [itineraryDayRepositoryProvider.overrideWithValue(fakeRepo)],
    );

    await tester.tap(find.text('Generate itinerary'));
    await tester.pump();
    // One generated day per calendar day of the 4-day trip.
    expect(fakeRepo.saved, isNotNull);
    expect(fakeRepo.saved!.length, 4);
  });
}
