import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/key_numbers_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'panel_harness.dart';

final _full = HomeKeyNumbers(
  careerDives: 412,
  careerTimeSeconds: 386 * 3600,
  divesThisYear: 47,
  timeThisYearSeconds: 41 * 3600,
  monthlySeries: const [2, 0, 4, 9, 3, 0, 5, 2, 7, 1, 3, 11],
  daysSinceLastDive: 12,
  lastDiveId: 'd412',
  lastDiveSite: 'Salt Pier',
  avgSac: 14.2,
  avgSacChange: -0.6,
  sacSeries: const [15, 14.8, 14.5, 14.2],
  deepestThisYear: 42.1,
  deepestLastYear: 38,
  nextTrip: Trip(
    id: 't1',
    name: 'Bonaire',
    startDate: DateTime.now().add(const Duration(days: 23)),
    endDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  tripChecklistDone: 6,
  tripChecklistTotal: 14,
  avgDepthThisYear: 21,
  avgDepthLastYear: 19.6,
  species: 143,
  newSpeciesThisYear: 12,
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  HomeKeyNumbers? numbers,
  AppSettings settings = const AppSettings(),
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        homeKeyNumbersProvider.overrideWith((ref) async => numbers ?? _full),
      ].cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                final tier = homeWidthTierOf(context);
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: KeyNumbersPanel.heightFor(
                      context,
                      tier,
                      KeyNumbersPanel.visibleTileCount(
                        numbers ?? _full,
                        settings.hiddenHomeKeyNumbers,
                      ),
                    ),
                    child: const KeyNumbersPanel(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  test('tiles per row follow the tier', () {
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.desktop, 6), 6);
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.tablet, 6), 3);
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.tablet, 4), 4);
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.phone, 6), 2);
  });

  testWidgets('desktop shows the six default tiles', (tester) async {
    await _pump(tester, width: 1280);
    for (final title in [
      'DIVES',
      'TIME UNDER',
      'LAST DIVE',
      'AVG RMV',
      'SPECIES',
      'NEXT TRIP',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('DEEPEST THIS YEAR'), findsNothing);
    // In the deepest tile's old place: after the gas tile, before the trip.
    final species = tester.getTopLeft(find.text('SPECIES')).dx;
    expect(species, greaterThan(tester.getTopLeft(find.text('AVG RMV')).dx));
    expect(species, lessThan(tester.getTopLeft(find.text('NEXT TRIP')).dx));
    expect(find.text('412'), findsOneWidget);
    expect(find.text('+47 this year'), findsOneWidget);
  });

  testWidgets('one day reads as a day, not days', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: HomeKeyNumbers(
        careerDives: 3,
        careerTimeSeconds: 3 * 3600,
        daysSinceLastDive: 1,
        lastDiveId: 'd3',
        nextTrip: Trip(
          id: 't1',
          name: 'Bonaire',
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 8)),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    expect(find.text('1 day'), findsNWidgets(2));
    expect(find.text('1 days'), findsNothing);
  });

  testWidgets('hours this year keep a decimal under ten, as the total does', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(
        careerDives: 1,
        careerTimeSeconds: 45 * 60,
        timeThisYearSeconds: 45 * 60,
      ),
    );
    expect(find.text('0.8 h'), findsOneWidget);
    expect(find.text('+0.8 h this year'), findsOneWidget);
  });

  testWidgets('a gas change that rounds to nothing carries no sign', (
    tester,
  ) async {
    for (final change in [0.03, -0.04]) {
      await _pump(
        tester,
        width: 1280,
        numbers: HomeKeyNumbers(
          careerDives: 30,
          careerTimeSeconds: 30 * 3600,
          avgSac: 14.2,
          avgSacChange: change,
        ),
      );
      expect(
        find.text('0.0 vs previous 10'),
        findsOneWidget,
        reason: '$change',
      );
    }
  });

  testWidgets('a tile with nothing to say is left out', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(careerDives: 0, careerTimeSeconds: 0),
    );
    expect(find.text('DIVES'), findsOneWidget);
    expect(find.text('TIME UNDER'), findsOneWidget);
    expect(find.text('LAST DIVE'), findsNothing);
    expect(find.text('AVG RMV'), findsNothing);
    expect(find.text('NEXT TRIP'), findsNothing);
  });

  testWidgets('switching tiles on shows them', (tester) async {
    await _pump(
      tester,
      width: 1280,
      settings: const AppSettings(hiddenHomeKeyNumbers: {}),
    );
    expect(find.text('DEEPEST THIS YEAR'), findsOneWidget);
    expect(find.text('AVG DEPTH'), findsOneWidget);
  });

  testWidgets('imperial units show feet', (tester) async {
    await _pump(
      tester,
      width: 1280,
      // The depth tiles are off by default; switched on to show feet.
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        hiddenHomeKeyNumbers: {},
      ),
    );
    expect(find.textContaining('ft'), findsWidgets);
  });

  testWidgets('a SAC-only diver sees bar a minute', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(
        careerDives: 1,
        careerTimeSeconds: 1,
        avgSac: 1.2,
        sacLane: GasConsumptionLane.sac,
      ),
    );
    expect(find.text('AVG SAC'), findsOneWidget);
    expect(find.textContaining('bar/min'), findsOneWidget);
  });

  testWidgets('no overflow at text scale 2 on a phone', (tester) async {
    await _pump(
      tester,
      width: 390,
      textScale: 2,
      settings: const AppSettings(hiddenHomeKeyNumbers: {}),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a SAC that went up is not drawn as a gain', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(
        careerDives: 30,
        careerTimeSeconds: 100000,
        avgSac: 15,
        avgSacChange: 0.4,
      ),
    );
    final text = tester.widget<Text>(find.textContaining('+0.4'));
    final context = tester.element(find.textContaining('+0.4'));
    expect(text.style?.color, isNot(Theme.of(context).colorScheme.primary));
  });

  testWidgets('under ten hours shows a decimal', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(careerDives: 1, careerTimeSeconds: 2700),
    );
    expect(find.textContaining('0.8 h'), findsOneWidget);
  });

  // 9.97 hours rounds to ten, so it reads as ten hours do: no decimal.
  testWidgets('a total that rounds to ten hours shows no decimal', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(careerDives: 12, careerTimeSeconds: 35900),
    );
    expect(find.textContaining('10 h'), findsOneWidget);
    expect(find.textContaining('10.0'), findsNothing);
  });

  testWidgets('the trip checklist count comes before the trip name', (
    tester,
  ) async {
    await _pump(tester, width: 1280);
    expect(find.text('checklist 6/14 · Bonaire'), findsOneWidget);
  });

  testWidgets('RMV in cuft a minute keeps two places', (tester) async {
    await _pump(
      tester,
      width: 1280,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      numbers: const HomeKeyNumbers(
        careerDives: 30,
        careerTimeSeconds: 30 * 3600,
        avgSac: 16,
        avgSacChange: -0.85,
      ),
    );
    // 16 L/min is 0.565 cuft/min, and -0.85 L/min is -0.030.
    expect(find.text('0.57 cuft/min'), findsOneWidget);
    expect(find.text('-0.03 vs previous 10'), findsOneWidget);
  });

  testWidgets('SAC in psi a minute shows whole numbers', (tester) async {
    await _pump(
      tester,
      width: 1280,
      settings: const AppSettings(pressureUnit: PressureUnit.psi),
      numbers: const HomeKeyNumbers(
        careerDives: 30,
        careerTimeSeconds: 30 * 3600,
        avgSac: 1.2,
        sacLane: GasConsumptionLane.sac,
      ),
    );
    expect(find.text('17 psi/min'), findsOneWidget);
  });

  testWidgets('decimals follow the locale', (tester) async {
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = previous);
    await _pump(
      tester,
      width: 1280,
      settings: const AppSettings(hiddenHomeKeyNumbers: {}),
      numbers: const HomeKeyNumbers(
        careerDives: 30,
        careerTimeSeconds: 8 * 3600 + 30 * 60,
        deepestThisYear: 42.1,
      ),
    );
    expect(find.text('42,1 m'), findsOneWidget);
    expect(find.text('8,5 h'), findsOneWidget);
  });

  testWidgets('nothing logged this year leaves the year lines out', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(
        careerDives: 30,
        careerTimeSeconds: 30 * 3600,
        divesThisYear: 0,
        timeThisYearSeconds: 0,
      ),
    );
    expect(find.textContaining('this year'), findsNothing);
  });

  testWidgets('the last dive tile gives its site and date', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: HomeKeyNumbers(
        careerDives: 30,
        careerTimeSeconds: 30 * 3600,
        daysSinceLastDive: 12,
        lastDiveId: 'd30',
        lastDiveSite: 'Salt Pier',
        lastDiveDate: DateTime(2026, 11, 9),
      ),
    );
    expect(find.textContaining('Salt Pier · '), findsOneWidget);
  });

  testWidgets('the deepest tile names its dive and opens it', (tester) async {
    final nav = await pumpPanel(
      tester,
      const KeyNumbersPanel(),
      width: 1280,
      // Off by default; switched on to test it.
      settings: const AppSettings(hiddenHomeKeyNumbers: {}),
      overrides: [
        homeKeyNumbersProvider.overrideWith(
          (ref) async => const HomeKeyNumbers(
            careerDives: 30,
            careerTimeSeconds: 30 * 3600,
            deepestThisYear: 42,
            deepestLastYear: 38,
            deepestDiveId: 'd400',
            deepestDiveSite: 'Blue Hole',
          ),
        ),
      ],
    );
    expect(find.text('Blue Hole'), findsOneWidget);
    await tester.tap(find.text('DEEPEST THIS YEAR'));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives/d400');
  });

  testWidgets('time under opens the dive list', (tester) async {
    final nav = await pumpPanel(
      tester,
      const KeyNumbersPanel(),
      width: 1280,
      overrides: [
        homeKeyNumbersProvider.overrideWith(
          (ref) async =>
              const HomeKeyNumbers(careerDives: 30, careerTimeSeconds: 108000),
        ),
      ],
    );
    await tester.tap(find.text('TIME UNDER'));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives');
  });

  group('trend line lies inside the tile\'s content area', () {
    const sparse = HomeKeyNumbers(
      careerDives: 36,
      careerTimeSeconds: 74000,
      divesThisYear: 15,
      monthlySeries: [7, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0],
      avgSac: 14.4,
      sacSeries: [17, 15.5, 19.8, 14.2, 14.7, 13.6],
    );
    for (final width in [390.0, 1280.0]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('at width $width, text scale $scale', (tester) async {
          await _pump(
            tester,
            width: width,
            numbers: sparse,
            textScale: scale,
            // Only the tiles the numbers fill, so the loading frame's
            // placeholders match the box the harness sizes.
            settings: const AppSettings(
              hiddenHomeKeyNumbers: {
                'lastDive',
                'deepestThisYear',
                'nextTrip',
                'avgDepth',
                'species',
              },
            ),
          );
          final sparks = find.byType(HomeSparkline);
          expect(sparks, findsWidgets);
          for (final element in sparks.evaluate()) {
            final spark = tester.getRect(find.byWidget(element.widget));
            final panel = tester.getRect(
              find
                  .ancestor(
                    of: find.byWidget(element.widget),
                    matching: find.byType(HomePanel),
                  )
                  .first,
            );
            // The panel's bottom padding is 10; its content is clipped there.
            expect(spark.bottom, lessThanOrEqualTo(panel.bottom - 10));
            expect(spark.height, greaterThan(0));
          }
        });
      }
    }
  });

  test('the headline is phone-only and odd-only', () {
    expect(KeyNumbersPanel.headlineFirst(HomeWidthTier.phone, 5), isTrue);
    expect(KeyNumbersPanel.headlineFirst(HomeWidthTier.phone, 3), isTrue);
    expect(KeyNumbersPanel.headlineFirst(HomeWidthTier.phone, 1), isTrue);
    expect(KeyNumbersPanel.headlineFirst(HomeWidthTier.phone, 4), isFalse);
    expect(KeyNumbersPanel.headlineFirst(HomeWidthTier.tablet, 5), isFalse);
    expect(KeyNumbersPanel.headlineFirst(HomeWidthTier.desktop, 5), isFalse);
  });

  group('five tiles on a phone', () {
    const five = AppSettings(
      hiddenHomeKeyNumbers: {'deepestThisYear', 'avgDepth', 'nextTrip'},
    );

    testWidgets('a headline row, then two pairs', (tester) async {
      await _pump(tester, width: 390, settings: five);
      final panel = tester.getRect(find.byType(KeyNumbersPanel));
      final dives = tester.getRect(
        find.ancestor(of: find.text('DIVES'), matching: find.byType(HomePanel)),
      );
      expect(dives.width, closeTo(panel.width, 1));
      for (final pair in [
        ['TIME UNDER', 'LAST DIVE'],
        ['AVG RMV', 'SPECIES'],
      ]) {
        final a = tester.getRect(
          find.ancestor(
            of: find.text(pair[0]),
            matching: find.byType(HomePanel),
          ),
        );
        final b = tester.getRect(
          find.ancestor(
            of: find.text(pair[1]),
            matching: find.byType(HomePanel),
          ),
        );
        expect(a.top, b.top);
        expect(a.width, lessThan(panel.width / 2));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the panel is three short rows tall', (tester) async {
      await _pump(tester, width: 390, settings: five);
      final context = tester.element(find.byType(KeyNumbersPanel));
      final short = homeRowHeight(HomePanelHeight.short, context);
      expect(
        KeyNumbersPanel.heightFor(context, HomeWidthTier.phone, 5),
        3 * short + 2 * 8,
      );
      expect(
        KeyNumbersPanel.heightFor(context, HomeWidthTier.phone, 4),
        2 * short + 8,
      );
    });

    testWidgets('the headline marks the series start and now', (tester) async {
      await _pump(tester, width: 390, settings: five);
      final now = DateTime.now();
      final start = const UnitFormatter(
        AppSettings(),
      ).formatMonthYear(DateTime(now.year, now.month - 11));
      expect(find.text(start), findsOneWidget);
      expect(find.text('now'), findsOneWidget);
    });

    testWidgets('no overflow at text scale 1.6', (tester) async {
      await _pump(tester, width: 390, settings: five, textScale: 1.6);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('four tiles on a phone keep two pairs', (tester) async {
    await _pump(
      tester,
      width: 390,
      settings: const AppSettings(
        hiddenHomeKeyNumbers: {
          'deepestThisYear',
          'avgDepth',
          'nextTrip',
          'species',
        },
      ),
    );
    final dives = tester.getRect(
      find.ancestor(of: find.text('DIVES'), matching: find.byType(HomePanel)),
    );
    final time = tester.getRect(
      find.ancestor(
        of: find.text('TIME UNDER'),
        matching: find.byType(HomePanel),
      ),
    );
    expect(dives.top, time.top);
    expect(find.text('now'), findsNothing);
  });

  testWidgets('in a right-to-left language the headline line still reads '
      'from its start to now', (tester) async {
    await pumpPanel(
      tester,
      const KeyNumbersPanel(),
      width: 390,
      height: 3 * 96 + 16,
      locale: const Locale('he'),
      settings: const AppSettings(
        hiddenHomeKeyNumbers: {'deepestThisYear', 'avgDepth', 'nextTrip'},
      ),
      overrides: [homeKeyNumbersProvider.overrideWith((ref) async => _full)],
    );
    final now = find.text('עכשיו');
    expect(now, findsOneWidget);
    final labels = find.descendant(
      of: find.ancestor(of: now, matching: find.byType(Row)).first,
      matching: find.byType(Text),
    );
    final start = tester.getRect(labels.first);
    // The line is drawn oldest to newest left to right in every language,
    // so its start label sits at the left and "now" at the right.
    expect(start.left, lessThan(tester.getRect(now).left));
    expect(tester.takeException(), isNull);
  });
}
