import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
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
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
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
  testWidgets('past trip renders day chapters, hero, and pinned stat strip', (
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
}
