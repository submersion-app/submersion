import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_picker_model.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _stripKey = Key('strip');

List<DiveProfilePoint> _profile(double depth) => [
  const DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 300, depth: depth),
  DiveProfilePoint(timestamp: 2400, depth: depth * 0.6),
  const DiveProfilePoint(timestamp: 3000, depth: 0),
];

/// A trip from [start] with [divesPerDay] dives on each day, the first dive
/// of a day the deepest.
({TripStory story, TripPickerModel model}) _trip(
  DateTime start,
  List<int> divesPerDay, {
  DateTime? today,
  List<double> depths = const [30.2, 28.4, 24.0],
}) {
  final dives = <Dive>[
    for (var d = 0; d < divesPerDay.length; d++)
      for (var i = 0; i < divesPerDay[d]; i++)
        Dive(
          id: 'd$d-$i',
          dateTime: DateTime(start.year, start.month, start.day + d, 8 + 3 * i),
          maxDepth: depths[i % depths.length],
          runtime: const Duration(minutes: 50),
        ),
  ];
  final end = DateTime(
    start.year,
    start.month,
    start.day + divesPerDay.length - 1,
  );
  final story = buildTripStory(
    trip: Trip(
      id: 'trip-1',
      name: 'Red Sea',
      startDate: start,
      endDate: end,
      tripType: TripType.liveaboard,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    dives: dives,
    itineraryDays: [],
    mediaByDiveId: {},
    sightingsByDiveId: {},
    checklistItems: [],
    today: today ?? DateTime(2026, 12, 1),
  );
  final model = buildTripPickerModel(
    days: story.days,
    profiles: {for (final dive in dives) dive.id: _profile(dive.maxDepth!)},
    undivedPlanIds: const {},
  );
  return (story: story, model: model);
}

void main() {
  late List<DateTime?> selections;

  setUp(() => selections = []);

  Future<void> pumpPicker(
    WidgetTester tester, {
    required List<TripStoryDay> days,
    required TripPickerModel model,
    DateTime? selectedDate,
    double width = 360,
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) async {
    // Dates are formatted against Intl.defaultLocale, a process global the
    // app sets from its own locale. Pin it and put it back.
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: SizedBox(
                    key: _stripKey,
                    width: width,
                    child: TripDayPicker(
                      days: days,
                      model: model,
                      selectedDate: selectedDate,
                      onSelect: selections.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final six = _trip(DateTime(2026, 10, 28), [1, 3, 3, 2, 1, 0]);
  final fourteen = _trip(DateTime(2026, 10, 17), [
    1, 3, 3, 2, 3, 0, 2, 3, 3, 2, 3, 1, 2, 0, //
  ]);

  testWidgets('tapping a day tile selects its date; the Trip tile selects '
      'null', (tester) async {
    await pumpPicker(tester, days: six.story.days, model: six.model);

    await tester.tap(find.byKey(TripDayPicker.dayTileKey(2)));
    await tester.tap(find.byKey(TripDayPicker.tripTileKey));

    expect(selections, [six.story.days[1].date, null]);
  });

  testWidgets('six days fit a phone without scrolling', (tester) async {
    await pumpPicker(tester, days: six.story.days, model: six.model);

    expect(
      tester.getSize(find.byKey(TripDayPicker.dayTileKey(1))).width,
      closeTo((360 - TripDayPicker.tripTileWidth - 1) / 6, 0.5),
    );
    expect(
      tester.getRect(find.byKey(TripDayPicker.dayTileKey(6))).right,
      closeTo(tester.getRect(find.byKey(_stripKey)).right, 0.5),
    );
  });

  testWidgets('fourteen days scroll, the Trip tile stays put, the selected '
      'day is in view', (tester) async {
    await pumpPicker(
      tester,
      days: fourteen.story.days,
      model: fourteen.model,
      selectedDate: fourteen.story.days[11].date,
    );
    await tester.pumpAndSettle();

    final strip = tester.getRect(find.byKey(_stripKey));
    final tripLeft = tester
        .getTopLeft(find.byKey(TripDayPicker.tripTileKey))
        .dx;
    final selected = tester.getRect(find.byKey(TripDayPicker.dayTileKey(12)));
    expect(
      selected.left,
      greaterThanOrEqualTo(tripLeft + TripDayPicker.tripTileWidth),
    );
    expect(selected.right, lessThanOrEqualTo(strip.right + 0.5));
    expect(
      tester.getSize(find.byKey(TripDayPicker.dayTileKey(12))).width,
      closeTo(TripDayPicker.minDayTileWidth, 0.5),
    );

    await tester.drag(
      find.byKey(TripDayPicker.dayTileKey(12)),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(TripDayPicker.tripTileKey)).dx,
      tripLeft,
    );
    expect(
      tester.getRect(find.byKey(TripDayPicker.dayTileKey(12))).left,
      greaterThan(selected.left),
    );
  });

  testWidgets('a day tile says what it draws and whether it is selected', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      days: six.story.days,
      model: six.model,
      selectedDate: six.story.days[1].date,
    );

    expect(
      tester.getSemantics(find.byKey(TripDayPicker.dayTileKey(2))),
      isSemantics(
        label: 'Thu, Oct 29, day 2, 3 dives, deepest 30.2m',
        isButton: true,
        isSelected: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(TripDayPicker.dayTileKey(1))),
      isSemantics(
        label: 'Wed, Oct 28, day 1, 1 dive, deepest 30.2m',
        isButton: true,
        isSelected: false,
      ),
    );
  });

  testWidgets('a day with no dives says only its date and number', (
    tester,
  ) async {
    await pumpPicker(tester, days: six.story.days, model: six.model);

    expect(
      tester.getSemantics(find.byKey(TripDayPicker.dayTileKey(6))),
      isSemantics(label: 'Mon, Nov 2, day 6', isButton: true),
    );
  });

  testWidgets('the Trip tile says it opens the whole trip, selected when no '
      'day is', (tester) async {
    await pumpPicker(tester, days: six.story.days, model: six.model);

    expect(
      tester.getSemantics(find.byKey(TripDayPicker.tripTileKey)),
      isSemantics(label: 'Whole trip', isButton: true, isSelected: true),
    );
  });

  testWidgets("today's tile says Today", (tester) async {
    final underWay = _trip(DateTime(2026, 10, 28), [
      1, 3, 0, 0, 0, 0, //
    ], today: DateTime(2026, 10, 29, 12));
    await pumpPicker(tester, days: underWay.story.days, model: underWay.model);

    expect(
      tester.getSemantics(find.byKey(TripDayPicker.dayTileKey(2))),
      isSemantics(label: 'Thu, Oct 29, day 2, 3 dives, deepest 30.2m, Today'),
    );
  });

  testWidgets('a one-day trip has a Trip tile and one day tile', (
    tester,
  ) async {
    final one = _trip(DateTime(2026, 10, 28), [2]);
    await pumpPicker(tester, days: one.story.days, model: one.model);

    expect(find.byKey(TripDayPicker.tripTileKey), findsOneWidget);
    expect(find.byKey(TripDayPicker.dayTileKey(1)), findsOneWidget);
    expect(find.byKey(TripDayPicker.dayTileKey(2)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at text scale 2.0 nothing overflows', (tester) async {
    await pumpPicker(
      tester,
      days: six.story.days,
      model: six.model,
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    // The label is not clipped by its tile: the tile grew to hold it.
    final label = tester.getRect(find.text('Wed'));
    final tile = tester.getRect(find.byKey(TripDayPicker.dayTileKey(1)));
    expect(label.left, greaterThanOrEqualTo(tile.left - 0.5));
    expect(label.right, lessThanOrEqualTo(tile.right + 0.5));
  });

  testWidgets('in a right-to-left locale the Trip tile is at the start edge '
      'and days follow in reading order', (tester) async {
    await pumpPicker(
      tester,
      days: six.story.days,
      model: six.model,
      locale: const Locale('ar'),
    );

    final strip = tester.getRect(find.byKey(_stripKey));
    expect(
      tester.getRect(find.byKey(TripDayPicker.tripTileKey)).right,
      closeTo(strip.right, 0.5),
    );
    expect(
      tester.getRect(find.byKey(TripDayPicker.dayTileKey(1))).left,
      greaterThan(tester.getRect(find.byKey(TripDayPicker.dayTileKey(2))).left),
    );
  });

  testWidgets('the right arrow moves the selection to the next tile', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      days: six.story.days,
      model: six.model,
      selectedDate: six.story.days[1].date,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

    expect(selections, [six.story.days[2].date, six.story.days[0].date]);
  });

  testWidgets('the left arrow from the first day goes to the Trip tile, and '
      'stops there', (tester) async {
    await pumpPicker(
      tester,
      days: six.story.days,
      model: six.model,
      selectedDate: six.story.days[0].date,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

    expect(selections, [null]);
  });
}
