import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_scale_layout.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_card.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_scale.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 58 dives 30 days apart from 10 Jan 2021, 110 m each: 6,380 m in all,
/// 5 of them estimated from max depth.
final _timeline = VerticalDistanceTimeline([
  for (var i = 0; i < 58; i++)
    DiveVerticalDistance(
      diveId: 'd$i',
      startMillis: DateTime.utc(
        2021,
        1,
        10,
      ).add(Duration(days: 30 * i)).millisecondsSinceEpoch,
      meters: 110,
      estimated: i < 5,
    ),
]);

/// A new timeline object holding the same dives, as a provider refresh gives.
VerticalDistanceTimeline _copy(VerticalDistanceTimeline t) =>
    VerticalDistanceTimeline([
      for (var i = 0; i < 58; i++)
        DiveVerticalDistance(
          diveId: 'd$i',
          startMillis: DateTime.utc(
            2021,
            1,
            10,
          ).add(Duration(days: 30 * i)).millisecondsSinceEpoch,
          meters: 110,
          estimated: i < 5,
        ),
    ]);

const _scaleKey = Key('verticalScale');
const _stripKey = Key('verticalStrip');
const _openKey = Key('verticalOpenDive');

/// The total ascent and descent card (issue #4569).
void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(
    WidgetTester tester, {
    VerticalDistanceTimeline? timeline,
    AppSettings settings = const AppSettings(),
    double width = 1000,
    Locale locale = const Locale('en'),
    Widget card = const VerticalDistanceCard(),
    VerticalDistanceTimeline? maxDepths,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.all(16), child: card),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Text('dive ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verticalDistanceTimelineProvider.overrideWith(
            (ref) async => timeline ?? _copy(_timeline),
          ),
          maxDepthTimelineProvider.overrideWith(
            (ref) async => maxDepths ?? VerticalDistanceTimeline.empty,
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => _MockSettingsNotifier(settings),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final layout = VerticalScaleLayout.compute(
    totalMeters: 6380,
    halfHeightPx: kVerticalScaleHalfHeight,
  );
  const units = UnitFormatter(AppSettings());
  String dateOf(double meters) => units.formatDate(
    wallClockUtcFromMillis(_timeline.crossingAt(meters)!.startMillis),
  );

  /// The bar's centre at [offset] px from sea level (negative is up).
  Offset at(WidgetTester tester, double offset) {
    final origin = tester.getTopLeft(find.byKey(_scaleKey));
    final size = tester.getSize(find.byKey(_scaleKey));
    return Offset(
      origin.dx + size.width / 2,
      origin.dy + kVerticalScaleHeight / 2 + offset,
    );
  }

  String stripText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(_stripKey), matching: find.byType(Text)),
      )
      .first
      .data!;

  Future<TestGesture> mouse(WidgetTester tester) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    return g;
  }

  testWidgets('headlines show the total each way', (tester) async {
    await pump(tester);

    expect(find.text('6,380 m'), findsNWidgets(2));
    expect(find.text('total ascent'), findsOneWidget);
    expect(find.text('total descent'), findsOneWidget);
    expect(find.text('Next: Aconcagua'), findsOneWidget);
    expect(find.text('581 m to go'), findsOneWidget);
  });

  testWidgets('on feet every figure is in feet', (tester) async {
    await pump(tester, settings: const AppSettings(depthUnit: DepthUnit.feet));

    expect(find.text('20,932 ft'), findsNWidgets(2));
    // Denali, the most recently passed and so always labelled: 6,190 m =
    // 20,308 ft.
    expect(find.text('Denali'), findsOneWidget);
    expect(find.text('20,308 ft'), findsOneWidget);
    // No figure anywhere reads in metres.
    final metres = RegExp(r'\d m\b');
    expect(
      find.byWidgetPredicate((w) => w is Text && metres.hasMatch(w.data ?? '')),
      findsNothing,
    );
  });

  testWidgets('the info sheet writes the deadband like the card figures', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('ignoring wobble under 1 m.'), findsOneWidget);
  });

  testWidgets('says how many dives were estimated', (tester) async {
    await pump(tester);
    expect(find.text('5 of 58 dives counted from max depth'), findsOneWidget);
  });

  testWidgets('no estimated dives, no note', (tester) async {
    await pump(
      tester,
      timeline: VerticalDistanceTimeline([
        const DiveVerticalDistance(
          diveId: 'a',
          startMillis: 0,
          meters: 30,
          estimated: false,
        ),
      ]),
    );
    expect(find.textContaining('counted from max depth'), findsNothing);
  });

  testWidgets('hovering a bar reads the date the level was reached', (
    tester,
  ) async {
    await pump(tester);
    expect(stripText(tester), 'Point at a bar to see when you got there');

    final g = await mouse(tester);
    await g.moveTo(at(tester, 100));
    await tester.pump();

    final meters = layout.metersAt(100);
    expect(
      stripText(tester),
      '${units.formatDepthWhole(meters)} of descent, reached ${dateOf(meters)}',
    );
    expect(find.byKey(_openKey), findsOneWidget);

    await g.moveTo(at(tester, -100));
    await tester.pump();
    expect(stripText(tester), startsWith(units.formatDepthWhole(meters)));
    expect(stripText(tester), contains('of ascent, reached'));

    // Off the bars, back to idle.
    final origin = tester.getTopLeft(find.byKey(_scaleKey));
    await g.moveTo(origin + const Offset(4, 4));
    await tester.pump();
    expect(stripText(tester), 'Point at a bar to see when you got there');
    expect(find.byKey(_openKey), findsNothing);
  });

  testWidgets('a click pins the level until a click away from the bars', (
    tester,
  ) async {
    await pump(tester);
    final g = await mouse(tester);
    await g.moveTo(at(tester, 100));
    await g.down(at(tester, 100));
    await g.up();
    await tester.pump();
    final pinned = stripText(tester);
    expect(find.text('Pinned'), findsOneWidget);

    await g.moveTo(at(tester, 150));
    await tester.pump();
    expect(stripText(tester), pinned);

    final origin = tester.getTopLeft(find.byKey(_scaleKey));
    await g.moveTo(origin + const Offset(4, 4));
    await g.down(origin + const Offset(4, 4));
    await g.up();
    await tester.pump();
    expect(stripText(tester), 'Point at a bar to see when you got there');
    expect(find.text('Pinned'), findsNothing);
  });

  testWidgets('a touch tap on a bar pins that level', (tester) async {
    await pump(tester);
    await tester.tapAt(at(tester, 100));
    await tester.pump();

    expect(stripText(tester), contains('of descent, reached'));
    expect(find.text('Pinned'), findsOneWidget);
  });

  testWidgets('hold then drag scrubs, and the level stays', (tester) async {
    await pump(tester);
    final g = await tester.startGesture(at(tester, 50));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveTo(at(tester, 130));
    await tester.pump();
    await g.up();
    await tester.pump();

    // 130 px is clear of every landmark's snap range.
    final meters = layout.metersAt(130);
    expect(stripText(tester), startsWith(units.formatDepthWhole(meters)));
    expect(find.text('Pinned'), findsOneWidget);
  });

  testWidgets('a swipe that starts on a bar scrolls the page', (tester) async {
    await pump(tester);
    await tester.dragFrom(at(tester, 50), const Offset(0, -300));
    await tester.pumpAndSettle();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, greaterThan(0));
    expect(stripText(tester), 'Point at a bar to see when you got there');
  });

  testWidgets('near a passed landmark the readout names it', (tester) async {
    await pump(tester);
    final g = await mouse(tester);
    await g.moveTo(at(tester, layout.offsetFor(3800) + 2));
    await tester.pump();

    expect(stripText(tester), 'Titanic: passed ${dateOf(3800)}');
    expect(find.byKey(_openKey), findsOneWidget);
  });

  testWidgets('the next landmark says how far away it is', (tester) async {
    await pump(tester);
    final g = await mouse(tester);
    await g.moveTo(at(tester, -layout.offsetFor(6961)));
    await tester.pump();

    expect(stripText(tester), 'Aconcagua: 581 m to go');
    expect(find.byKey(_openKey), findsNothing);
  });

  testWidgets('Open dive goes to the dive that reached the level', (
    tester,
  ) async {
    await pump(tester);
    await tester.tapAt(at(tester, 100));
    await tester.pump();
    final id = _timeline.crossingAt(layout.metersAt(100))!.diveId;

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    expect(find.text('dive $id'), findsOneWidget);
  });

  testWidgets('no dives with a depth shows the empty state', (tester) async {
    await pump(tester, timeline: VerticalDistanceTimeline.empty);

    expect(find.text('No dives with a depth yet'), findsOneWidget);
    expect(find.byKey(_scaleKey), findsNothing);
  });

  testWidgets('fits a narrow phone', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
    expect(find.byKey(_scaleKey), findsOneWidget);
    // A long name gives way before its figure does: the whale's 2,992 m
    // stays whole even where the name is cut short.
    expect(find.text('2,992 m'), findsOneWidget);
  });

  testWidgets('on a phone the headline keeps its distance whole', (
    tester,
  ) async {
    await pump(tester, width: 320);
    // Next down is the deepest shipwreck (6,865), 485 m away.
    expect(find.text('485 m to go'), findsOneWidget);
    expect(find.text('Next: Deepest shipwreck'), findsOneWidget);
  });

  testWidgets('on a phone a pinned level leaves the strip room for its date', (
    tester,
  ) async {
    await pump(tester, width: 320);
    await tester.tapAt(at(tester, 100));
    await tester.pump();

    // The border marks the pin; no chip takes the text's room.
    expect(find.text('Pinned'), findsNothing);
    // The test font draws every glyph as a full square, so the text cannot
    // be measured as a reader sees it. Check the room it gets instead:
    // 180 px is two lines of about 30 characters each in the app's font,
    // enough for a level and a date in every locale.
    final text = find.descendant(
      of: find.byKey(_stripKey),
      matching: find.byType(Text),
    );
    expect(tester.getSize(text.first).width, greaterThanOrEqualTo(180));
    expect(find.byKey(_openKey), findsOneWidget);
  });

  testWidgets('a scrub keeps reading the bar when the thumb drifts sideways', (
    tester,
  ) async {
    await pump(tester);
    final g = await tester.startGesture(at(tester, 50));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveTo(at(tester, 130) + const Offset(60, 0));
    await tester.pump();
    await g.up();
    await tester.pump();

    final meters = layout.metersAt(130);
    expect(stripText(tester), startsWith(units.formatDepthWhole(meters)));
  });

  testWidgets('a tap anywhere else on the card unpins', (tester) async {
    await pump(tester);
    await tester.tapAt(at(tester, 100));
    await tester.pump();
    expect(find.text('Pinned'), findsOneWidget);

    await tester.tap(find.text('5 of 58 dives counted from max depth'));
    await tester.pump();
    expect(stripText(tester), 'Point at a bar to see when you got there');
  });

  testWidgets('on a short bar the ascent headline stays clear of sea level', (
    tester,
  ) async {
    await pump(
      tester,
      width: 320,
      timeline: VerticalDistanceTimeline([
        const DiveVerticalDistance(
          diveId: 'a',
          startMillis: 0,
          meters: 50,
          estimated: false,
        ),
      ]),
    );
    final seaLevel = tester.getRect(find.text('Sea level'));
    final ascentToGo = tester.getRect(find.textContaining('to go').first);
    expect(ascentToGo.bottom, lessThanOrEqualTo(seaLevel.top));
  });

  testWidgets('a pinned level survives a refresh with the same dives', (
    tester,
  ) async {
    await pump(tester);
    await tester.tapAt(at(tester, 100));
    await tester.pump();
    final pinned = stripText(tester);

    ProviderScope.containerOf(
      tester.element(find.byType(VerticalDistanceCard)),
    ).invalidate(verticalDistanceTimelineProvider);
    await tester.pumpAndSettle();

    expect(stripText(tester), pinned);
    expect(find.text('Pinned'), findsOneWidget);
  });

  /// Shows [card] still loading: both timelines wait on [pending], so a
  /// test can measure the loading state and then complete it.
  Future<void> pumpLoading(
    WidgetTester tester,
    Widget card,
    Completer<VerticalDistanceTimeline> pending,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verticalDistanceTimelineProvider.overrideWith(
            (ref) => pending.future,
          ),
          maxDepthTimelineProvider.overrideWith((ref) => pending.future),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => _MockSettingsNotifier(const AppSettings()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ),
    );
    await tester.pump();
  }

  double cardHeight(WidgetTester tester) =>
      tester.getSize(find.byType(VerticalDistanceCard)).height;

  testWidgets('the card keeps its height from loading to loaded', (
    tester,
  ) async {
    final pending = Completer<VerticalDistanceTimeline>();
    await pumpLoading(tester, const VerticalDistanceCard(), pending);
    final loading = cardHeight(tester);

    pending.complete(_timeline);
    await tester.pumpAndSettle();

    expect(cardHeight(tester), loading);
  });

  testWidgets('a pinned strip fits large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, width: 320);
    await tester.tapAt(at(tester, 100));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out right to left', (tester) async {
    await pump(tester, width: 320, locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
    expect(find.byKey(_scaleKey), findsOneWidget);
  });

  testWidgets('screen readers get the summary and every passed landmark', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(
      find.bySemanticsLabel(RegExp(r'^Total ascent and descent 6,380 m each')),
      findsOneWidget,
    );
    final titanic = find.bySemanticsLabel(RegExp(r'^Titanic: passed'));
    expect(titanic, findsOneWidget);
    expect(tester.getSemantics(titanic), isSemantics(hasTapAction: true));
    handle.dispose();
  });

  group('max depths added up', () {
    final twoDives = VerticalDistanceTimeline([
      for (final (i, id) in ['a', 'b'].indexed)
        DiveVerticalDistance(
          diveId: id,
          startMillis: DateTime.utc(2024, 1, 1 + i).millisecondsSinceEpoch,
          meters: 15,
          estimated: false,
        ),
    ]);

    testWidgets('reads its own timeline under its own title', (tester) async {
      await pump(
        tester,
        card: const VerticalDistanceCard.maxDepths(),
        maxDepths: twoDives,
      );

      expect(find.text('Max Depths Added Up'), findsOneWidget);
      expect(
        find.text('Each dive straight down to its deepest point and back'),
        findsOneWidget,
      );
      expect(find.text('30 m'), findsNWidgets(2));
      expect(find.text('6,380 m'), findsNothing);
    });

    testWidgets('it reserves no note row, from loading to loaded', (
      tester,
    ) async {
      await pump(tester, timeline: twoDives);
      final withNoteRow = cardHeight(tester);
      // A fresh scope, not the same one with a different set of overrides.
      await tester.pumpWidget(const SizedBox());

      final pending = Completer<VerticalDistanceTimeline>();
      await pumpLoading(
        tester,
        const VerticalDistanceCard.maxDepths(),
        pending,
      );
      final loading = cardHeight(tester);
      pending.complete(twoDives);
      await tester.pumpAndSettle();

      expect(cardHeight(tester), loading);
      expect(cardHeight(tester), withNoteRow - 8 - kVerticalNoteHeight);
    });

    testWidgets('an estimated dive still gets its note', (tester) async {
      await pump(
        tester,
        card: const VerticalDistanceCard.maxDepths(),
        maxDepths: VerticalDistanceTimeline([
          const DiveVerticalDistance(
            diveId: 'a',
            startMillis: 0,
            meters: 15,
            estimated: true,
          ),
          const DiveVerticalDistance(
            diveId: 'b',
            startMillis: 1,
            meters: 15,
            estimated: false,
          ),
        ]),
      );

      expect(find.text('1 of 2 dives counted from max depth'), findsOneWidget);
    });

    testWidgets('its info sheet says only the deepest point counts', (
      tester,
    ) async {
      await pump(
        tester,
        card: const VerticalDistanceCard.maxDepths(),
        maxDepths: twoDives,
      );
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('ignoring every change of depth along the way'),
        findsOneWidget,
      );
    });
  });
}
