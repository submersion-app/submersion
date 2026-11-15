import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_line.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_empty_state.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_trip_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_summary_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// A trip's story with [divesPerDay] dives on each day from [start], every
/// day's first dive at its own site and the deepest of the day.
({TripStory story, TripWithStats stats}) _trip(
  DateTime start,
  List<int> divesPerDay, {
  required DateTime today,
  TripType type = TripType.resort,
  String notes = '',
}) {
  const depths = [30.2, 28.4, 24.0];
  final dives = <Dive>[
    for (var d = 0; d < divesPerDay.length; d++)
      for (var i = 0; i < divesPerDay[d]; i++)
        Dive(
          id: 'd$d-$i',
          dateTime: DateTime(start.year, start.month, start.day + d, 8 + 3 * i),
          maxDepth: depths[i % depths.length],
          runtime: const Duration(minutes: 50),
          site: DiveSite(id: 'site-$d', name: 'Site ${d + 1}'),
        ),
  ];
  final trip = Trip(
    id: 'trip-1',
    name: 'Red Sea Liveaboard',
    startDate: start,
    endDate: DateTime(
      start.year,
      start.month,
      start.day + divesPerDay.length - 1,
    ),
    tripType: type,
    notes: notes,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  return (
    story: buildTripStory(
      trip: trip,
      dives: dives,
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: today,
    ),
    stats: TripWithStats(
      trip: trip,
      diveCount: dives.length,
      totalRuntime: dives.length * 50 * 60,
      maxDepth: dives.isEmpty ? null : 30.2,
    ),
  );
}

void main() {
  late List<DateTime> selected;

  setUp(() => selected = []);

  Future<void> pumpTripPage(
    WidgetTester tester, {
    required TripStory story,
    required TripWithStats stats,
    List<Override> extra = const [],
    VoidCallback? onScanForDives,
  }) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Dates are formatted against Intl.defaultLocale, a process global the
    // app sets from its own locale. Pin it and put it back.
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);

    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TripStoryTripPage(
              story: story,
              stats: stats,
              onSelectDay: selected.add,
              onScanForDives: onScanForDives,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          tripCountriesProvider.overrideWith((ref) async => {}),
          tripFillForecastProvider('trip-1').overrideWith((ref) async => null),
          ...extra,
        ].cast(),
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

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder.first).dy;

  final finished = _trip(
    DateTime(2026, 10, 28),
    [1, 3, 3, 2, 1, 0],
    today: DateTime(2026, 12, 1),
    notes: 'Strong current at Daedalus.',
  );

  testWidgets('a finished trip lists dates, totals, a line per day, notes '
      'and documents, in that order', (tester) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    expect(find.byType(TripStoryDayLine), findsNWidgets(6));
    final ys = [
      top(tester, find.textContaining('6 days')),
      top(tester, find.byKey(TripStoryTripPage.totalsKey)),
      top(tester, find.byKey(TripStoryDayLine.keyFor(1))),
      top(tester, find.byKey(TripStoryDayLine.keyFor(6))),
      top(tester, find.textContaining('Strong current', findRichText: true)),
      top(tester, find.byType(DocumentsSection)),
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.byType(TripFlightCountdownCard), findsNothing);
  });

  testWidgets('the totals are the trip stats, in the diver\'s units', (
    tester,
  ) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    final totals = find.byKey(TripStoryTripPage.totalsKey);
    Finder within(String text) =>
        find.descendant(of: totals, matching: find.text(text));
    expect(within('10'), findsOneWidget);
    expect(within('8h 20m'), findsOneWidget);
    expect(within('30.2m'), findsOneWidget);
    // Five days were dived, each at its own site.
    expect(within('5'), findsOneWidget);
    expect(within('Sites visited'), findsOneWidget);
  });

  testWidgets('the trip name is not on the page', (tester) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    expect(find.text('Red Sea Liveaboard'), findsNothing);
  });

  testWidgets('tapping a day line selects that day', (tester) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    await tester.tap(find.byKey(TripStoryDayLine.keyFor(3)));

    expect(selected, [finished.story.days[2].date]);
  });

  testWidgets('a day line names its day, where it was, and what was dived', (
    tester,
  ) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    final line = find.byKey(TripStoryDayLine.keyFor(2));
    Finder within(String text) =>
        find.descendant(of: line, matching: find.text(text));
    expect(within('Thu, Oct 29'), findsOneWidget);
    expect(within('Site 2'), findsOneWidget);
    expect(within('3 dives'), findsOneWidget);
    expect(within('30.2m'), findsOneWidget);
    expect(
      tester.getSemantics(line),
      isSemantics(label: 'Thu, Oct 29, Site 2', isButton: true),
    );
  });

  testWidgets("a surface day's line shows no dive count", (tester) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    final line = find.byKey(TripStoryDayLine.keyFor(6));
    expect(
      find.descendant(of: line, matching: find.text('Surface day')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: line, matching: find.textContaining('dive')),
      findsNothing,
    );
  });

  testWidgets('an empty trip shows the empty state in place of totals and '
      'day lines', (tester) async {
    final empty = _trip(DateTime(2026, 10, 28), [
      0,
      0,
      0,
    ], today: DateTime(2026, 12, 1));
    var scans = 0;
    await pumpTripPage(
      tester,
      story: empty.story,
      stats: empty.stats,
      onScanForDives: () => scans++,
    );

    expect(find.byType(TripStoryEmptyState), findsOneWidget);
    expect(find.byKey(TripStoryTripPage.totalsKey), findsNothing);
    expect(find.byType(TripStoryDayLine), findsNothing);
    expect(find.byType(DocumentsSection), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    expect(scans, 1);
  });

  testWidgets('a liveaboard shows its vessel after the day lines', (
    tester,
  ) async {
    final liveaboard = _trip(
      DateTime(2026, 10, 28),
      [1, 2],
      today: DateTime(2026, 12, 1),
      type: TripType.liveaboard,
    );
    await pumpTripPage(
      tester,
      story: liveaboard.story,
      stats: liveaboard.stats,
      extra: [
        liveaboardDetailsProvider('trip-1').overrideWith(
          (ref) async => LiveaboardDetails(
            id: 'lv-1',
            tripId: 'trip-1',
            vesselName: 'MY Blue Horizon',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ),
      ],
    );

    expect(find.byType(TripVesselSection), findsOneWidget);
    expect(
      top(tester, find.byKey(TripStoryDayLine.keyFor(2))),
      lessThan(top(tester, find.byType(TripVesselSection))),
    );
  });

  testWidgets('a resort trip shows no vessel', (tester) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    expect(find.byType(TripVesselSection), findsNothing);
  });

  group('a trip under way', () {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 1);
    final underWay = _trip(start, [1, 1, 0], today: now);
    final cylinders = tripCylinderStatesProvider('trip-1').overrideWith(
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
    );

    testWidgets('says Day N of M and shows the under-way cards above the '
        'day lines', (tester) async {
      await pumpTripPage(
        tester,
        story: underWay.story,
        stats: underWay.stats,
        extra: [cylinders],
      );

      expect(find.text('Day 2 of 3'), findsOneWidget);
      const summary = Key('trip-cylinders-summary');
      expect(find.byKey(summary), findsOneWidget);
      expect(
        top(tester, find.byKey(TripStoryTripPage.totalsKey)),
        lessThan(top(tester, find.byKey(summary))),
      );
      expect(
        top(tester, find.byKey(summary)),
        lessThan(top(tester, find.byKey(TripStoryDayLine.keyFor(1)))),
      );
    });

    testWidgets("today's line carries the Today chip", (tester) async {
      await pumpTripPage(
        tester,
        story: underWay.story,
        stats: underWay.stats,
        extra: [cylinders],
      );

      expect(
        find.descendant(
          of: find.byKey(TripStoryDayLine.keyFor(2)),
          matching: find.byType(TodayChip),
        ),
        findsOneWidget,
      );
      expect(find.byType(TodayChip), findsOneWidget);
    });
  });

  testWidgets('a finished trip says nothing of a day in progress and shows '
      'no cylinders', (tester) async {
    await pumpTripPage(tester, story: finished.story, stats: finished.stats);

    expect(find.textContaining(' of 6'), findsNothing);
    expect(find.byType(TripCylindersSummaryCard), findsOneWidget);
    expect(find.byKey(const Key('trip-cylinders-summary')), findsNothing);
  });
}
