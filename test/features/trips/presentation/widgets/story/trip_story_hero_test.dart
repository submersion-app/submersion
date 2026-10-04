import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// [days] calendar days from [day], which is not the same as adding a
/// `Duration`. A `Duration` is elapsed time, so a window that crosses a
/// daylight-saving change lands an hour short and loses a whole calendar day:
/// from 2026-09-20, `add(Duration(days: 43))` gives 2026-11-01 23:00, not
/// 2026-11-02, and a four-day trip becomes a three-day one.
///
/// The difference only shows in a zone that observes the transition, so this
/// file is listed in the Timezone Tests CI job; the runners are UTC, where
/// reverting this helper would change nothing and pass.
DateTime _daysFrom(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

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
  List<ItineraryDay> itinerary = const [],
}) {
  return buildTripStory(
    trip: trip,
    dives: [],
    itineraryDays: itinerary,
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
  bool showEmptyState = true,
  bool showChecklist = true,
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
            child: TripStoryHero(
              story: story,
              onScanForDives: onScan,
              showEmptyState: showEmptyState,
              showChecklist: showChecklist,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('showEmptyState false keeps the countdown and drops the '
      'empty state', (tester) async {
    final now = DateTime.now();
    final trip = _trip(start: _daysFrom(now, 12), end: _daysFrom(now, 19));
    await pumpHero(tester, _story(trip), showEmptyState: false);
    expect(find.text('12 days until departure'), findsOneWidget);
    expect(find.text('No dives or itinerary yet'), findsNothing);
  });

  testWidgets('planned liveaboard shows countdown and checklist', (
    tester,
  ) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(
      start: _daysFrom(today, 40),
      end: _daysFrom(today, 47),
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
  });

  testWidgets('showChecklist false keeps the countdown and drops the '
      'checklist card (#2881)', (tester) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(start: _daysFrom(today, 40), end: _daysFrom(today, 47));
    final story = _story(
      trip,
      checklist: [_check('a', done: true), _check('Service regulator')],
    );
    await pumpHero(tester, story, showChecklist: false);

    expect(find.textContaining('until departure'), findsOneWidget);
    expect(find.text('1 of 2 done'), findsNothing);
    expect(find.text('Service regulator'), findsNothing);
  });

  testWidgets('the hero never offers itinerary generation', (tester) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(
      start: _daysFrom(today, 12),
      end: _daysFrom(today, 19),
      tripType: TripType.liveaboard,
    );
    await pumpHero(tester, _story(trip));
    expect(find.text('Generate itinerary'), findsNothing);
  });

  testWidgets('in-progress trip shows day-of-trip line', (tester) async {
    // Capture now once so the trip range and injected story `today` can't
    // straddle midnight and shift the day-of-trip count.
    final now = DateTime.now();
    final today = _dayOnly(now);
    final trip = _trip(start: _daysFrom(today, -1), end: _daysFrom(today, 2));
    final story = _story(trip, today: now);
    await pumpHero(tester, story);

    expect(find.text('Day 2 of 4'), findsOneWidget);
  });

  testWidgets('empty past trip shows empty state and fires scan callback', (
    tester,
  ) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(start: _daysFrom(today, -10), end: _daysFrom(today, -7));
    final story = _story(trip);
    var scanned = false;
    await pumpHero(tester, story, onScan: () => scanned = true);

    expect(find.text('No dives or itinerary yet'), findsOneWidget);
    await tester.tap(find.text('Find matching dives'));
    expect(scanned, isTrue);
  });
}
