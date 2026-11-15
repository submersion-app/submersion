import 'package:flutter/gestures.dart';
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
    ValueNotifier<DateTime?>? selection,
  }) async {
    // Dates are formatted against Intl.defaultLocale, a process global the
    // app sets from its own locale. Pin it and put it back.
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = locale.languageCode;
    addTearDown(() => Intl.defaultLocale = previousLocale);

    Widget picker(DateTime? selected) => TripDayPicker(
      days: days,
      model: model,
      selectedDate: selected,
      onSelect: selections.add,
    );
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
                    child: selection == null
                        ? picker(selectedDate)
                        : ValueListenableBuilder<DateTime?>(
                            valueListenable: selection,
                            builder: (_, selected, _) => picker(selected),
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
    // The tiles grew with the text, so the labels are larger, not squeezed:
    // six days no longer fit 320 points and each keeps twice its minimum.
    final tile = tester.getRect(find.byKey(TripDayPicker.dayTileKey(1)));
    expect(tile.width, closeTo(TripDayPicker.minDayTileWidth * 2, 0.5));
    expect(
      tester.getSize(find.byKey(TripDayPicker.tripTileKey)).width,
      closeTo(TripDayPicker.tripTileWidth * 2, 0.5),
    );
    final label = tester.getRect(find.text('Wed'));
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

  group('keyboard focus', () {
    /// Whether the focused control is inside the tile with [key].
    bool focusIsIn(WidgetTester tester, Key key) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      final tile = tester.element(find.byKey(key));
      var inside = false;
      focused.visitAncestorElements((ancestor) {
        inside = ancestor == tile;
        return !inside;
      });
      return inside;
    }

    testWidgets('the strip is one tab stop, on the selected tile', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        days: six.story.days,
        model: six.model,
        selectedDate: six.story.days[2].date,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(3)), isTrue);

      // Nothing else on this screen takes focus, so a second Tab comes back
      // round to the same tile: no other tile is a stop on the way.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(3)), isTrue);
    });

    testWidgets('with the Trip tile selected, it is the tab stop', (
      tester,
    ) async {
      await pumpPicker(tester, days: six.story.days, model: six.model);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.tripTileKey), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.tripTileKey), isTrue);
    });

    testWidgets('an arrow key takes the focus along with the selection', (
      tester,
    ) async {
      final selection = ValueNotifier<DateTime?>(six.story.days[1].date);
      addTearDown(selection.dispose);
      await pumpPicker(
        tester,
        days: six.story.days,
        model: six.model,
        selection: selection,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(2)), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      selection.value = selections.last;
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(3)), isTrue);

      // And the stop moved with it: Tab comes back to the new tile.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(3)), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      selection.value = selections.last;
      await tester.pump();
      // Two steps back from day 3 is day 1; the second was taken from the
      // tile the first one focused.
      expect(selections.last, six.story.days[1].date);
    });

    testWidgets('focus stays on its day when days are added in front', (
      tester,
    ) async {
      // A dive logged two days before the trip adds two leading days.
      final longer = _trip(DateTime(2026, 10, 26), [1, 1, 1, 3, 3, 2, 1, 0]);
      final shown = ValueNotifier(six);
      addTearDown(shown.dispose);
      final selected = six.story.days[2].date;
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: shown,
                builder: (_, trip, _) => TripDayPicker(
                  days: trip.story.days,
                  model: trip.model,
                  selectedDate: selected,
                  onSelect: selections.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(3)), isTrue);

      shown.value = longer;
      await tester.pump();
      await tester.pump();

      // The same date is day 5 now, and the focus went with it.
      expect(longer.story.days[4].date, selected);
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(5)), isTrue);
      // An arrow key still moves on from the day that has focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(selections.last, longer.story.days[5].date);
    });

    testWidgets('when the focused day goes, the focus stays in the strip', (
      tester,
    ) async {
      final shown = ValueNotifier(six);
      addTearDown(shown.dispose);
      final selected = six.story.days[5].date;
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: shown,
                builder: (_, trip, _) => TripDayPicker(
                  days: trip.story.days,
                  model: trip.model,
                  selectedDate: selected,
                  onSelect: selections.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(6)), isTrue);

      // The trip is cut to its first three days: day 6 is gone.
      shown.value = _trip(DateTime(2026, 10, 28), [1, 3, 3]);
      await tester.pump();
      await tester.pump();

      // With no day of its own selected, the Trip tile is the tab stop.
      expect(focusIsIn(tester, TripDayPicker.tripTileKey), isTrue);
    });

    testWidgets('a trip that loses days keeps a tab stop', (tester) async {
      final days = ValueNotifier(fourteen.story.days);
      addTearDown(days.dispose);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: days,
                builder: (_, shown, _) => TripDayPicker(
                  days: shown,
                  model: TripPickerModel(
                    days: [
                      for (final day in shown)
                        TripPickerDay(date: day.date, dives: const []),
                    ],
                    maxDepth: 0,
                    widestDaySeconds: 0,
                  ),
                  selectedDate: shown.first.date,
                  onSelect: selections.add,
                ),
              ),
            ),
          ),
        ),
      );

      days.value = fourteen.story.days.sublist(0, 3);
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(focusIsIn(tester, TripDayPicker.dayTileKey(1)), isTrue);
    });
  });

  group('a strip longer than its space', () {
    testWidgets('keeps the selected day in view when days are added in '
        'front of it', (tester) async {
      // A dive logged two days before the trip adds two leading days: every
      // tile moves two places along, the selected one included.
      final counts = [1, 3, 3, 2, 3, 0, 2, 3, 3, 2, 3, 1, 2, 0];
      final longer = _trip(DateTime(2026, 10, 15), [1, 1, ...counts]);
      final shown = ValueNotifier(fourteen);
      addTearDown(shown.dispose);
      final selected = fourteen.story.days[12].date;
      final previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'en';
      addTearDown(() => Intl.defaultLocale = previousLocale);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  key: _stripKey,
                  width: 360,
                  child: ValueListenableBuilder(
                    valueListenable: shown,
                    builder: (_, trip, _) => TripDayPicker(
                      days: trip.story.days,
                      model: trip.model,
                      selectedDate: selected,
                      onSelect: selections.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final strip = tester.getRect(find.byKey(_stripKey));
      bool inView(int dayNumber) {
        final tile = tester.getRect(
          find.byKey(TripDayPicker.dayTileKey(dayNumber)),
        );
        return tile.left >= strip.left - 0.5 && tile.right <= strip.right + 0.5;
      }

      expect(inView(13), isTrue, reason: 'opens with the selected day shown');

      shown.value = longer;
      await tester.pump();
      await tester.pumpAndSettle();

      // The same date is day 15 now.
      expect(longer.story.days[14].date, selected);
      expect(inView(15), isTrue);
    });

    testWidgets('choosing a day that is off screen brings it into view', (
      tester,
    ) async {
      final selection = ValueNotifier<DateTime?>(null);
      addTearDown(selection.dispose);
      await pumpPicker(
        tester,
        days: fourteen.story.days,
        model: fourteen.model,
        selection: selection,
      );
      final strip = tester.getRect(find.byKey(_stripKey));
      expect(
        tester.getRect(find.byKey(TripDayPicker.dayTileKey(13))).left,
        greaterThan(strip.right),
        reason: 'day 13 starts off screen',
      );

      selection.value = fourteen.story.days[12].date;
      await tester.pumpAndSettle();

      final chosen = tester.getRect(find.byKey(TripDayPicker.dayTileKey(13)));
      expect(chosen.right, lessThanOrEqualTo(strip.right + 0.5));
      expect(
        chosen.left,
        greaterThanOrEqualTo(strip.left + TripDayPicker.tripTileWidth),
      );
    });

    testWidgets('can be dragged with a mouse', (tester) async {
      await pumpPicker(
        tester,
        days: fourteen.story.days,
        model: fourteen.model,
      );
      final before = tester.getRect(find.byKey(TripDayPicker.dayTileKey(3)));

      await tester.drag(
        find.byKey(TripDayPicker.dayTileKey(3)),
        const Offset(-150, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(TripDayPicker.dayTileKey(3))).left,
        lessThan(before.left - 100),
      );
    });

    testWidgets('fades at each edge where there is more to see', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        days: fourteen.story.days,
        model: fourteen.model,
      );
      await tester.pump();
      expect(find.byKey(TripDayPicker.moreAfterKey), findsOneWidget);
      expect(find.byKey(TripDayPicker.moreBeforeKey), findsNothing);

      await tester.drag(
        find.byKey(TripDayPicker.dayTileKey(3)),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(TripDayPicker.moreBeforeKey), findsOneWidget);
      expect(find.byKey(TripDayPicker.moreAfterKey), findsOneWidget);
    });

    testWidgets('a strip that fits has no fade', (tester) async {
      await pumpPicker(tester, days: six.story.days, model: six.model);
      await tester.pump();

      expect(find.byKey(TripDayPicker.moreAfterKey), findsNothing);
      expect(find.byKey(TripDayPicker.moreBeforeKey), findsNothing);
    });
  });

  group('every tile is the same height, whatever its label needs', () {
    // A label too wide for its tile is scaled down. That must not make its
    // tile shorter: the surface line is the picture's baseline, and a
    // staggered baseline makes depths impossible to compare across days.
    for (final language in ['fr', 'ar', 'de']) {
      testWidgets('in $language, on a 14 day trip', (tester) async {
        await pumpPicker(
          tester,
          days: fourteen.story.days,
          model: fourteen.model,
          locale: Locale(language),
        );

        final heights = {
          tester.getSize(find.byKey(TripDayPicker.tripTileKey)).height,
          for (var day = 1; day <= 14; day++)
            tester.getSize(find.byKey(TripDayPicker.dayTileKey(day))).height,
        };
        expect(heights, hasLength(1), reason: 'heights: $heights');
        final tops = {
          for (var day = 1; day <= 14; day++)
            tester.getRect(find.byKey(TripDayPicker.dayTileKey(day))).top,
        };
        expect(tops, hasLength(1));
      });
    }
  });
}
