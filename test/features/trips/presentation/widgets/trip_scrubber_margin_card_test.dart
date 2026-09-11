import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';

const ccr = EquipmentItem(
  id: 'r1',
  name: 'My CCR',
  type: EquipmentType.rebreather,
);

Trip trip({bool past = false}) {
  final start = past
      ? DateTime(2025, 3, 1)
      : DateTime.now().add(const Duration(days: 10));
  return Trip(
    id: 't1',
    name: 'Trip',
    startDate: start,
    endDate: start.add(const Duration(days: 4)),
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

ScrubberMargin margin({
  double? rated = 300,
  double? marginAfter = -140,
  bool caution = true,
  int divesN = 0,
  int minutesN = 2,
  bool divesFromOverride = true,
  bool minutesFromOverride = false,
  int expectedDives = 10,
  DateTime? consumedSince,
  bool noRepack = false,
}) => ScrubberMargin(
  item: ccr,
  ratedMinutes: rated,
  consumedMinutes: 90,
  consumedSince: noRepack ? null : (consumedSince ?? DateTime(2025, 2, 1)),
  remainingBefore: rated == null ? 0 : 210,
  expectedDives: expectedDives,
  expectedDivesN: divesN,
  divesFromOverride: divesFromOverride,
  minutesFromOverride: minutesFromOverride,
  minutesPerDive: 35,
  minutesPerDiveN: minutesN,
  expectedUse: 350,
  marginAfter: marginAfter,
  caution: caution,
);

Widget host(List<ScrubberMargin> margins, {bool past = false}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    tripScrubberMarginsProvider('t1').overrideWith((ref) async => margins),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: TripScrubberMarginCard(trip: trip(past: past)),
    ),
  ),
);

void main() {
  // formatDate resolves DateFormat against Intl.defaultLocale, a process
  // global the app assigns from the diver's locale and a widget test never
  // sets. Left alone, the "as of Mar 1, 2025" assertion below would rest on
  // whatever the machine's default happens to be.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  testWidgets('states the four figures with their n and the caution', (
    tester,
  ) async {
    await tester.pumpWidget(host([margin()]));
    await tester.pumpAndSettle();
    expect(find.text('Scrubber margin'), findsOneWidget);
    expect(find.text('My CCR'), findsOneWidget);
    expect(
      find.text(
        '210 min left before the trip (rated 300 min, 90 min used since the last repack)',
      ),
      findsOneWidget,
    );
    expect(find.text('10 expected dives (set on this trip)'), findsOneWidget);
    expect(
      // Loop history includes SCR dives, so the source says rebreather.
      find.text('35 min per dive (from your last 2 rebreather dives)'),
      findsOneWidget,
    );
    expect(find.text('350 min expected use'), findsOneWidget);
    expect(find.text('-140 min margin after the trip'), findsOneWidget);
    expect(find.textContaining('Under 20 percent'), findsOneWidget);
  });

  testWidgets('estimated dives name the trips behind them, no caution line', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        margin(
          marginAfter: 100,
          caution: false,
          divesN: 3,
          divesFromOverride: false,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('10 expected dives (from your last 3 trips)'),
      findsOneWidget,
    );
    expect(find.textContaining('Under 20 percent'), findsNothing);
  });

  testWidgets('with no repack known the used minutes say so', (tester) async {
    // The consumed minutes then count every loop dive on the unit, which
    // "since the last repack" would misstate for a first-use scrubber.
    await tester.pumpWidget(host([margin(noRepack: true)]));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '210 min left before the trip (rated 300 min, 90 min used, no repack recorded)',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('since the last repack'), findsNothing);
  });

  testWidgets('a count of one reads in the singular', (tester) async {
    await tester.pumpWidget(
      host([
        margin(
          expectedDives: 1,
          divesN: 1,
          minutesN: 1,
          divesFromOverride: false,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 expected dive (from your last trip)'), findsOneWidget);
    expect(
      find.text('35 min per dive (from your last rebreather dive)'),
      findsOneWidget,
    );
  });

  testWidgets('a margin just under zero keeps its sign', (tester) async {
    // Rounding a shortfall to "0 min" would read as breaking even. A
    // margin below zero is always shown as a shortfall.
    await tester.pumpWidget(host([margin(marginAfter: -0.4)]));
    await tester.pumpAndSettle();
    expect(find.text('0 min margin after the trip'), findsNothing);
    expect(find.text('-1 min margin after the trip'), findsOneWidget);
  });

  test('the banner summary keeps a small shortfall negative', () {
    final l10n = AppLocalizationsEn();
    expect(
      tripScrubberMarginSummary(l10n, [margin(marginAfter: -0.4)]),
      '-1 min scrubber margin',
    );
  });

  testWidgets('a past trip says as of its start', (tester) async {
    await tester.pumpWidget(host([margin()], past: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('as of Mar 1, 2025'), findsOneWidget);
  });

  testWidgets('no rating shows the hint instead of a margin', (tester) async {
    await tester.pumpWidget(
      host([margin(rated: null, marginAfter: null, caution: false)]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No rated duration'), findsOneWidget);
    expect(find.textContaining('margin after'), findsNothing);
  });

  testWidgets('many rebreathers on a short window leave room for the page', (
    tester,
  ) async {
    // The card sits above the page's scrolling content, so it must never
    // take the whole window: several units on a compact screen scroll
    // inside the card instead of overflowing the page.
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripScrubberMarginsProvider(
            't1',
          ).overrideWith((ref) async => [for (var i = 0; i < 6; i++) margin()]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                TripScrubberMarginCard(trip: trip()),
                const Expanded(child: SizedBox(key: ValueKey('page-body'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final card = tester.getSize(find.byType(TripScrubberMarginCard));
    expect(card.height, lessThanOrEqualTo(600 * 0.4 + 1));
    expect(
      tester.getSize(find.byKey(const ValueKey('page-body'))).height,
      greaterThan(0),
    );
  });

  testWidgets('no rebreather renders nothing', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  test('the banner summary picks the lowest margin', () {
    final l10n = AppLocalizationsEn();
    expect(
      tripScrubberMarginSummary(l10n, [margin()]),
      '-140 min scrubber margin',
    );
    expect(
      tripScrubberMarginSummary(l10n, [
        margin(marginAfter: 50),
        margin(marginAfter: 20),
      ]),
      '2 rebreathers, lowest 20 min scrubber margin',
    );
    expect(
      tripScrubberMarginSummary(l10n, [margin(rated: null, marginAfter: null)]),
      isNull,
    );
  });

  testWidgets('a fallback with no history claims no source', (tester) async {
    // n is 0 for a default too, so keying the "(set on this trip)" suffix
    // off n told a diver with no trip history that they had set a figure
    // they never touched.
    await tester.pumpWidget(
      host([
        margin(
          divesN: 0,
          divesFromOverride: false,
          minutesN: 0,
          minutesFromOverride: false,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('10 expected dives'), findsOneWidget);
    expect(find.textContaining('set on this trip'), findsNothing);
    expect(find.textContaining('from your last'), findsNothing);
  });

  test('the banner counts every rebreather, rated or not', () {
    // The lowest margin comes from the rated units, but the count names
    // all of them: the card beneath shows a block for each.
    final summary = tripScrubberMarginSummary(AppLocalizationsEn(), [
      margin(marginAfter: 40, caution: false),
      margin(rated: null, marginAfter: null, caution: false),
    ]);
    expect(summary, '2 rebreathers, lowest 40 min scrubber margin');
  });
}
