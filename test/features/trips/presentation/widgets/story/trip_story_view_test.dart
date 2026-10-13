import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/pages/trip_day_map_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
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
  Map<int, TripDayWeather>? tripDayWeather,
  Locale locale = const Locale('en'),
  List<TripCylinderState> cylinderStates = const [],
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides(
    weatherHttpClient: weatherHttpClient,
    tripDayWeather: tripDayWeather,
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
      overrides: [
        ...overrides,
        tripCylinderStatesProvider(
          'trip-1',
        ).overrideWith((ref) async => cylinderStates),
        tripFillForecastProvider('trip-1').overrideWith((ref) async => null),
        ...extra,
      ].cast(),
      child: MaterialApp.router(
        locale: locale,
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

  group('in progress', () {
    // Today is the last-but-three day; every day up to today has a dive, so
    // each chapter has a card body and the story is long.
    TripStory longTrip({required int todayOffset}) {
      final now = DateTime.now();
      final today = _dayOnly(now);
      final trip = _trip(
        start: today.subtract(Duration(days: todayOffset)),
        // Two weeks still to come, so plenty follows today in the window.
        end: today.add(const Duration(days: 15)),
      );
      return _story(
        trip,
        today: now,
        dives: [
          for (var i = 0; i <= todayOffset; i++)
            _dive(
              'd$i',
              today
                  .subtract(Duration(days: todayOffset - i))
                  .add(const Duration(hours: 9)),
            ),
        ],
      );
    }

    testWidgets('the Documents card sits with the hero, above today', (
      tester,
    ) async {
      await pumpView(tester, longTrip(todayOffset: 0));
      final docs = find.byKey(
        const ValueKey('documents-section-trip'),
        skipOffstage: false,
      );
      final today = find.byType(TripStoryDayHeader).first;
      expect(tester.getTopLeft(docs).dy, lessThan(tester.getTopLeft(today).dy));
      expect(
        tester.getTopLeft(docs).dy,
        greaterThan(
          tester.getTopLeft(find.byType(TripStatStrip, skipOffstage: false)).dy,
        ),
      );
    });

    testWidgets('opens with today at the top', (tester) async {
      await pumpView(
        tester,
        longTrip(todayOffset: 9),
        viewSize: const Size(800, 900),
      );
      final chip = find.byKey(const Key('today-chip'));
      expect(chip, findsOneWidget);
      expect(tester.getTopLeft(chip).dy, lessThan(120));
      expect(find.byType(TripStoryHero), findsNothing);
    });

    testWidgets('earlier days and the hero are above, by scrolling up', (
      tester,
    ) async {
      await pumpView(
        tester,
        longTrip(todayOffset: 9),
        viewSize: const Size(800, 900),
      );
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 800));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(TripStoryHero), findsOneWidget);
    });

    testWidgets('today on Day 1 keeps the hero just above', (tester) async {
      await pumpView(
        tester,
        longTrip(todayOffset: 0),
        viewSize: const Size(800, 900),
      );
      final chip = find.byKey(const Key('today-chip'));
      expect(tester.getTopLeft(chip).dy, lessThan(120));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(TripStoryHero), findsOneWidget);
    });

    testWidgets('the last day fills the window with the days before it', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = _dayOnly(now);
      final trip = _trip(
        start: today.subtract(const Duration(days: 9)),
        end: today,
      );
      final story = _story(
        trip,
        today: now,
        dives: [
          for (var i = 0; i < 9; i++)
            _dive('d$i', today.subtract(Duration(days: 9 - i, hours: -9))),
        ],
      );
      await pumpView(tester, story, viewSize: const Size(800, 900));
      // Today is the last day, a header with nothing after it: it ends the
      // window instead of sitting at the top over a blank screen.
      final chip = find.byKey(const Key('today-chip'));
      expect(tester.getTopLeft(chip).dy, greaterThan(400));
      expect(find.byType(TripStoryDayHeader), findsAtLeastNWidgets(2));
    });

    testWidgets('the Today divider is gone; the header carries it', (
      tester,
    ) async {
      await pumpView(tester, longTrip(todayOffset: 1));
      expect(find.text('Today'), findsOneWidget);
    });
  });

  testWidgets('an ended trip with a dive today still opens at the hero', (
    tester,
  ) async {
    // A dive logged today stretches the story to today, but the trip itself
    // ended yesterday: it is not under way, so it opens at the top.
    final now = DateTime.now();
    final today = _dayOnly(now);
    final trip = _trip(
      start: today.subtract(const Duration(days: 20)),
      end: today.subtract(const Duration(days: 1)),
    );
    final story = _story(
      trip,
      today: now,
      dives: [
        for (var i = 0; i <= 20; i++)
          _dive('d$i', today.subtract(Duration(days: 20 - i, hours: -9))),
      ],
    );
    expect(story.todayIndex, isNotNull);
    await pumpView(tester, story, viewSize: const Size(800, 900));
    expect(find.byType(TripStoryHero), findsOneWidget);
  });

  testWidgets('a past trip still opens at the hero', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    await pumpView(tester, _story(trip, today: DateTime(2026, 5, 1)));
    expect(find.byType(TripStoryHero), findsOneWidget);
    expect(find.byKey(const Key('today-chip')), findsNothing);
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

  testWidgets('the story fills a wide window rather than sitting in gutters', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    final story = _story(trip, today: DateTime(2026, 6, 1));
    await pumpView(tester, story, viewSize: const Size(1400, 900));

    // Edge to edge: a centred maximum width left blank space either side,
    // which reads as a broken page rather than a deliberate measure.
    expect(tester.getSize(find.byType(CustomScrollView)).width, 1400.0);
  });

  testWidgets('the stat strip scrolls away', (tester) async {
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

    // The strip is ordinary scroll content: nothing is pinned (#2845).
    expect(find.byType(TripStatStrip), findsNothing);
  });

  testWidgets('surface days get the same header as dive days', (tester) async {
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
    // contributes a header, surface day included.
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

  testWidgets('the surface day renders stored weather', (tester) async {
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
    final surfaceDate = DateTime(2026, 3, 26);
    final now = DateTime(2026, 3, 28);

    await pumpView(
      tester,
      story,
      tripDayWeather: {
        tripDayMillis(surfaceDate): TripDayWeather(
          id: 'w1',
          tripId: trip.id,
          date: surfaceDate,
          latitude: 12.10,
          longitude: -68.20,
          airTemp: 26,
          cloudCover: CloudCover.clear,
          fetchedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      },
    );
    await tester.pump();

    expect(find.text('26°C'), findsOneWidget);
  });

  testWidgets('a day with nothing stored renders no weather badge', (
    tester,
  ) async {
    // The view no longer falls back to a network fetch while rendering: an
    // unstored day is simply badge-free until the backfill writes its row.
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
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 500);
    });

    await pumpView(tester, story, weatherHttpClient: client);
    await tester.pump();

    expect(calls, 0);
    expect(find.textContaining('°C'), findsNothing);
  });

  testWidgets('the story is one scroll with no pinned band', (tester) async {
    final trip = _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9));
    final story = _story(
      trip,
      dives: [_diveAt('d1', DateTime(2026, 3, 8, 9), 12.1, -68.2)],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(390, 2600));
    expect(find.byType(SliverPersistentHeader), findsNothing);
    expect(find.byType(TripStoryHero), findsOneWidget);
    // One map, inside the day with a located dive.
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TripChecklistSection), findsNothing);
  });

  testWidgets('each day card gets only its own points', (tester) async {
    final trip = _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 9));
    final story = _story(
      trip,
      dives: [
        _diveAt('d1', DateTime(2026, 3, 7, 9), 12.1, -68.2),
        _diveAt('d2', DateTime(2026, 3, 8, 9), 12.2, -68.3),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);
    final cards = tester.widgetList<TripStoryDayCard>(
      find.byType(TripStoryDayCard),
    );
    final byDay = {for (final c in cards) c.day.dayNumber: c.mapPoints};
    expect(byDay[1]!.map((p) => p.diveId), ['d1']);
    expect(byDay[2]!.map((p) => p.diveId), ['d2']);
    expect(byDay[3], isEmpty);
  });

  testWidgets('expanding a day map opens the fullscreen page', (tester) async {
    final trip = _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 7));
    final story = _story(
      trip,
      dives: [_diveAt('d1', DateTime(2026, 3, 7, 9), 12.1, -68.2)],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);
    await tester.tap(find.byKey(const Key('day-map-expand')));
    await tester.pumpAndSettle();
    expect(find.byType(TripDayMapPage), findsOneWidget);
  });

  testWidgets('a trip in progress with slots shows the cylinders summary', (
    tester,
  ) async {
    final now = DateTime.now();
    final trip = _trip(
      start: DateTime(now.year, now.month, now.day - 1),
      end: DateTime(now.year, now.month, now.day + 3),
    );
    await pumpView(
      tester,
      _story(trip, today: now),
      cylinderStates: [
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
    );
    expect(find.byKey(const Key('trip-cylinders-summary')), findsOneWidget);
  });

  testWidgets('the under-way cards open with today, above its header', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = _dayOnly(now);
    final trip = _trip(
      start: today.subtract(const Duration(days: 8)),
      end: today.add(const Duration(days: 15)),
    );
    final story = _story(
      trip,
      today: now,
      dives: [
        for (var i = 0; i <= 8; i++)
          _dive('d$i', today.subtract(Duration(days: 8 - i, hours: -9))),
      ],
    );
    await pumpView(
      tester,
      story,
      viewSize: const Size(800, 900),
      cylinderStates: [
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
    );
    final summary = find.byKey(const Key('trip-cylinders-summary'));
    final chip = find.byKey(const Key('today-chip'));
    expect(summary, findsOneWidget);
    expect(tester.getTopLeft(summary).dy, lessThan(40));
    expect(tester.getTopLeft(summary).dy, lessThan(tester.getTopLeft(chip).dy));
    expect(find.byType(TripStoryHero), findsNothing);
  });

  testWidgets('day cards are keyed by date so shifted days keep their state', (
    tester,
  ) async {
    final trip = _trip(start: DateTime(2026, 3, 7), end: DateTime(2026, 3, 8));
    await pumpView(tester, _story(trip, today: DateTime(2026, 6, 1)));
    final keys = [
      for (final c in tester.widgetList<TripStoryDayCard>(
        find.byType(TripStoryDayCard),
      ))
        c.key,
    ];
    expect(keys, [
      ValueKey(DateTime(2026, 3, 7)),
      ValueKey(DateTime(2026, 3, 8)),
    ]);
  });

  testWidgets('a long trip mounts only the day maps near the screen', (
    tester,
  ) async {
    final trip = _trip(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 30));
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 30; i++)
          _diveAt('d$i', DateTime(2026, 3, 1 + i, 9), 12.1 + i / 100, -68.2),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(390, 844));
    // Each map loads tiles; thirty at once would be thirty sets of tiles.
    expect(
      find.byType(FlutterMap, skipOffstage: false).evaluate().length,
      lessThan(6),
    );
  });

  testWidgets('a past trip shows its Documents before the first day', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 29),
    );
    final story = _story(
      trip,
      dives: [_dive('d1', DateTime(2026, 3, 27, 9))],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story);
    final docs = tester.getTopLeft(
      find.byKey(const ValueKey('documents-section-trip')),
    );
    final firstDay = tester.getTopLeft(find.byType(TripStoryDayHeader).first);
    expect(docs.dy, lessThan(firstDay.dy));
  });
}
