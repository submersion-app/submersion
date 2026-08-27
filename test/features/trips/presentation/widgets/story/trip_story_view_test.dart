import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_map_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

Dive _dive(String id, DateTime dt) => Dive(id: id, dateTime: dt);

Dive _diveAt(String id, DateTime dt, double lat, double lng) => Dive(
  id: id,
  dateTime: dt,
  maxDepth: 20,
  site: DiveSite(
    id: 'site-$id',
    name: 'Site $id',
    location: GeoPoint(lat, lng),
  ),
);

Trip _trip({
  required DateTime start,
  required DateTime end,
  TripType type = TripType.resort,
}) {
  return Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: start,
    endDate: end,
    tripType: type,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TripStory _story(
  Trip trip, {
  List<Dive> dives = const [],
  required DateTime today,
}) {
  return buildTripStory(
    trip: trip,
    dives: dives,
    itineraryDays: [],
    mediaByDiveId: {},
    sightingsByDiveId: {},
    checklistItems: [],
    today: today,
  );
}

Future<void> pumpView(
  WidgetTester tester,
  TripStory story, {
  List<Override> extra = const [],
  Size viewSize = const Size(800, 2600),
  http.Client? weatherHttpClient,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides(
    weatherHttpClient: weatherHttpClient,
  );
  final stats = TripWithStats(trip: story.trip, diveCount: 2);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TripStoryView(story: story, stats: stats),
        ),
      ),
      GoRoute(path: '/dives/:id', builder: (_, _) => const Scaffold()),
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
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('past trip renders day chapters, hero, and stat strip', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    final story = _story(
      trip,
      dives: [
        _dive('d1', DateTime(2026, 3, 27, 9)),
        _dive('d2', DateTime(2026, 3, 28, 10)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);

    expect(find.byType(TripStoryDayCard), findsNWidgets(2));
    expect(find.byType(TripStoryHero), findsOneWidget);
    expect(find.byType(TripStatStrip), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('in-progress trip shows a Today divider', (tester) async {
    // Capture now once so the trip range and the injected story `today` can't
    // straddle a midnight boundary and shift todayIndex.
    final now = DateTime.now();
    final today = _dayOnly(now);
    final trip = _trip(
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 2)),
    );
    final story = _story(trip, today: now);
    await pumpView(tester, story);

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('liveaboard trip includes the vessel section', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
      type: TripType.liveaboard,
    );
    final story = _story(trip, today: DateTime(2026, 6, 1));
    final details = LiveaboardDetails(
      id: 'lad-1',
      tripId: 'trip-1',
      vesselName: 'MV Test',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await pumpView(
      tester,
      story,
      extra: [
        liveaboardDetailsProvider(
          'trip-1',
        ).overrideWith((ref) async => details),
      ],
    );

    expect(find.byType(TripVesselSection), findsOneWidget);
  });

  testWidgets('wide layout docks the map beside the story', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    final story = _story(trip, today: DateTime(2026, 6, 1));
    await pumpView(tester, story, viewSize: const Size(1400, 900));

    expect(find.byKey(const Key('trip-story-wide-layout')), findsOneWidget);
    // Wide layout keeps the strip fixed in the side panel.
    expect(find.byType(TripStatStrip), findsOneWidget);
  });

  testWidgets('stat strip scrolls away in the narrow layout', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 6; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    expect(find.byType(TripStatStrip), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();

    // The strip is ordinary scroll content now, not pinned under the map.
    expect(find.byType(TripStatStrip), findsNothing);
  });

  testWidgets('scrolling resolves the active day and animates the map', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    // One dive/site per day over six days, so there's enough scrollable content
    // for later chapters to cross the active-day resolution threshold.
    final labels = ['a', 'b', 'c', 'd', 'e', 'f'];
    final story = buildTripStory(
      trip: trip,
      dives: [
        // Cluster the sites tightly so every marker stays within the small
        // pinned map and can be found by its Semantics label.
        for (var i = 0; i < labels.length; i++)
          _diveAt(
            labels[i],
            DateTime(2026, 3, 25 + i, 9),
            12.10 + i * 0.002,
            -68.20 + i * 0.002,
          ),
      ],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: DateTime(2026, 6, 1),
    );
    // A short viewport so day chapters scroll through the resolution threshold.
    await pumpView(tester, story, viewSize: const Size(500, 700));

    // The active marker is drawn at full opacity; inactive ones are dimmed.
    // Correlate a marker to its day via the Semantics label the map sets, and
    // read back which day the header currently treats as active.
    double markerOpacity(String label) {
      final opacity = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        ),
        matching: find.byType(Opacity),
      );
      return tester.widget<Opacity>(opacity).opacity;
    }

    int activeDayIndex() {
      for (var i = 0; i < labels.length; i++) {
        if (markerOpacity('Site ${labels[i]}') == 1.0) return i;
      }
      return -1;
    }

    // Day 0 starts active.
    expect(activeDayIndex(), 0);

    // Drag the story's vertical scroll view (targeting the CustomScrollView, not
    // a nested/map scrollable) up in steps, pumping 150ms between drags so the
    // frame-timestamp resolve throttle (100ms) lets each drag resolve a day.
    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 6; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    // Scrolling down must actually advance the active day: the highlighted
    // marker moves to a later day. (A no-op _onScroll would leave day 0 active
    // and fail here.)
    expect(activeDayIndex(), greaterThan(0));
    expect(markerOpacity('Site a'), lessThan(1.0));
  });

  testWidgets('day header sticks below the collapsed map while scrolling', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final labels = ['a', 'b', 'c', 'd', 'e', 'f'];
    final story = buildTripStory(
      trip: trip,
      dives: [
        for (var i = 0; i < labels.length; i++)
          _diveAt(
            labels[i],
            DateTime(2026, 3, 25 + i, 9),
            12.10 + i * 0.002,
            -68.20 + i * 0.002,
          ),
      ],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    // Scroll deep into the story so the map is fully collapsed and a later
    // day's chapter is under the headers.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }

    // Exactly one day header is pinned directly below the 180px map header;
    // the first day's header has been pushed out by a later one.
    final pinnedTops = [
      for (final element in find.byType(TripStoryDayHeader).evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    ];
    expect(pinnedTops, anyElement(closeTo(180.0, 1.0)));
    // The first day's header (its badge shows "Mar 25") has been pushed out.
    expect(find.textContaining('Mar 25'), findsNothing);
  });

  testWidgets('checklist and notes closers share the section title style', (
    tester,
  ) async {
    // Both end-of-story cards must read as the same family: the checklist
    // ExpansionTile's title gets the notes card's bold section-title style
    // instead of the ListTile default.
    final trip = Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 27),
      endDate: DateTime(2026, 3, 28),
      tripType: TripType.resort,
      notes: 'Great vis all week',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final story = buildTripStory(
      trip: trip,
      dives: [_dive('d1', DateTime(2026, 3, 27, 9))],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [
        TripChecklistItem(
          id: 'c1',
          tripId: 'trip-1',
          title: 'Pack fins',
          isDone: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);

    final notesStyle = tester.widget<Text>(find.text('Notes')).style;
    final checklistStyle = tester.widget<Text>(find.text('1 of 1 done')).style;
    expect(checklistStyle?.fontWeight, FontWeight.bold);
    expect(checklistStyle?.fontSize, notesStyle?.fontSize);
  });

  testWidgets('surface days get the same sticky header as dive days', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 27),
    );
    // Dives on days 1 and 3; day 2 is a surface day.
    final story = _story(
      trip,
      dives: [
        _dive('d1', DateTime(2026, 3, 25, 9)),
        _dive('d3', DateTime(2026, 3, 27, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);

    // Tall harness viewport: all three days are mounted, and every one of them
    // contributes a sticky header, surface day included.
    expect(find.byType(TripStoryDayHeader), findsNWidgets(3));
    // The surface day's header carries the same day-number badge as dive days.
    expect(
      find.descendant(
        of: find.byKey(const Key('day-number-badge')).at(1),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('Surface day'), findsOneWidget);
  });

  testWidgets('only the surface day fetches from the nearest trip point', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 27),
    );
    final story = _story(
      trip,
      dives: [
        _diveAt('d1', DateTime(2026, 3, 25, 9), 12.10, -68.20),
        _diveAt('d3', DateTime(2026, 3, 27, 9), 13.30, -69.40),
      ],
      today: DateTime(2026, 6, 1),
    );
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.queryParameters['latitude'], '12.1');
      expect(request.url.queryParameters['longitude'], '-68.2');
      expect(request.url.queryParameters['start_date'], '2026-03-26');
      expect(request.url.queryParameters['timezone'], 'auto');
      return http.Response(
        jsonEncode({
          'hourly': {
            'time': ['2026-03-26T12:00'],
            'temperature_2m': [26.0],
            'relative_humidity_2m': [70.0],
            'precipitation': [0.0],
            'cloud_cover': [10.0],
            'wind_speed_10m': [8.0],
            'wind_direction_10m': [30.0],
            'surface_pressure': [1012.0],
            'weathercode': [0],
          },
        }),
        200,
      );
    });

    await pumpView(tester, story, weatherHttpClient: client);
    await tester.pump();

    expect(calls, 1);
    expect(find.text('26°C'), findsOneWidget);
  });
}
