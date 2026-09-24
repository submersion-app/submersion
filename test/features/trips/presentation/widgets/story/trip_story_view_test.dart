import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_map_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart';
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
      overrides: [...overrides, ...extra].cast(),
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

/// Top of a day's full-width chapter heading, or null when it is not built.
double? _headingTop(WidgetTester tester, int dayNumber) {
  final matches = find
      .byWidgetPredicate(
        (w) =>
            w is TripStoryDayHeader &&
            !w.compact &&
            w.day.dayNumber == dayNumber,
      )
      .evaluate();
  if (matches.isEmpty) return null;
  return tester.getTopLeft(find.byWidget(matches.first.widget)).dy;
}

int _dockedDayNumber(WidgetTester tester) => tester
    .widget<TripStoryDockedDay>(find.byType(TripStoryDockedDay))
    .day
    .dayNumber;

/// Where the band switches days for a viewport [height] tall: a third of the
/// way down the space below the docked band.
double _switchLineFor(double height) =>
    TripStoryBandExtents.dockedFloor +
    (height - TripStoryBandExtents.dockedFloor) / 3;

/// The switch line on the 500x700 phone most of these tests use.
double get _switchLine => _switchLineFor(700);

ScrollPosition _storyScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// Drags in steps past the touch slop until day [dayNumber]'s heading sits
/// strictly between [above] and [below], then fails loudly if it never did.
Future<double> _creepHeadingInto(
  WidgetTester tester,
  int dayNumber, {
  required double above,
  required double below,
}) async {
  // jumpTo rather than drags: it moves an exact distance with no momentum to
  // coast past a narrow window, and still fires real scroll notifications.
  for (var i = 0; i < 200; i++) {
    final top = _headingTop(tester, dayNumber);
    if (top != null && top > above && top < below) return top;
    final position = _storyScroll(tester);
    position.jumpTo(position.pixels + 20);
    await tester.pump(const Duration(milliseconds: 150));
  }
  fail('day $dayNumber heading never landed between $above and $below');
}

