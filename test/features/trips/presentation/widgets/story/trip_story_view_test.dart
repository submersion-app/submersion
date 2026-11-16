import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_profile_batcher.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_picker.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_line.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_plan.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_trip_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Stands in for the app's mini-profile batcher: records what it was asked
/// for and fetches nothing.
class _RecordingBatcher extends DiveProfileBatcher {
  _RecordingBatcher(super.ref);

  final calls = <List<String>>[];

  @override
  Future<void> load(List<String> diveIds) async => calls.add([...diveIds]);
}

List<DiveProfilePoint> _profile(double depth) => [
  const DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 300, depth: depth),
  const DiveProfilePoint(timestamp: 3000, depth: 0),
];

Dive _dive(String id, DateTime at, {bool planned = false}) => Dive(
  id: id,
  dateTime: at,
  maxDepth: 20,
  runtime: const Duration(minutes: 50),
  isPlanned: planned,
);

Dive _diveAt(String id, DateTime at, double lat, double lng) => Dive(
  id: id,
  dateTime: at,
  maxDepth: 20,
  site: DiveSite(
    id: 'site-$id',
    name: 'Site $id',
    location: GeoPoint(lat, lng),
  ),
);

Trip _trip({required DateTime start, required DateTime end}) => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: start,
  endDate: end,
  tripType: TripType.resort,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

TripStory _story(
  Trip trip, {
  List<Dive> dives = const [],
  required DateTime today,
}) => buildTripStory(
  trip: trip,
  dives: dives,
  itineraryDays: [],
  mediaByDiveId: {},
  sightingsByDiveId: {},
  checklistItems: [],
  today: today,
);

DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

