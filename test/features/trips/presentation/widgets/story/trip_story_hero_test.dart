import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

Trip _trip({required DateTime start, required DateTime end}) {
  return Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: start,
    endDate: end,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TripChecklistItem _check(String id, {bool done = false}) {
  return TripChecklistItem(
    id: id,
    tripId: 'trip-1',
    title: id,
    isDone: done,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TripStory _story(Trip trip, {List<TripChecklistItem> checklist = const []}) {
  return buildTripStory(
    trip: trip,
    dives: [],
    itineraryDays: [],
    mediaByDiveId: {},
    sightingsByDiveId: {},
    checklistItems: checklist,
    today: DateTime.now(),
  );
}

Future<void> pumpHero(
  WidgetTester tester,
  TripStory story, {
  VoidCallback? onScan,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
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
  testWidgets('planned trip shows countdown, checklist, generate itinerary', (
    tester,
  ) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(
      start: today.add(const Duration(days: 40)),
      end: today.add(const Duration(days: 47)),
    );
    final story = _story(
      trip,
      checklist: [_check('a', done: true), _check('b')],
    );
    await pumpHero(tester, story);

    expect(find.textContaining('until departure'), findsOneWidget);
    expect(find.text('1 of 2 done'), findsOneWidget);
    expect(find.text('Generate itinerary'), findsOneWidget);
  });

  testWidgets('in-progress trip shows day-of-trip line', (tester) async {
    final today = _dayOnly(DateTime.now());
    final trip = _trip(
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 2)),
    );
    final story = _story(trip);
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
}