/// Forces one resolution at the settled position, independent of how the
/// view handles a scroll coming to rest, so a test about WHERE the line is
/// does not also depend on WHEN resolution runs.
Future<void> _resolveInPlace(WidgetTester tester) async {
  final position = _storyScroll(tester);
  final settled = position.pixels;
  await tester.pump(const Duration(milliseconds: 150));
  position.jumpTo(settled - 1);
  await tester.pump(const Duration(milliseconds: 150));
  position.jumpTo(settled);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump(const Duration(milliseconds: 400));
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

  testWidgets('one band serves every width', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    final story = _story(trip, today: DateTime(2026, 6, 1));
    await pumpView(tester, story, viewSize: const Size(1400, 900));

    // The 380px map column and its 900px breakpoint are gone.
    expect(find.byKey(const Key('trip-story-wide-layout')), findsNothing);
    expect(find.byKey(TripStoryBandDelegate.bandKey), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
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
    expect(
      tester.getSize(find.byKey(TripStoryBandDelegate.bandKey)).width,
      1400.0,
    );
  });

  testWidgets('the band parks at the docked extent', (tester) async {
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

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.getSize(find.byKey(TripStoryBandDelegate.bandKey)).height,
      closeTo(TripStoryBandExtents.dockedFloor, 1.0),
    );
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

  testWidgets('the band names the day whose heading last crossed the line', (
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

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    // The band names a day.
    expect(find.byType(TripStoryDockedDay), findsOneWidget);

    // The band names the day whose heading most recently crossed the line:
    // that heading, if still on screen, is above the line, and the next
    // day's heading, if on screen, is still below it.
    await _resolveInPlace(tester);
    final docked = _dockedDayNumber(tester);
    final dockedTop = _headingTop(tester, docked);
    if (dockedTop != null) {
      expect(dockedTop, lessThanOrEqualTo(_switchLine + 1));
    }
    final nextTop = _headingTop(tester, docked + 1);
    if (nextTop != null) {
      expect(nextTop, greaterThan(_switchLine - 1));
    }

    // The first day is well out of view by now.
    expect(find.textContaining('Mar 25'), findsNothing);
  });

  testWidgets('the band switches a third of the way below itself', (
    tester,
  ) async {
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

    // Just below the line: day 1 still owns the screen. A halfway line (398)
    // would already have switched here.
    await _creepHeadingInto(
      tester,
      2,
      above: _switchLine + 12,
      below: _switchLine + 85,
    );
    await _resolveInPlace(tester);
    expect(_dockedDayNumber(tester), 1);

    // Just above the line, but still below both earlier rules: the band edge
    // (96) and a third of the whole viewport (233). Both would still show
    // day 1 here, which is the late switch this line exists to fix.
    await _creepHeadingInto(tester, 2, above: 235, below: _switchLine - 12);
    await _resolveInPlace(tester);
    expect(_dockedDayNumber(tester), 2);
  });

  testWidgets('the last day docks once the story is scrolled to the end', (
    tester,
  ) async {
    // The last chapter plus the closers is shorter than the space below the
    // band, so its heading can never reach the line on its own: the scroll
    // runs out first. At the end the last day still has to get its turn.
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
    // A tall viewport pushes the line down to 397, below where the last
    // heading bottoms out, so only the end-of-scroll rule can dock it.
    await pumpView(tester, story, viewSize: const Size(500, 1000));

    final position = _storyScroll(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 150));
    await _resolveInPlace(tester);

    final lastTop = _headingTop(tester, 6);
    expect(lastTop, isNotNull);
    expect(
      lastTop,
      greaterThan(_switchLineFor(1000)),
      reason: 'the fixture no longer strands the last heading below the line',
    );
    expect(_dockedDayNumber(tester), 6);
  });

  testWidgets('a last chapter taller than the screen still docks its own day', (
    tester,
  ) async {
    // The last day carries enough dives that its chapter is taller than the
    // screen, so at the end of the scroll its heading has gone up past the top
    // while its body is still what fills the screen. No other heading can be
    // visible then, since every earlier day is further up, so the band should
    // name the last day rather than skip back to an earlier one.
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 5; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
        for (var j = 0; j < 12; j++)
          _dive('last$j', DateTime(2026, 3, 30, 7 + j)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    final position = _storyScroll(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 150));
    await _resolveInPlace(tester);

    // Guard: the scenario is actually reached. Headings are box slivers, so
    // they stay mounted however far off screen they go; look past offstage.
    final heading = find.byWidgetPredicate(
      (w) => w is TripStoryDayHeader && !w.compact && w.day.dayNumber == 6,
      skipOffstage: false,
    );
    expect(heading, findsOneWidget);
    expect(
      tester.getTopLeft(heading).dy,
      lessThan(0),
      reason: 'the last chapter no longer outgrows the screen',
    );
    expect(_dockedDayNumber(tester), 6);
  });

  testWidgets('the band catches up when a scroll comes to rest', (
    tester,
  ) async {
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

    // Day 2's heading comfortably below the line, band on day 1.
    await _creepHeadingInto(
      tester,
      2,
      above: _switchLine + 60,
      below: _switchLine + 110,
    );
    await _resolveInPlace(tester);
    expect(_dockedDayNumber(tester), 1);

    // One slow drag that carries the heading well above the line: every move
    // lands in the same frame, so the throttle resolves only the first (with
    // the heading still below the line) and drops the rest. The finger then
    // rests before lifting, so there is no momentum and no later update. Only
    // the scroll coming to rest can switch the band now.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, -20));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _headingTop(tester, 2),
      lessThan(_switchLine - 40),
      reason: 'the drag did not carry the heading past the line',
    );
    expect(_dockedDayNumber(tester), 2);
  });

  testWidgets('tapping the docked day scrolls its chapter back into view', (
    tester,
  ) async {
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

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 3; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    final docked = tester
        .widget<TripStoryDockedDay>(find.byType(TripStoryDockedDay))
        .day
        .date;

    await tester.tap(find.byType(TripStoryDockedDay));
    await tester.pumpAndSettle();

    // Its full-width heading is back on screen, below the band.
    final heading = find.byWidgetPredicate(
      (w) => w is TripStoryDayHeader && !w.compact && w.day.date == docked,
    );
    expect(heading, findsOneWidget);
    expect(
      tester.getTopLeft(heading).dy,
      greaterThanOrEqualTo(TripStoryBandExtents.dockedFloor - 1),
    );
  });

  testWidgets('the docked day sits at the start edge in both directions', (
    tester,
  ) async {
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

    Future<double> panelRelativeToMap(Locale locale) async {
      await pumpView(
        tester,
        story,
        viewSize: const Size(500, 700),
        locale: locale,
      );
      final scrollable = find.byType(CustomScrollView);
      for (var i = 0; i < 4; i++) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pump(const Duration(milliseconds: 500));
      return tester.getCenter(find.byType(TripStoryDockedDay)).dx -
          tester.getCenter(find.byType(TripStoryMap)).dx;
    }

    expect(await panelRelativeToMap(const Locale('en')), lessThan(0));
    expect(await panelRelativeToMap(const Locale('he')), greaterThan(0));
  });

  testWidgets('large text does not overflow the docked panel', (tester) async {
    // 2x is the common accessibility setting, and 96px has enough slack to
    // absorb it: the band does not grow here, it just must not clip.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    // No RenderFlex overflow from the scaled date and subtitle.
    expect(tester.takeException(), isNull);
    expect(find.byType(TripStoryDockedDay), findsOneWidget);
    expect(
      tester.getSize(find.byKey(TripStoryBandDelegate.bandKey)).height,
      closeTo(TripStoryBandExtents.dockedFloor, 1.0),
    );
  });

  testWidgets('text past the floor grows the band rather than clipping it', (
    tester,
  ) async {
    // Above roughly 2.3x the panel outgrows the 96px floor, and the band has
    // to grow with it: a fixed extent would clip the date instead.
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.getSize(find.byKey(TripStoryBandDelegate.bandKey)).height,
      greaterThan(TripStoryBandExtents.dockedFloor),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a subtitled day at 3x text does not clip the docked panel', (
    tester,
  ) async {
    // Dives with sites, so the docked panel carries a subtitle under the date.
    // Two scaled lines are what the band's extents have to reserve for; a day
    // without a subtitle needs less and would not catch an under-estimate.
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TripStoryDockedDay), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the docked panel overflowed the band it was given',
    );
  });

  testWidgets('tapping the docked day clears the chapter of the band', (
    tester,
  ) async {
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

    // Stop mid-story, so the reveal is not clamped by the end of the scroll
    // extent: that clamp is what hides an alignment that ignores the band.
    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 2; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    final docked = tester
        .widget<TripStoryDockedDay>(find.byType(TripStoryDockedDay))
        .day
        .date;

    await tester.tap(find.byType(TripStoryDockedDay));
    await tester.pumpAndSettle();

    final heading = find.byWidgetPredicate(
      (w) => w is TripStoryDayHeader && !w.compact && w.day.date == docked,
    );
    expect(heading, findsOneWidget);
    // Fully clear of the pinned band, not tucked underneath it.
    expect(
      tester.getTopLeft(heading).dy,
      greaterThanOrEqualTo(TripStoryBandExtents.dockedFloor),
      reason: 'the revealed heading is hidden behind the band',
    );
  });

  testWidgets('a trip with no mappable points still renders the band', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 27),
    );
    // Dives without sites: the geometry has no points at all.
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 3; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    expect(find.byKey(TripStoryBandDelegate.bandKey), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('the docked day carries its stored weather into the band', (
    tester,
  ) async {
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
    final now = DateTime(2026, 3, 31);

    // Weather for every day of the trip, each at a distinct temperature, so
    // the badge in the band can only come from the day actually docked.
    await pumpView(
      tester,
      story,
      viewSize: const Size(500, 700),
      tripDayWeather: {
        for (var i = 0; i < 6; i++)
          tripDayMillis(DateTime(2026, 3, 25 + i)): TripDayWeather(
            id: 'w$i',
            tripId: trip.id,
            date: DateTime(2026, 3, 25 + i),
            latitude: 12.10,
            longitude: -68.20,
            airTemp: 20.0 + i,
            cloudCover: CloudCover.clear,
            fetchedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
      },
    );

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    final panel = find.byType(TripStoryDockedDay);
    final dockedDay = tester.widget<TripStoryDockedDay>(panel).day;
    final expectedTemp = 20 + (dockedDay.dayNumber - 1);

    expect(
      find.descendant(
        of: panel,
        matching: find.textContaining('$expectedTemp'),
      ),
      findsOneWidget,
      reason: 'the band shows the docked day\'s own weather',
    );
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

  group('checklist closer reachability (#1569)', () {
    // The checklist closer is the only editable checklist surface a
    // non-liveaboard trip has. Hiding it while the trip is upcoming, or while
    // the checklist is still empty, made it unreachable in every state: the
    // section that applies a template was gated on a template already having
    // been applied.
    Trip relativeTrip({required bool upcoming}) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = upcoming
          ? today.add(const Duration(days: 10))
          : today.subtract(const Duration(days: 20));
      return Trip(
        id: 'trip-1',
        name: 'Bonaire',
        startDate: start,
        endDate: start.add(const Duration(days: 2)),
        tripType: TripType.resort,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    }

    TripStory relativeStory(Trip trip, List<TripChecklistItem> items) {
      return buildTripStory(
        trip: trip,
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: items,
        today: DateTime(
          trip.startDate.year,
          trip.startDate.month,
          trip.startDate.day,
        ),
      );
    }

    testWidgets('upcoming trip with an empty checklist can still bootstrap '
        'one', (tester) async {
      final trip = relativeTrip(upcoming: true);
      await pumpView(
        tester,
        relativeStory(trip, const []),
        extra: [tripChecklistProvider(trip.id).overrideWith((ref) async => [])],
      );

      // Titled "Checklist" rather than "0 of 0 to-dos done", and expanded so
      // the apply-template menu is reachable without a hunt.
      expect(find.text('Checklist'), findsOneWidget);
      expect(
        find.text('Plan your trip - add to-dos or apply a template'),
        findsOneWidget,
      );
      expect(find.text('Add item'), findsOneWidget);
    });

    testWidgets('upcoming trip with items opens expanded', (tester) async {
      final trip = relativeTrip(upcoming: true);
      final items = [
        TripChecklistItem(
          id: 'c1',
          tripId: trip.id,
          title: 'Service regulator',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      await pumpView(
        tester,
        relativeStory(trip, items),
        extra: [
          tripChecklistProvider(trip.id).overrideWith((ref) async => items),
        ],
      );

      // Open, so the card wears the section's own header rather than an
      // ExpansionTile title that would repeat it.
      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('0 of 1 to-dos done'), findsOneWidget);
      // No tap needed: an upcoming trip's prep list is the point of the page.
      expect(find.text('Service regulator'), findsOneWidget);
    });

    testWidgets('past trip with an empty checklist can still bootstrap one', (
      tester,
    ) async {
      final trip = relativeTrip(upcoming: false);
      await pumpView(
        tester,
        relativeStory(trip, const []),
        extra: [tripChecklistProvider(trip.id).overrideWith((ref) async => [])],
      );

      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('No checklist items'), findsOneWidget);
    });

    testWidgets('past trip with items stays collapsed', (tester) async {
      final trip = relativeTrip(upcoming: false);
      final items = [
        TripChecklistItem(
          id: 'c1',
          tripId: trip.id,
          title: 'Service regulator',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      await pumpView(
        tester,
        relativeStory(trip, items),
        extra: [
          tripChecklistProvider(trip.id).overrideWith((ref) async => items),
        ],
      );

      expect(find.text('0 of 1 done'), findsOneWidget);
      expect(find.text('Service regulator'), findsNothing);
    });

    testWidgets('liveaboard trips keep the closer out of the story', (
      tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        name: 'Bonaire',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 12)),
        tripType: TripType.liveaboard,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await pumpView(
        tester,
        relativeStory(trip, const []),
        extra: [tripChecklistProvider(trip.id).overrideWith((ref) async => [])],
      );

      // Liveaboards get a dedicated Checklist tab; a second copy in the story
      // would be two editors for one list.
      expect(find.text('Checklist'), findsNothing);
    });
  });
}