void main() {
  late _RecordingBatcher batcher;

  Future<void> pumpView(
    WidgetTester tester,
    TripStory story, {
    ValueNotifier<TripStorySelection?>? selection,
    ValueNotifier<TripStory>? stories,
    Map<String, List<DiveProfilePoint>> profiles = const {},
    Set<String> undived = const {},
    Future<Set<String>> Function()? undivedRead,
    Stream<int>? profileWrites,
    Map<int, TripDayWeather>? tripDayWeather,
    Size viewSize = const Size(420, 900),
    ValueChanged<TripNoteDay>? onEditDayNote,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Dates are formatted against Intl.defaultLocale, a process global the
    // app sets from its own locale. Pin it and put it back.
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);

    final overrides = await getBaseOverrides(tripDayWeather: tripDayWeather);
    Widget view(TripStory shown) => TripStoryView(
      story: shown,
      stats: TripWithStats(trip: shown.trip, diveCount: 2),
      selection: selection,
      onEditDayNote: onEditDayNote,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: stories == null
                ? view(story)
                : ValueListenableBuilder<TripStory>(
                    valueListenable: stories,
                    builder: (_, shown, _) => view(shown),
                  ),
          ),
        ),
        GoRoute(path: '/dives/:id', builder: (_, _) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProfileBatcherProvider.overrideWith(
            (ref) => batcher = _RecordingBatcher(ref),
          ),
          batchProfileCacheProvider.overrideWith((ref) => {...profiles}),
          tripUndivedPlanIdsProvider(
            'trip-1',
          ).overrideWith((ref) => undivedRead?.call() ?? Future.value(undived)),
          tripProfileWritesProvider.overrideWith(
            (ref) => profileWrites ?? const Stream<int>.empty(),
          ),
          tripCountriesProvider.overrideWith((ref) async => {}),
          tripCylinderStatesProvider(
            'trip-1',
          ).overrideWith((ref) async => const []),
          tripFillForecastProvider('trip-1').overrideWith((ref) async => null),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  TripStoryDayPage dayPage(WidgetTester tester) =>
      tester.widget<TripStoryDayPage>(find.byType(TripStoryDayPage));

  // Three days in March, long over: dives on days 1 and 3, a surface day
  // between them.
  final marchTrip = _trip(
    start: DateTime(2026, 3, 25),
    end: DateTime(2026, 3, 27),
  );
  final finished = _story(
    marchTrip,
    dives: [
      _dive('d1', DateTime(2026, 3, 25, 9)),
      _dive('d3a', DateTime(2026, 3, 27, 9)),
      _dive('d3b', DateTime(2026, 3, 27, 14)),
    ],
    today: DateTime(2026, 6, 1),
  );

  group("a day's part of the trip's Notes (#4625)", () {
    final noted = _story(
      marchTrip.copyWith(notes: 'Intro\n\n## Day 2\nCurrent was strong'),
      dives: [_dive('d1', DateTime(2026, 3, 25, 9))],
      today: DateTime(2026, 6, 1),
    );
    final day2 = DateTime(2026, 3, 26);

    testWidgets('the day shows its passage', (tester) async {
      await pumpView(
        tester,
        noted,
        selection: ValueNotifier(TripStorySelection.day(day2)),
      );

      expect(dayPage(tester).tripNotes, 'Current was strong');
      expect(find.text('Current was strong'), findsOneWidget);
    });

    testWidgets('edited Notes reach the day page', (tester) async {
      final stories = ValueNotifier(noted);
      addTearDown(stories.dispose);
      await pumpView(
        tester,
        noted,
        stories: stories,
        selection: ValueNotifier(TripStorySelection.day(day2)),
      );
      expect(dayPage(tester).tripNotes, 'Current was strong');

      stories.value = _story(
        marchTrip.copyWith(notes: 'Intro\n\n## Day 2\nMantas at dusk'),
        dives: [_dive('d1', DateTime(2026, 3, 25, 9))],
        today: DateTime(2026, 6, 1),
      );
      await tester.pumpAndSettle();

      expect(dayPage(tester).tripNotes, 'Mantas at dusk');
    });

    testWidgets('another day has no passage', (tester) async {
      await pumpView(
        tester,
        noted,
        selection: ValueNotifier(TripStorySelection.day(DateTime(2026, 3, 25))),
      );

      expect(dayPage(tester).tripNotes, isNull);
    });

    testWidgets('the caption opens the Trip page at its Notes', (tester) async {
      await pumpView(
        tester,
        noted,
        selection: ValueNotifier(TripStorySelection.day(day2)),
        viewSize: const Size(420, 420),
      );

      await tester.tap(find.byKey(TripStoryDayPlan.fromTripNotesKey));
      await tester.pumpAndSettle();

      expect(find.byType(TripStoryTripPage), findsOneWidget);
      final notes = tester.getRect(find.text('Current was strong'));
      expect(notes.top, greaterThanOrEqualTo(0));
      expect(notes.bottom, lessThanOrEqualTo(420));
    });

    testWidgets('the edit action names the day it is on', (tester) async {
      final edited = <TripNoteDay>[];
      await pumpView(
        tester,
        noted,
        selection: ValueNotifier(TripStorySelection.day(day2)),
        onEditDayNote: edited.add,
      );

      await tester.tap(find.byKey(TripStoryDayPage.editNoteKey));
      expect(edited, [TripNoteDay(date: day2, dayNumber: 2)]);
    });

    testWidgets('no edit action without a handler', (tester) async {
      await pumpView(
        tester,
        noted,
        selection: ValueNotifier(TripStorySelection.day(day2)),
      );

      expect(find.byKey(TripStoryDayPage.editNoteKey), findsNothing);
    });
  });

  group('where the page opens', () {
    testWidgets('a finished trip opens on the Trip page', (tester) async {
      await pumpView(tester, finished);

      expect(find.byType(TripStoryTripPage), findsOneWidget);
      expect(find.byType(TripStoryDayPage), findsNothing);
    });

    testWidgets('a trip under way opens on today', (tester) async {
      final now = DateTime.now();
      final today = _dayOnly(now);
      final trip = _trip(
        start: DateTime(today.year, today.month, today.day - 2),
        end: DateTime(today.year, today.month, today.day + 3),
      );
      await pumpView(tester, _story(trip, today: now));

      expect(find.byType(TripStoryTripPage), findsNothing);
      expect(dayPage(tester).day.kind, TripStoryDayKind.today);
      expect(dayPage(tester).day.dayNumber, 3);
    });

    testWidgets('a story that reaches today on a trip that has ended opens '
        'on the Trip page', (tester) async {
      final now = DateTime.now();
      final today = _dayOnly(now);
      final trip = _trip(
        start: DateTime(today.year, today.month, today.day - 5),
        end: DateTime(today.year, today.month, today.day - 2),
      );
      // A dive logged today stretches the story's span past the trip's end.
      final story = _story(
        trip,
        today: now,
        dives: [_dive('late', DateTime(today.year, today.month, today.day, 9))],
      );
      expect(story.todayIndex, isNotNull);

      await pumpView(tester, story);

      expect(find.byType(TripStoryTripPage), findsOneWidget);
    });

    testWidgets('the selected day vanishing falls back to the Trip page', (
      tester,
    ) async {
      final selection = ValueNotifier<TripStorySelection?>(
        TripStorySelection.day(DateTime(2026, 12, 25)),
      );
      addTearDown(selection.dispose);

      await pumpView(tester, finished, selection: selection);

      expect(find.byType(TripStoryTripPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a day that disappears while it is open falls back too', (
      tester,
    ) async {
      final stories = ValueNotifier(finished);
      addTearDown(stories.dispose);
      await pumpView(tester, finished, stories: stories);
      await tester.tap(find.byKey(TripDayPicker.dayTileKey(3)));
      await tester.pump();
      expect(dayPage(tester).day.dayNumber, 3);

      // The trip shrinks to its first day.
      stories.value = _story(
        _trip(start: DateTime(2026, 3, 25), end: DateTime(2026, 3, 25)),
        dives: [_dive('d1', DateTime(2026, 3, 25, 9))],
        today: DateTime(2026, 6, 1),
      );
      await tester.pump();

      expect(find.byType(TripStoryTripPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('choosing a page', () {
    testWidgets('a tile shows its day and only its day; the Trip tile comes '
        'back', (tester) async {
      await pumpView(tester, finished);

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(3)));
      await tester.pump();
      expect(dayPage(tester).day.dayNumber, 3);
      expect(find.byType(TripStoryDayPage), findsOneWidget);
      expect(find.byType(TripStoryTripPage), findsNothing);

      await tester.tap(find.byKey(TripDayPicker.tripTileKey));
      await tester.pump();
      expect(find.byType(TripStoryTripPage), findsOneWidget);
      expect(find.byType(TripStoryDayPage), findsNothing);
    });

    testWidgets('a day line on the Trip page selects its day', (tester) async {
      await pumpView(tester, finished);

      await tester.tap(find.byKey(TripStoryDayLine.keyFor(2)));
      await tester.pump();

      expect(dayPage(tester).day.dayNumber, 2);
      expect(
        tester.widget<TripDayPicker>(find.byType(TripDayPicker)).selectedDate,
        DateTime(2026, 3, 26),
      );
    });

    testWidgets('a choice is written to the selection it was handed', (
      tester,
    ) async {
      final selection = ValueNotifier<TripStorySelection?>(null);
      addTearDown(selection.dispose);
      await pumpView(tester, finished, selection: selection);
      // The opening page is worked out, never written.
      expect(selection.value, isNull);

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(1)));
      await tester.pump();
      expect(selection.value, TripStorySelection.day(DateTime(2026, 3, 25)));

      await tester.tap(find.byKey(TripDayPicker.tripTileKey));
      await tester.pump();
      expect(selection.value, const TripStorySelection.trip());
    });

    testWidgets('changing day starts at the top', (tester) async {
      final manyDives = _story(
        marchTrip,
        dives: [
          for (var i = 0; i < 6; i++)
            _dive('a$i', DateTime(2026, 3, 25, 7 + 2 * i)),
          for (var i = 0; i < 6; i++)
            _dive('b$i', DateTime(2026, 3, 26, 7 + 2 * i)),
        ],
        today: DateTime(2026, 6, 1),
      );
      await pumpView(tester, manyDives, viewSize: const Size(420, 600));
      await tester.tap(find.byKey(TripDayPicker.dayTileKey(1)));
      await tester.pump();
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(TripStoryDayPage),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      await tester.drag(find.byType(TripStoryDayPage), const Offset(0, -300));
      await tester.pump();
      expect(position().pixels, greaterThan(0));

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(2)));
      await tester.pump();

      expect(dayPage(tester).day.dayNumber, 2);
      expect(position().pixels, 0);
    });
  });

  group('the layout', () {
    testWidgets('the picker stays put while the page scrolls', (tester) async {
      final manyDives = _story(
        marchTrip,
        dives: [
          for (var i = 0; i < 6; i++)
            _dive('a$i', DateTime(2026, 3, 25, 7 + 2 * i)),
        ],
        today: DateTime(2026, 6, 1),
      );
      await pumpView(tester, manyDives, viewSize: const Size(420, 600));
      await tester.tap(find.byKey(TripDayPicker.dayTileKey(1)));
      await tester.pump();
      final before = tester.getRect(find.byType(TripDayPicker));
      expect(before.top, 0);

      await tester.drag(find.byType(TripStoryDayPage), const Offset(0, -300));
      await tester.pump();

      expect(tester.getRect(find.byType(TripDayPicker)), before);
    });

    testWidgets('the trip name is not repeated on either page', (tester) async {
      await pumpView(tester, finished);
      expect(find.text('Bonaire'), findsNothing);

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(1)));
      await tester.pump();
      expect(find.text('Bonaire'), findsNothing);
    });

    testWidgets('the picker is taller on a wide pane', (tester) async {
      await pumpView(tester, finished, viewSize: const Size(640, 900));
      expect(
        tester.widget<TripDayPicker>(find.byType(TripDayPicker)).chartHeight,
        76,
      );
    });

    testWidgets('and 60 on a phone', (tester) async {
      await pumpView(tester, finished);
      expect(
        tester.widget<TripDayPicker>(find.byType(TripDayPicker)).chartHeight,
        60,
      );
    });
  });

  group('what each day is handed', () {
    testWidgets('each day page gets only its own map points', (tester) async {
      final story = _story(
        marchTrip,
        dives: [
          _diveAt('d1', DateTime(2026, 3, 25, 9), 12.1, -68.2),
          _diveAt('d2', DateTime(2026, 3, 26, 9), 12.2, -68.3),
        ],
        today: DateTime(2026, 6, 1),
      );
      await pumpView(tester, story);

      Future<Iterable<String?>> pointsOf(int day) async {
        await tester.tap(find.byKey(TripDayPicker.dayTileKey(day)));
        await tester.pump();
        return dayPage(tester).mapPoints.map((p) => p.diveId);
      }

      expect(await pointsOf(1), ['d1']);
      expect(await pointsOf(2), ['d2']);
      expect(await pointsOf(3), isEmpty);
    });

    testWidgets('a day shows the weather stored for it', (tester) async {
      final surfaceDate = DateTime(2026, 3, 26);
      final now = DateTime(2026, 3, 28);
      await pumpView(
        tester,
        finished,
        tripDayWeather: {
          tripDayMillis(surfaceDate): TripDayWeather(
            id: 'w1',
            tripId: 'trip-1',
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

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(2)));
      await tester.pump();
      expect(find.text('26°C'), findsOneWidget);

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(1)));
      await tester.pump();
      expect(find.text('26°C'), findsNothing);
    });
  });

  group('the picker\'s profiles', () {
    TripDayPicker picker(WidgetTester tester) =>
        tester.widget<TripDayPicker>(find.byType(TripDayPicker));

    testWidgets('asks the batcher once for every dive on the trip', (
      tester,
    ) async {
      await pumpView(tester, finished);

      expect(batcher.calls, hasLength(1));
      expect(batcher.calls.single.toSet(), {'d1', 'd3a', 'd3b'});
    });

    testWidgets('asks again when the trip gains a dive, not on every rebuild', (
      tester,
    ) async {
      final stories = ValueNotifier(finished);
      addTearDown(stories.dispose);
      await pumpView(tester, finished, stories: stories);
      // Stays on the Trip page, which holds no dive cards: a dive card asks
      // the same batcher for its own mini profile, and this counts only the
      // story's requests.
      await tester.tap(find.byKey(TripDayPicker.tripTileKey));
      await tester.pump();
      expect(batcher.calls, hasLength(1));

      stories.value = _story(
        marchTrip,
        dives: [
          _dive('d1', DateTime(2026, 3, 25, 9)),
          _dive('d2', DateTime(2026, 3, 26, 9)),
        ],
        today: DateTime(2026, 6, 1),
      );
      await tester.pump();
      await tester.pump();

      expect(batcher.calls, hasLength(2));
      expect(batcher.calls.last.toSet(), {'d1', 'd2'});
    });

    testWidgets('does not ask again when the story changes but its dives do '
        'not', (tester) async {
      final stories = ValueNotifier(finished);
      addTearDown(stories.dispose);
      await pumpView(tester, finished, stories: stories);
      await tester.tap(find.byKey(TripDayPicker.tripTileKey));
      await tester.pump();
      expect(batcher.calls, hasLength(1));

      // The same three dives, read again after one was edited: a checklist
      // tick or a linked photo recomposes the story the same way. Every ask
      // re-reads each dive held without samples, so an unchanged set of dives
      // must not ask; a profile written is heard on its own.
      stories.value = _story(
        marchTrip,
        dives: [
          _dive('d1', DateTime(2026, 3, 25, 9)),
          _dive('d3a', DateTime(2026, 3, 27, 9)).copyWith(maxDepth: 27.4),
          _dive('d3b', DateTime(2026, 3, 27, 14)),
        ],
        today: DateTime(2026, 6, 1),
      );
      await tester.pump();
      await tester.pump();

      expect(batcher.calls, hasLength(1));
    });

    testWidgets('asks again when a profile is written, even with the story '
        'unchanged', (tester) async {
      final writes = StreamController<int>();
      addTearDown(writes.close);
      await pumpView(tester, finished, profileWrites: writes.stream);
      await tester.tap(find.byKey(TripDayPicker.tripTileKey));
      await tester.pump();
      expect(batcher.calls, hasLength(1));

      // No frame follows: nothing on screen changed, so nothing asks for
      // one. The request must not wait for a frame that may never come.
      writes.add(1);
      await tester.idle();
      await tester.idle();

      expect(batcher.calls, hasLength(2));
      expect(batcher.calls.last.toSet(), {'d1', 'd3a', 'd3b'});
    });

    testWidgets('asks for a long trip a list page at a time, in the '
        'story\'s order', (tester) async {
      final long = _story(
        marchTrip,
        dives: [
          for (var day = 0; day < 3; day++)
            for (var i = 0; i < 40; i++)
              _dive(
                'd$day-${i.toString().padLeft(2, '0')}',
                DateTime(2026, 3, 25 + day, 6, i * 15),
              ),
        ],
        today: DateTime(2026, 6, 1),
      );
      await pumpView(tester, long);

      expect(batcher.calls.map((ids) => ids.length), [50, 50, 20]);
      expect(batcher.calls.expand((ids) => ids), [
        for (final day in long.days)
          for (final dive in day.dives) dive.id,
      ]);
    });

    testWidgets('choosing another day does not build the model again', (
      tester,
    ) async {
      await pumpView(
        tester,
        finished,
        profiles: {'d1': _profile(18), 'd3a': _profile(30)},
      );
      final before = picker(tester).model;

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(3)));
      await tester.pump();

      expect(picker(tester).selectedDate, DateTime(2026, 3, 27));
      expect(picker(tester).model, same(before));
    });

    testWidgets('draws what the cache holds, on the trip\'s scales', (
      tester,
    ) async {
      await pumpView(
        tester,
        finished,
        profiles: {'d1': _profile(18), 'd3a': _profile(30)},
      );

      final model = picker(tester).model;
      expect(model.days.map((d) => d.dives.length), [1, 0, 1]);
      expect(model.maxDepth, 30);
    });

    testWidgets('a plan nobody has dived draws dashed', (tester) async {
      final story = _story(
        marchTrip,
        dives: [
          _dive('d1', DateTime(2026, 3, 25, 9)),
          _dive('plan', DateTime(2026, 3, 26, 9), planned: true),
          _dive('mirror', DateTime(2026, 3, 27, 9), planned: true),
        ],
        today: DateTime(2026, 6, 1),
      );
      await pumpView(
        tester,
        story,
        profiles: {
          'd1': _profile(18),
          'plan': _profile(20),
          'mirror': _profile(22),
        },
        undived: {'plan'},
      );
      await tester.pump();

      final dashed = [
        for (final day in picker(tester).model.days) day.dives.single.dashed,
      ];
      expect(dashed, [false, true, false]);
    });

    testWidgets('until it is known which plans were dived, a plan is not '
        'drawn: it never shows solid first', (tester) async {
      final answer = Completer<Set<String>>();
      final story = _story(
        marchTrip,
        dives: [
          _dive('d1', DateTime(2026, 3, 25, 9)),
          _dive('plan', DateTime(2026, 3, 26, 9), planned: true),
        ],
        today: DateTime(2026, 6, 1),
      );
      await pumpView(
        tester,
        story,
        profiles: {'d1': _profile(18), 'plan': _profile(20)},
        undivedRead: () => answer.future,
      );

      var days = picker(tester).model.days;
      expect(days[0].dives.single.dashed, isFalse);
      expect(days[1].dives, isEmpty);

      answer.complete({'plan'});
      await tester.pump();
      await tester.pump();

      days = picker(tester).model.days;
      expect(days[1].dives.single.dashed, isTrue);
    });

    testWidgets('when the plans read fails it is still not known: a plan '
        'stays undrawn, and is never shown as dived', (tester) async {
      final story = _story(
        marchTrip,
        dives: [
          _dive('d1', DateTime(2026, 3, 25, 9)),
          _dive('plan', DateTime(2026, 3, 26, 9), planned: true),
        ],
        today: DateTime(2026, 6, 1),
      );
      await pumpView(
        tester,
        story,
        profiles: {'d1': _profile(18), 'plan': _profile(20)},
        undivedRead: () async => throw StateError('no database'),
      );
      await tester.pump();

      final days = picker(tester).model.days;
      expect(days[0].dives.single.dashed, isFalse);
      expect(days[1].dives, isEmpty);
    });

    testWidgets('a profile landing in the cache redraws the picker without '
        'rebuilding the page', (tester) async {
      await pumpView(tester, finished);
      await tester.tap(find.byKey(TripDayPicker.dayTileKey(1)));
      await tester.pump();
      final pageBefore = dayPage(tester);
      expect(picker(tester).model.days.first.dives, isEmpty);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripStoryView)),
      );
      container.read(batchProfileCacheProvider.notifier).state = {
        'd1': _profile(18),
      };
      await tester.pump();

      expect(picker(tester).model.days.first.dives, hasLength(1));
      expect(identical(dayPage(tester), pageBefore), isTrue);
    });
  });
}
