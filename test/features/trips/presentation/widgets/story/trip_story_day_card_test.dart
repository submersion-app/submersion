import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_plan.dart';
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
  int count = 1,
  String? speciesId,
}) => Sighting(
  id: id,
  diveId: 'd1',
  speciesId: speciesId ?? 'sp-$species',
  speciesName: species,
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

Future<void> pumpCard(
  WidgetTester tester,
  TripStoryDay day, {
  List<Override> extra = const [],
  List<TripStoryMapPoint> mapPoints = const [],
  void Function(TripStoryDay, List<TripStoryMapPoint>)? onExpandMap,
}) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: TripStoryDayCard(
              day: day,
              tripId: 'trip-1',
              mapPoints: mapPoints,
              onExpandMap: onExpandMap,
            ),
          ),
        ),
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

void main() {
  testWidgets('past day with dives shows rhythm and dive rows', (tester) async {
    final dive = createTestDiveWithBottomTime(
      id: 'd1',
      diveNumber: 42,
      bottomTime: const Duration(minutes: 47),
      maxDepth: 28.0,
    );
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [dive],
    );
    await pumpCard(tester, day);

    // The day title lives in the sticky header now, not the card.
    expect(find.textContaining('Day 2'), findsNothing);
    expect(find.byType(DayRhythmBar), findsOneWidget);
    expect(find.byType(DiveListItem), findsOneWidget);
  });

  testWidgets('stats and rhythm bar sit untinted under the header', (
    tester,
  ) async {
    final dive = createTestDiveWithBottomTime(
      id: 'd1',
      diveNumber: 42,
      bottomTime: const Duration(minutes: 47),
      maxDepth: 28.0,
    );
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [dive],
    );
    await pumpCard(tester, day);

    // The day-at-a-glance cluster: stat strip and rhythm bar group under the
    // header by spacing alone (#4106); a tinted box inside the card was the
    // third surface the hero folds away.
    final summary = find.byKey(const Key('day-summary'));
    expect(summary, findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.byType(DayRhythmBar)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.textContaining('Dives')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: summary,
        matching: find.byWidgetPredicate(
          (w) => w is Container && (w.color != null || w.decoration != null),
        ),
      ),
      findsNothing,
    );
    // The header leads the card, above the summary.
    final header = tester.getRect(find.byType(TripStoryDayHeader));
    expect(header.bottom, lessThanOrEqualTo(tester.getRect(summary).top));
    // The dive rows stay outside the summary: they are the primary content.
    expect(
      find.descendant(of: summary, matching: find.byType(DiveListItem)),
      findsNothing,
    );
  });

  testWidgets('photo strip carries a Photos caption', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
      media: [_media('m1')],
    );
    await pumpCard(tester, day);

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
    await pumpCard(tester, day);

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
    await pumpCard(tester, day);

    expect(find.text('Photos'), findsNothing);
    expect(find.text('Species seen'), findsNothing);
  });

  testWidgets('surface day is a card of nothing but its header', (
    tester,
  ) async {
    // The whole day is its header: title, date and the "Surface day" label
    // open the card (#4106) and nothing follows them.
    final day = TripStoryDay(
      date: DateTime(2026, 3, 9),
      dayNumber: 3,
      kind: TripStoryDayKind.past,
    );
    await pumpCard(tester, day);
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(TripStoryDayHeader), findsOneWidget);
    expect(find.textContaining('Surface day'), findsOneWidget);
    expect(find.byType(DayRhythmBar), findsNothing);
    expect(find.byKey(const Key('day-summary')), findsNothing);
  });

  testWidgets('planned day without content renders only its header', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
    );
    await pumpCard(tester, day);
    // Title and chip open the card; with no notes, port, dives, media, or
    // sightings there is nothing under them.
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
    expect(find.byType(TripStoryDayPlan), findsNothing);
  });

  testWidgets('planned day with only a blank port renders only its header', (
    tester,
  ) async {
    // A blank port is not content: it must not defeat the empty-body guard.
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
      itineraryDay: _itin(port: '   ', notes: '  '),
    );
    await pumpCard(tester, day);

    expect(find.byType(TripStoryDayHeader), findsOneWidget);
    expect(find.byType(TripStoryDayPlan), findsNothing);
  });

  testWidgets('past day renders photo strip with a more-indicator', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      itineraryDay: _itin(port: 'Kralendijk'),
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9), maxDepth: 20)],
      media: [for (var i = 0; i < 6; i++) _media('m$i')],
      mediaCount: 8,
    );
    await pumpCard(tester, day);

    // 8 photos, max 6 shown, so a "+2" more indicator appears.
    expect(find.text('+2'), findsOneWidget);
    // The port subtitle reads once, in the header that opens the card.
    expect(
      find.descendant(
        of: find.byType(TripStoryDayHeader),
        matching: find.textContaining('Kralendijk'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Kralendijk'), findsOneWidget);
    // Every tappable thumbnail (6 photos + the "+2" tile) is a labeled button
    // for screen readers, not an unlabeled image / bare "+2".
    final galleryButtons = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Open trip photos',
    );
    expect(galleryButtons, findsNWidgets(7));
  });

  testWidgets('past day merges duplicate species into one badge', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
      sightings: [
        _sighting('s1', 'Reef shark'),
        _sighting('s2', 'Reef shark'),
        _sighting('s3', 'Turtle'),
      ],
    );
    await pumpCard(tester, day);

    // Two "Reef shark" sightings merge into a single "x2" chip.
    expect(find.text('Reef shark x2'), findsOneWidget);
    expect(find.text('Turtle'), findsOneWidget);
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
    await pumpCard(tester, day);

    // Same display name but different speciesId: two separate chips, no "x2".
    expect(find.text('Goby'), findsNWidgets(2));
    expect(find.text('Goby x2'), findsNothing);
  });

  testWidgets('planned day shows itinerary notes and site-history pills', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
      itineraryDay: _itin(port: 'Manta Sandy', notes: 'Bring a reef hook'),
    );
    await pumpCard(
      tester,
      day,
      extra: [
        siteHistoryByNameProvider('Manta Sandy').overrideWith(
          (ref) async => (diveCount: 6, avgWaterTemp: 27.0, avgMaxDepth: 25.0),
        ),
      ],
    );

    expect(find.text('Bring a reef hook'), findsOneWidget);
    expect(find.textContaining('6 past dives here'), findsOneWidget);
  });

  testWidgets('a day with map points opens with its header in the map fade', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _pastDay(['d1', 'd2']),
      mapPoints: [_pin('d1', 1), _pin('d2', 2)],
    );
    expect(find.byType(FlutterMap), findsOneWidget);
    final backdrop = tester.getRect(find.byType(HeaderMapBackdrop));
    final header = tester.getRect(find.byType(TripStoryDayHeader));
    final summary = tester.getRect(find.byKey(const Key('day-summary')));
    // The map shows mapPeekHeight above the header row, and the row sits
    // inside the backdrop, where the fade has turned the card colour.
    expect(header.top - backdrop.top, TripStoryDayCard.mapPeekHeight);
    expect(backdrop.bottom, header.bottom);
    expect(summary.top, greaterThanOrEqualTo(backdrop.bottom));
    expect(
      tester
          .widget<HeaderMapBackdrop>(find.byType(HeaderMapBackdrop))
          .fadeColor,
      backdropColorOf(tester.element(find.byType(HeaderMapBackdrop))),
    );
  });

  testWidgets('a day without map points leads with its header on the card', (
    tester,
  ) async {
    await pumpCard(tester, _pastDay(['d1']));
    expect(find.byType(HeaderMapBackdrop), findsNothing);
    // The card's surface, inside its own 4px margin.
    final surface = tester.getRect(
      find
          .descendant(
            of: find.byType(Card).first,
            matching: find.byType(Material),
          )
          .first,
    );
    final header = tester.getRect(find.byType(TripStoryDayHeader));
    expect(header.top, surface.top + 16);
  });

  testWidgets('stored weather reaches the header', (tester) async {
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
              child: TripStoryDayCard(
                day: _pastDay(['d1']),
                tripId: 'trip-1',
                storedWeather: const TripStoryDayWeather(
                  airTemp: 29,
                  cloudCover: CloudCover.clear,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    expect(find.textContaining('29'), findsOneWidget);
  });

  testWidgets('a day with no map points shows no map', (tester) async {
    await pumpCard(tester, _pastDay(['d1']));
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('tapping a pin highlights its row, tapping again clears it', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _pastDay(['d1', 'd2']),
      mapPoints: [_pin('d1', 1), _pin('d2', 2)],
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

  testWidgets('the expand button hands the day and its points up', (
    tester,
  ) async {
    TripStoryDay? expandedDay;
    List<TripStoryMapPoint>? expandedPoints;
    await pumpCard(
      tester,
      _pastDay(['d1']),
      mapPoints: [_pin('d1', 1)],
      onExpandMap: (day, points) {
        expandedDay = day;
        expandedPoints = points;
      },
    );
    await tester.tap(find.byKey(const Key('day-map-expand')));
    expect(expandedDay?.dayNumber, 2);
    expect(expandedPoints?.single.diveId, 'd1');
  });

  testWidgets('a pin scrolls only when its row is off screen', (tester) async {
    tester.view.physicalSize = const Size(420, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCard(
      tester,
      _pastDay(['d1', 'd2', 'd3', 'd4']),
      mapPoints: [_pin('d1', 1), _pin('d4', 4)],
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, 0);
    final row1 = tester.getRect(
      find.byWidgetPredicate((w) => w is DiveListItem && w.summary.id == 'd1'),
    );
    expect(row1.bottom, lessThanOrEqualTo(560), reason: 'row 1 starts visible');
    // Row 1 is in view: the map stays where it is.
    await tester.tap(find.byKey(const Key('day-map-pin-d1')));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    // Row 4 is below the fold: the page brings it up.
    await tester.tap(find.byKey(const Key('day-map-pin-d4')));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('a drag on the day map scrolls the story, not the map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCard(
      tester,
      _pastDay(['d1', 'd2', 'd3', 'd4']),
      mapPoints: [_pin('d1', 1)],
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

  group('plan and conditions', () {
    ItineraryDay planned(int dives, {String notes = '', String? port}) =>
        _itin(notes: notes, port: port).copyWith(plannedDives: dives);

    testWidgets('today with no dives shows its notes and plan', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(3, notes: 'Two-tank boat dive'),
      );
      await pumpCard(tester, day);
      expect(find.text('Two-tank boat dive'), findsOneWidget);
      expect(find.text('0 of 3 planned dives'), findsOneWidget);
    });

    testWidgets("today's card has a primary outline", (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(2),
      );
      await pumpCard(tester, day);
      final card = tester.widget<Card>(find.byType(Card).first);
      final context = tester.element(find.byType(TripStoryDayCard));
      final side = (card.shape! as RoundedRectangleBorder).side;
      expect(side.color, Theme.of(context).colorScheme.primary);
      expect(side.width, 2);
    });

    testWidgets('a past day compares logged with planned', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: planned(3, notes: 'Reef day'),
        dives: _pastDay(['d1', 'd2', 'd3', 'd4']).dives,
      );
      await pumpCard(tester, day);
      expect(find.text('Reef day'), findsOneWidget);
      expect(find.text('4 of 3 planned dives'), findsOneWidget);
    });

    testWidgets('a planned rest day shows no plan line', (tester) async {
      final day = TripStoryDay(
        date: DateTime(2026, 3, 8),
        dayNumber: 2,
        kind: TripStoryDayKind.today,
        itineraryDay: planned(0, notes: 'Rest'),
      );
      await pumpCard(tester, day);
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
      await pumpCard(tester, day);
      expect(find.byKey(const Key('day-conditions-line')), findsOneWidget);
    });

    testWidgets('a planned port with no history renders only its header', (
      tester,
    ) async {
      final day = TripStoryDay(
        date: DateTime(2027, 1, 10),
        dayNumber: 1,
        kind: TripStoryDayKind.future,
        itineraryDay: _itin(port: 'Kralendijk'),
      );
      await pumpCard(
        tester,
        day,
        extra: [
          siteHistoryByNameProvider('Kralendijk').overrideWith(
            (ref) async =>
                (diveCount: 0, avgWaterTemp: null, avgMaxDepth: null),
          ),
        ],
      );
      expect(find.byType(TripStoryDayHeader), findsOneWidget);
      expect(find.byType(TripStoryDayPlan), findsNothing);
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
      await pumpCard(
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

    testWidgets('a port with no history adds no space to a planned card', (
      tester,
    ) async {
      final noHistory = siteHistoryByNameProvider('Kralendijk').overrideWith(
        (ref) async => (diveCount: 0, avgWaterTemp: null, avgMaxDepth: null),
      );
      Future<double> cardHeight(String? port) async {
        await pumpCard(
          tester,
          TripStoryDay(
            date: DateTime(2027, 1, 10),
            dayNumber: 1,
            kind: TripStoryDayKind.future,
            itineraryDay: _itin(port: port, notes: 'Bring a reef hook'),
          ),
          extra: [noHistory],
        );
        return tester.getSize(find.byType(Card)).height;
      }

      final withoutPort = await cardHeight(null);
      final withPort = await cardHeight('Kralendijk');
      expect(withPort, withoutPort);
    });

    testWidgets('a port card stays while its site history reloads', (
      tester,
    ) async {
      final pending = Completer<SiteHistory>();
      var loads = 0;
      await pumpCard(
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
        tester.element(find.byType(TripStoryDayCard)),
      ).invalidate(siteHistoryByNameProvider('Kralendijk'));
      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
      expect(find.textContaining('3 past dives here'), findsOneWidget);
    });
  });
}
