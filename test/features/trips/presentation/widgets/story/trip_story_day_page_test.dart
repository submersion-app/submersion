import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/pages/trip_day_map_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_sections.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_head.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_plan.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_under_way_cards.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

MediaItem _media(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  takenAt: DateTime(2026, 3, 8, 10),
  createdAt: DateTime(2026, 3, 8, 10),
  updatedAt: DateTime(2026, 3, 8, 10),
);

Sighting _sighting(
  String id,
  String species, {
  SightingAbundance abundance = SightingAbundance.seen,
  int count = 1,
  String? speciesId,
}) => Sighting(
  id: id,
  diveId: 'd1',
  speciesId: speciesId ?? 'sp-$species',
  speciesName: species,
  abundance: abundance,
  count: count,
);

ItineraryDay _itin({String? port, String notes = ''}) => ItineraryDay(
  id: 'itin-1',
  tripId: 'trip-1',
  dayNumber: 2,
  date: DateTime(2026, 3, 8),
  dayType: DayType.diveDay,
  portName: port,
  notes: notes,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

TripStoryDay _pastDay(List<String> diveIds) => TripStoryDay(
  date: DateTime(2026, 3, 8),
  dayNumber: 2,
  kind: TripStoryDayKind.past,
  dives: [
    for (final (i, id) in diveIds.indexed)
      createTestDiveWithBottomTime(
        id: id,
        diveNumber: i + 1,
        bottomTime: const Duration(minutes: 45),
        maxDepth: 20.0,
      ),
  ],
);

/// A dive pin at its own site, kilometres from the others, so each dive
/// keeps its own pin rather than sharing a badge.
TripStoryMapPoint _pin(String diveId, int number) => TripStoryMapPoint(
  latitude: 12.1,
  longitude: -68.2 + number * 0.05,
  dayIndex: 1,
  label: 'Site $number',
  siteId: 'site-$number',
  diveId: diveId,
  diveNumber: number,
);

Trip _trip({DateTime? start, DateTime? end}) => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: start ?? DateTime(2026, 3, 7),
  endDate: end ?? DateTime(2026, 3, 9),
  tripType: TripType.resort,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// A story holding [day], with plain earlier days before it so that the
/// trip's day count is at least the day's own number.
TripStory _storyFor(TripStoryDay day, {Trip? trip}) => TripStory(
  trip: trip ?? _trip(),
  days: [
    for (var n = 1; n < day.dayNumber; n++)
      TripStoryDay(
        date: DateTime(
          day.date.year,
          day.date.month,
          day.date.day - (day.dayNumber - n),
        ),
        dayNumber: n,
        kind: TripStoryDayKind.past,
      ),
    day,
  ],
  checklist: const TripStoryChecklistSummary(done: 0, total: 0, nextDue: []),
  mapGeometry: const TripStoryMapGeometry(points: []),
);

Future<void> pumpPage(
  WidgetTester tester,
  TripStoryDay day, {
  List<Override> extra = const [],
  List<TripStoryMapPoint> mapPoints = const [],
  Trip? trip,
  Size? viewSize,
}) async {
  if (viewSize != null) {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  // Dates are formatted against Intl.defaultLocale, a process global the app
  // sets from its own locale. Pin it and put it back.
  final previousLocale = Intl.defaultLocale;
  Intl.defaultLocale = 'en';
  addTearDown(() => Intl.defaultLocale = previousLocale);

  final overrides = await getBaseOverrides();
  final story = _storyFor(day, trip: trip);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TripStoryDayPage(story: story, day: day, mapPoints: mapPoints),
        ),
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (_, state) =>
            Scaffold(body: Text('dive ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/trips/:id/gallery',
        builder: (_, state) =>
            Scaffold(body: Text('gallery ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides, ...extra].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  group('what a day shows, and in what order', () {
    testWidgets('a dive day runs head, map, timeline, dives, photos, '
        'species', (tester) async {
      final base = _pastDay(['d1', 'd2', 'd3']);
      final day = TripStoryDay(
        date: base.date,
        dayNumber: base.dayNumber,
        kind: base.kind,
        dives: base.dives,
        media: [_media('m1')],
        mediaCount: 1,
        sightings: [_sighting('s1', 'Turtle')],
      );
      await pumpPage(
        tester,
        day,
        mapPoints: [_pin('d1', 1), _pin('d2', 2)],
        viewSize: const Size(420, 2000),
      );

      final ys = [
        _top(tester, find.byType(TripStoryDayHead)),
        _top(tester, find.byType(FlutterMap)),
        _top(tester, find.byType(DayRhythmBar)),
        _top(tester, find.byType(DiveListItem)),
        _top(tester, find.byType(TripDayPhotoStrip)),
        _top(tester, find.byType(TripDaySightingChips)),
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.byType(DiveListItem), findsNWidgets(3));
    });

    testWidgets('the head says which day it is', (tester) async {
      await pumpPage(tester, _pastDay(['d1']));

      expect(find.textContaining('Day 2 of 2'), findsOneWidget);
      expect(find.text('Sun, Mar 8'), findsOneWidget);
    });

    testWidgets('no card wraps the day', (tester) async {
      await pumpPage(tester, _pastDay(['d1', 'd2']));

      expect(
        find.ancestor(
          of: find.byType(DiveListItem),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
    });

    testWidgets('the dive cards line up with the map and the head', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _pastDay(['d1', 'd2']),
        mapPoints: [_pin('d1', 1), _pin('d2', 2)],
        viewSize: const Size(420, 1400),
      );

      final map = tester.getRect(find.byType(FlutterMap));
      // The card's own Material: the tile around it may add no inset.
      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(DiveListItem).first,
              matching: find.byType(Card),
            )
            .first,
      );
      expect(card.left, closeTo(map.left, 0.5));
      expect(card.right, closeTo(map.right, 0.5));
    });

    testWidgets('the timeline has no tinted box', (tester) async {
      await pumpPage(tester, _pastDay(['d1']));

      expect(find.byType(DayRhythmBar), findsOneWidget);
      expect(find.byKey(const Key('day-summary-band')), findsNothing);
      final context = tester.element(find.byType(DayRhythmBar));
      final tint = Theme.of(context).colorScheme.surfaceContainerLow;
      final tinted = find.ancestor(
        of: find.byType(DayRhythmBar),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == tint,
        ),
      );
      expect(tinted, findsNothing);
    });

    testWidgets('a surface day shows its head and one quiet line', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 9),
        dayNumber: 3,
        kind: TripStoryDayKind.past,
      );
      await pumpPage(tester, day);

      expect(find.textContaining('Surface day'), findsOneWidget);
      expect(find.byKey(TripStoryDayPage.noDivesKey), findsOneWidget);
      expect(find.text('No dives this day'), findsOneWidget);
      expect(find.byType(DiveListItem), findsNothing);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byType(DayRhythmBar), findsNothing);
    });

    testWidgets('a day with photos and no dives says so before the photos, '
        'where its dives would be', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 9),
        dayNumber: 3,
        kind: TripStoryDayKind.past,
        media: [_media('m1')],
        mediaCount: 1,
        sightings: [_sighting('s1', 'Turtle')],
      );
      await pumpPage(tester, day, viewSize: const Size(420, 1400));

      final ys = [
        _top(tester, find.byKey(TripStoryDayPage.noDivesKey)),
        _top(tester, find.text('Photos')),
        _top(tester, find.text('Species seen')),
      ];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('a day ahead with nothing planned says so too', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2027, 1, 10),
        dayNumber: 1,
        kind: TripStoryDayKind.future,
      );
      await pumpPage(tester, day);

      expect(find.text('Planned'), findsOneWidget);
      expect(find.byKey(TripStoryDayPage.noDivesKey), findsOneWidget);
    });

    testWidgets('a blank port is not a plan', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2027, 1, 10),
        dayNumber: 1,
        kind: TripStoryDayKind.future,
        itineraryDay: _itin(port: '   ', notes: '  '),
      );
      await pumpPage(tester, day);

      expect(find.byType(TripStoryDayPlan), findsNothing);
      expect(find.byKey(TripStoryDayPage.noDivesKey), findsOneWidget);
    });

    testWidgets('a day ahead shows its plan and the cards of dives planned '
        'for it', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2027, 1, 10),
        dayNumber: 1,
        kind: TripStoryDayKind.future,
        itineraryDay: _itin(notes: 'Bring a reef hook'),
        dives: [
          Dive(
            id: 'planned',
            dateTime: DateTime(2027, 1, 10, 9),
            maxDepth: 18,
            isPlanned: true,
          ),
        ],
      );
      await pumpPage(tester, day);

      expect(find.text('Bring a reef hook'), findsOneWidget);
      expect(find.byType(DiveListItem), findsOneWidget);
      expect(find.byKey(TripStoryDayPage.noDivesKey), findsNothing);
    });

    testWidgets('tapping a card opens the dive', (tester) async {
      await pumpPage(tester, _pastDay(['d1']));

      await tester.tap(find.byType(DiveListItem));
      await tester.pumpAndSettle();

      expect(find.text('dive d1'), findsOneWidget);
    });
  });

  group('the cards for a trip under way', () {
    final now = DateTime.now();
    DateTime at(int offset) => DateTime(now.year, now.month, now.day + offset);
    final underWay = _trip(start: at(-1), end: at(1));
    final cylinders = [
      tripCylinderStatesProvider('trip-1').overrideWith(
        (ref) async => [
          foldCylinderState(
            cylinder: TripCylinder(
              id: 'c1',
              tripId: 'trip-1',
              label: 'Truck 1',
              createdAt: now,
              updatedAt: now,
            ),
            events: const [],
            uses: const [],
          ),
        ],
      ),
      tripFillForecastProvider('trip-1').overrideWith((ref) async => null),
    ];
    const summary = Key('trip-cylinders-summary');

    testWidgets('today leads with them, above its head', (tester) async {
      final today = TripStoryDay(
        date: at(0),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
      );
      await pumpPage(tester, today, trip: underWay, extra: cylinders);

      expect(find.byType(TripUnderWayCards), findsOneWidget);
      expect(find.byKey(summary), findsOneWidget);
      expect(
        _top(tester, find.byKey(summary)),
        lessThan(_top(tester, find.byType(TripStoryDayHead))),
      );
    });

    testWidgets('another day of the same trip does not have them', (
      tester,
    ) async {
      final yesterday = TripStoryDay(
        date: at(-1),
        dayNumber: 1,
        kind: TripStoryDayKind.past,
      );
      await pumpPage(tester, yesterday, trip: underWay, extra: cylinders);

      expect(find.byType(TripUnderWayCards), findsNothing);
      expect(find.byKey(summary), findsNothing);
    });

    testWidgets('a story that reaches today on a trip that has ended does '
        'not have them', (tester) async {
      final today = TripStoryDay(
        date: at(0),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
      );
      await pumpPage(
        tester,
        today,
        trip: _trip(start: at(-9), end: at(-2)),
        extra: cylinders,
      );

      expect(find.byType(TripUnderWayCards), findsNothing);
    });
  });

  group('photos and species', () {
    testWidgets('photo strip carries a Photos caption', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        media: [_media('m1')],
      );
      await pumpPage(tester, day);

      expect(find.text('Photos'), findsOneWidget);
    });

    testWidgets('sighting chips carry a Species seen caption', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        sightings: [_sighting('s1', 'Turtle')],
      );
      await pumpPage(tester, day);

      expect(find.text('Species seen'), findsOneWidget);
    });

    testWidgets('no captions render for a day without photos or sightings', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
      );
      await pumpPage(tester, day);

      expect(find.text('Photos'), findsNothing);
      expect(find.text('Species seen'), findsNothing);
    });

    testWidgets('a past day renders its photo strip with a more-indicator', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: _itin(port: 'Kralendijk'),
        dives: [
          Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9), maxDepth: 20),
        ],
        media: [for (var i = 0; i < 6; i++) _media('m$i')],
        mediaCount: 8,
      );
      await pumpPage(tester, day, viewSize: const Size(800, 1400));

      // 8 photos, max 6 shown, so a "+2" more indicator appears.
      expect(find.text('+2'), findsOneWidget);
      // The port is in the day's head.
      expect(find.textContaining('Kralendijk'), findsOneWidget);
      // Every tappable thumbnail (6 photos + the "+2" tile) is a labeled
      // button for screen readers, not an unlabeled image / bare "+2".
      final galleryButtons = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Open trip photos',
      );
      expect(galleryButtons, findsNWidgets(7));
    });

    testWidgets('a photo opens the trip\'s gallery, and so does the tile '
        'counting the rest', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9), maxDepth: 20),
        ],
        media: [_media('m0'), _media('m1')],
        mediaCount: 5,
      );
      await pumpPage(tester, day, viewSize: const Size(420, 1400));
      final tripId = _storyFor(day).trip.id;
      final photos = find.descendant(
        of: find.byType(TripDayPhotoStrip),
        matching: find.byType(GestureDetector),
      );

      await tester.tap(photos.first);
      await tester.pumpAndSettle();
      expect(find.text('gallery $tripId'), findsOneWidget);

      tester.element(find.text('gallery $tripId')).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('+3'));
      await tester.pumpAndSettle();
      expect(find.text('gallery $tripId'), findsOneWidget);
    });

    testWidgets('a past day merges duplicate species into one badge', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        sightings: [
          _sighting('s1', 'Reef shark', abundance: SightingAbundance.exact),
          _sighting('s2', 'Reef shark', abundance: SightingAbundance.exact),
          _sighting('s3', 'Turtle'),
        ],
      );
      await pumpPage(tester, day);

      // Two exact "Reef shark" counts of one merge into a single "x2" chip;
      // a turtle only Seen shows its name alone.
      expect(find.text('Reef shark x2'), findsOneWidget);
      expect(find.text('Turtle'), findsOneWidget);
    });

    testWidgets('a past day shows the larger REEF group across dives', (
      tester,
    ) async {
      // Issue #4337: an exact 3 and "Many" have no total; the day shows the
      // larger group, and a Seen sighting gives way to a count.
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        sightings: [
          _sighting('s1', 'Jack', abundance: SightingAbundance.exact, count: 3),
          _sighting('s2', 'Jack', abundance: SightingAbundance.many),
          _sighting('s3', 'Ray'),
          _sighting('s4', 'Ray', abundance: SightingAbundance.exact, count: 4),
        ],
      );
      await pumpPage(tester, day);

      expect(find.text('Jack Many'), findsOneWidget);
      expect(find.text('Ray x4'), findsOneWidget);
    });

    testWidgets('distinct species sharing a common name are not merged', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        sightings: [
          _sighting('s1', 'Goby', speciesId: 'sp-a'),
          _sighting('s2', 'Goby', speciesId: 'sp-b'),
        ],
      );
      await pumpPage(tester, day);

      // Same display name but different speciesId: two chips, no "x2".
      expect(find.text('Goby'), findsNWidgets(2));
      expect(find.text('Goby x2'), findsNothing);
    });
  });

  group('the day map', () {
    testWidgets('a day with map points shows its map above the timeline', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _pastDay(['d1', 'd2']),
        mapPoints: [_pin('d1', 1), _pin('d2', 2)],
        viewSize: const Size(420, 1400),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      final map = tester.getRect(find.byType(FlutterMap));
      final bar = tester.getRect(find.byType(DayRhythmBar));
      expect(map.height, 180);
      expect(map.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('a day with no map points shows no map', (tester) async {
      await pumpPage(tester, _pastDay(['d1']));

      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('tapping a pin highlights its card, tapping again clears it', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _pastDay(['d1', 'd2']),
        mapPoints: [_pin('d1', 1), _pin('d2', 2)],
        viewSize: const Size(420, 1400),
      );
      bool highlighted(String id) => tester
          .widgetList<DiveListItem>(find.byType(DiveListItem))
          .firstWhere((w) => w.summary.id == id)
          .isHighlighted;

      expect(highlighted('d1'), isFalse);
      await tester.tap(find.byKey(const Key('day-map-pin-d2')));
      await tester.pumpAndSettle();
      expect(highlighted('d2'), isTrue);
      expect(highlighted('d1'), isFalse);
      await tester.tap(find.byKey(const Key('day-map-pin-d1')));
      await tester.pumpAndSettle();
      expect(highlighted('d1'), isTrue);
      expect(highlighted('d2'), isFalse);
      await tester.tap(find.byKey(const Key('day-map-pin-d1')));
      await tester.pumpAndSettle();
      expect(highlighted('d1'), isFalse);
    });

    testWidgets('opening the card a pin lit up puts its light out', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _pastDay(['d1', 'd2']),
        mapPoints: [_pin('d1', 1), _pin('d2', 2)],
        viewSize: const Size(420, 1400),
      );
      bool highlighted(String id) => tester
          .widgetList<DiveListItem>(find.byType(DiveListItem))
          .firstWhere((w) => w.summary.id == id)
          .isHighlighted;
      await tester.tap(find.byKey(const Key('day-map-pin-d2')));
      await tester.pumpAndSettle();
      expect(highlighted('d2'), isTrue);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DiveListItem && w.summary.id == 'd2',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('dive d2'), findsOneWidget);

      // Back on the day, the card is as it was before the pin was tapped.
      tester.element(find.text('dive d2')).pop();
      await tester.pumpAndSettle();
      expect(highlighted('d2'), isFalse);
    });

    testWidgets('the expand button opens the day map fullscreen', (
      tester,
    ) async {
      await pumpPage(tester, _pastDay(['d1']), mapPoints: [_pin('d1', 1)]);

      await tester.tap(find.byKey(const Key('day-map-expand')));
      await tester.pumpAndSettle();

      final page = tester.widget<TripDayMapPage>(find.byType(TripDayMapPage));
      expect(page.day.dayNumber, 2);
      expect(page.points.single.diveId, 'd1');
    });

    testWidgets('a pin scrolls only when its card is off screen', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _pastDay(['d1', 'd2', 'd3', 'd4']),
        mapPoints: [_pin('d1', 1), _pin('d4', 4)],
        viewSize: const Size(420, 620),
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, 0);
      final card1 = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is DiveListItem && w.summary.id == 'd1',
        ),
      );
      expect(
        card1.bottom,
        lessThanOrEqualTo(620),
        reason: 'card 1 starts visible',
      );
      // Card 1 is in view: the map stays where it is.
      await tester.tap(find.byKey(const Key('day-map-pin-d1')));
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      // Card 4 is below the fold: the page brings it up.
      await tester.tap(find.byKey(const Key('day-map-pin-d4')));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
    });

    testWidgets('a drag on the day map scrolls the page, not the map', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _pastDay(['d1', 'd2', 'd3', 'd4']),
        mapPoints: [_pin('d1', 1)],
        viewSize: const Size(420, 560),
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera
          .center;

      await tester.drag(find.byType(FlutterMap), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0));
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center,
        camera,
      );
    });
  });

  group('on a wide pane', () {
    TripStoryDay richDay() {
      final base = _pastDay(['d1', 'd2', 'd3']);
      return TripStoryDay(
        date: base.date,
        dayNumber: base.dayNumber,
        kind: base.kind,
        dives: base.dives,
        media: [_media('m1')],
        mediaCount: 1,
        sightings: [_sighting('s1', 'Turtle')],
      );
    }

    final pins = [_pin('d1', 1), _pin('d2', 2)];

    testWidgets('at 640 wide the map sits beside the dives', (tester) async {
      await pumpPage(
        tester,
        richDay(),
        mapPoints: pins,
        viewSize: const Size(640, 1400),
      );

      expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsOneWidget);
      final map = tester.getRect(find.byType(FlutterMap));
      final card = tester.getRect(find.byType(DiveListItem).first);
      expect(card.left, greaterThan(map.right));
      expect((card.top - map.top).abs(), lessThan(40));
      expect(map.height, 230);
      // The head stays full width above both columns.
      expect(
        tester.getRect(find.byType(TripStoryDayHead)).bottom,
        lessThanOrEqualTo(map.top),
      );
    });

    testWidgets('at 640 wide a dive card is still as wide as a small phone', (
      tester,
    ) async {
      // 640 is the detail pane of the default desktop window. Split evenly, a
      // card there is narrower than any phone it was designed for, and site
      // names break mid-word.
      await pumpPage(
        tester,
        richDay(),
        mapPoints: pins,
        viewSize: const Size(640, 1400),
      );

      final card = tester.getRect(find.byType(DiveListItem).first);
      expect(card.width, greaterThanOrEqualTo(320));
      // And the map keeps a usable width beside it.
      expect(
        tester.getSize(find.byType(FlutterMap)).width,
        greaterThanOrEqualTo(240),
      );
    });

    testWidgets('photos and species sit under the map, not under the dives', (
      tester,
    ) async {
      await pumpPage(
        tester,
        richDay(),
        mapPoints: pins,
        viewSize: const Size(640, 1400),
      );

      final map = tester.getRect(find.byType(FlutterMap));
      final card = tester.getRect(find.byType(DiveListItem).first);
      for (final finder in [
        find.byType(DayRhythmBar),
        find.byType(TripDayPhotoStrip),
        find.byType(TripDaySightingChips),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(map.bottom));
        expect(rect.left, lessThan(card.left));
      }
    });

    testWidgets('at 599 wide it is one column', (tester) async {
      await pumpPage(
        tester,
        richDay(),
        mapPoints: pins,
        viewSize: const Size(599, 1400),
      );

      expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsNothing);
      expect(tester.getSize(find.byType(FlutterMap)).height, 180);
    });

    testWidgets('narrowing the pane to one column moves the map, it does '
        'not build it again', (tester) async {
      await pumpPage(
        tester,
        richDay(),
        mapPoints: pins,
        viewSize: const Size(640, 1400),
      );
      expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsOneWidget);
      final before = tester.state(find.byType(FlutterMap));

      tester.view.physicalSize = const Size(599, 1400);
      await tester.pump();

      expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsNothing);
      // The same state: its tiles and its camera came with it.
      expect(tester.state(find.byType(FlutterMap)), same(before));
      expect(tester.getSize(find.byType(FlutterMap)).height, 180);
    });

    testWidgets('a day with no map points is one column at any width', (
      tester,
    ) async {
      await pumpPage(tester, richDay(), viewSize: const Size(900, 1400));

      expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsNothing);
    });

    testWidgets('a mapped day with no dives is one column', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: _itin(notes: 'Harbour day'),
      );
      await pumpPage(
        tester,
        day,
        mapPoints: [_pin('none', 1)],
        viewSize: const Size(900, 1400),
      );

      expect(find.byKey(TripStoryDayPage.twoColumnsKey), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('a pin brings back a card scrolled off the top', (
      tester,
    ) async {
      // Short enough that the page scrolls.
      await pumpPage(
        tester,
        richDay(),
        mapPoints: pins,
        viewSize: const Size(640, 420),
      );
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final card1 = find.byWidgetPredicate(
        (w) => w is DiveListItem && w.summary.id == 'd1',
      );
      final viewTop = tester.getRect(scrollable).top;
      // Beside the map, the first card starts level with it. Scroll until the
      // card's top is 40 above the page, with the map's middle row of pins
      // still on screen.
      final offset = tester.getRect(card1).top - viewTop + 40;
      expect(position.maxScrollExtent, greaterThanOrEqualTo(offset));
      position.jumpTo(offset);
      await tester.pump();
      expect(position.pixels, offset, reason: 'the page really scrolled');
      expect(tester.getRect(card1).top, lessThan(viewTop));
      final pin = find.byKey(const Key('day-map-pin-d1'));
      expect(pin.hitTestable(), findsOneWidget);

      await tester.tap(pin);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(card1).top,
        greaterThanOrEqualTo(viewTop - 0.5),
        reason: 'the lit card is back in view, its top at the top',
      );
    });

    testWidgets('a pin tap lights a card that is already in view', (
      tester,
    ) async {
      await pumpPage(
        tester,
        richDay(),
        mapPoints: pins,
        viewSize: const Size(640, 700),
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;

      await tester.tap(find.byKey(const Key('day-map-pin-d2')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<DiveListItem>(find.byType(DiveListItem))
            .firstWhere((w) => w.summary.id == 'd2')
            .isHighlighted,
        isTrue,
      );
      expect(position.pixels, 0);
    });
  });

  group('plan and conditions', () {
    ItineraryDay planned(int dives, {String notes = '', String? port}) =>
        _itin(notes: notes, port: port).copyWith(plannedDives: dives);

    testWidgets('a day ahead shows itinerary notes and site-history pills', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2027, 1, 10),
        dayNumber: 1,
        kind: TripStoryDayKind.future,
        itineraryDay: _itin(port: 'Manta Sandy', notes: 'Bring a reef hook'),
      );
      await pumpPage(
        tester,
        day,
        extra: [
          siteHistoryByNameProvider('Manta Sandy').overrideWith(
            (ref) async =>
                (diveCount: 6, avgWaterTemp: 27.0, avgMaxDepth: 25.0),
          ),
        ],
      );

      expect(find.text('Bring a reef hook'), findsOneWidget);
      expect(find.textContaining('6 past dives here'), findsOneWidget);
    });

    testWidgets('today with no dives shows its notes and plan', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(3, notes: 'Two-tank boat dive'),
      );
      await pumpPage(tester, day);

      expect(find.text('Two-tank boat dive'), findsOneWidget);
      expect(find.text('0 of 3 planned dives'), findsOneWidget);
    });

    testWidgets('a past day compares logged with planned, above its dives', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: planned(3, notes: 'Reef day'),
        dives: _pastDay(['d1', 'd2', 'd3', 'd4']).dives,
      );
      await pumpPage(tester, day, viewSize: const Size(420, 1600));

      expect(find.text('Reef day'), findsOneWidget);
      expect(find.text('4 of 3 planned dives'), findsOneWidget);
      expect(
        _top(tester, find.byType(TripStoryDayPlan)),
        lessThan(_top(tester, find.byType(DayRhythmBar))),
      );
    });

    testWidgets('a planned rest day shows no plan line', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(0, notes: 'Rest'),
      );
      await pumpPage(tester, day);

      expect(find.textContaining('planned dive'), findsNothing);
      expect(find.text('Rest'), findsOneWidget);
    });

    testWidgets('dives with conditions show the conditions line', (
      tester,
    ) async {
      final base = _pastDay(['d1']);
      final day = TripStoryDay(
        date: base.date,
        dayNumber: base.dayNumber,
        kind: base.kind,
        dives: [base.dives.single.copyWith(waterTemp: 27)],
      );
      await pumpPage(tester, day);

      expect(find.byKey(const Key('day-conditions-line')), findsOneWidget);
    });

    testWidgets('a planned port with no history is not a plan', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2027, 1, 10),
        dayNumber: 1,
        kind: TripStoryDayKind.future,
        itineraryDay: _itin(port: 'Kralendijk'),
      );
      await pumpPage(
        tester,
        day,
        extra: [
          siteHistoryByNameProvider('Kralendijk').overrideWith(
            (ref) async =>
                (diveCount: 0, avgWaterTemp: null, avgMaxDepth: null),
          ),
        ],
      );

      expect(find.byType(TripStoryDayPlan), findsNothing);
      expect(find.byKey(TripStoryDayPage.noDivesKey), findsOneWidget);
    });

    testWidgets('a planned port with history still shows its pills', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2027, 1, 10),
        dayNumber: 1,
        kind: TripStoryDayKind.future,
        itineraryDay: _itin(port: 'Kralendijk'),
      );
      await pumpPage(
        tester,
        day,
        extra: [
          siteHistoryByNameProvider('Kralendijk').overrideWith(
            (ref) async =>
                (diveCount: 3, avgWaterTemp: null, avgMaxDepth: null),
          ),
        ],
      );

      expect(find.textContaining('3 past dives here'), findsOneWidget);
    });

    testWidgets('a port with no history adds no space to a plan', (
      tester,
    ) async {
      final noHistory = siteHistoryByNameProvider('Kralendijk').overrideWith(
        (ref) async => (diveCount: 0, avgWaterTemp: null, avgMaxDepth: null),
      );
      Future<double> planHeight(String? port) async {
        await pumpPage(
          tester,
          TripStoryDay(
            date: DateTime(2027, 1, 10),
            dayNumber: 1,
            kind: TripStoryDayKind.future,
            itineraryDay: _itin(port: port, notes: 'Bring a reef hook'),
          ),
          extra: [noHistory],
        );
        return tester.getSize(find.byType(TripStoryDayPlan)).height;
      }

      final withoutPort = await planHeight(null);
      final withPort = await planHeight('Kralendijk');
      expect(withPort, withoutPort);
    });

    testWidgets('a port plan stays while its site history reloads', (
      tester,
    ) async {
      final pending = Completer<SiteHistory>();
      var loads = 0;
      await pumpPage(
        tester,
        TripStoryDay(
          date: DateTime(2027, 1, 10),
          dayNumber: 1,
          kind: TripStoryDayKind.future,
          itineraryDay: _itin(port: 'Kralendijk'),
        ),
        extra: [
          siteHistoryByNameProvider('Kralendijk').overrideWith(
            (ref) => loads++ == 0
                ? Future.value((
                    diveCount: 3,
                    avgWaterTemp: null,
                    avgMaxDepth: null,
                  ))
                : pending.future,
          ),
        ],
      );
      expect(find.textContaining('3 past dives here'), findsOneWidget);

      // What a dive edit does: the history query runs again.
      ProviderScope.containerOf(
        tester.element(find.byType(TripStoryDayPage)),
      ).invalidate(siteHistoryByNameProvider('Kralendijk'));
      await tester.pump();

      expect(find.byType(TripStoryDayPlan), findsOneWidget);
      expect(find.textContaining('3 past dives here'), findsOneWidget);
    });
  });
}
