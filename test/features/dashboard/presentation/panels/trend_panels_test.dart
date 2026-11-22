import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dashboard/presentation/panels/activity_calendar_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/depth_mix_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/distribution_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/dives_per_month_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/ranking_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/sac_trend_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/widgets/depth_pie_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'panel_harness.dart';

DiveStatistics _stats({
  List<DepthRangeStat> depths = const [],
  List<TopSiteStat> sites = const [],
}) => DiveStatistics(
  totalDives: 10,
  totalTimeSeconds: 36000,
  maxDepth: 40,
  avgMaxDepth: 20,
  totalSites: 3,
  depthDistribution: depths,
  topSites: sites,
);

final _depths = [
  DepthRangeStat(label: '0-10', minDepth: 0, maxDepth: 10, count: 3),
  DepthRangeStat(label: '10-20', minDepth: 10, maxDepth: 20, count: 8),
  DepthRangeStat(label: '20-30', minDepth: 20, maxDepth: 30, count: 5),
  DepthRangeStat(label: '30-40', minDepth: 30, maxDepth: 40, count: 0),
  DepthRangeStat(label: '40-50', minDepth: 40, maxDepth: 50, count: 0),
];

void main() {
  group('activity calendar', () {
    testWidgets('sums dives and dive days, and opens the log', (tester) async {
      final nav = await pumpPanel(
        tester,
        const ActivityCalendarPanel(),
        width: 800,
        overrides: [
          homeActivityDaysProvider.overrideWith(
            (ref) async => {DateTime(2026, 3, 4): 2, DateTime(2026, 6, 1): 1},
          ),
        ],
      );
      expect(find.text('3 dives · 2 days'), findsOneWidget);
      await tester.tap(find.byType(ActivityCalendarPanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/dives');
    });

    testWidgets('says no count to a screen reader while loading', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPanel(
        tester,
        const ActivityCalendarPanel(),
        width: 800,
        overrides: [
          homeActivityDaysProvider.overrideWith(
            (ref) => Completer<Map<DateTime, int>>().future,
          ),
        ],
      );
      expect(find.bySemanticsLabel('Activity, 12 months'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a phone shows six months', (tester) async {
      await pumpPanel(
        tester,
        const ActivityCalendarPanel(),
        width: 390,
        overrides: [homeActivityDaysProvider.overrideWith((ref) async => {})],
      );
      expect(find.text('ACTIVITY, 6 MONTHS'), findsOneWidget);
    });
  });

  group('dives per month', () {
    testWidgets('shows a bar per month', (tester) async {
      await pumpPanel(
        tester,
        const DivesPerMonthPanel(),
        overrides: [
          homeMonthlyDivesProvider.overrideWith(
            (ref) async => [
              for (var m = 1; m <= 12; m++) MonthCount(2026, m, m % 3),
            ],
          ),
        ],
      );
      expect(find.text('DIVES PER MONTH'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('month labels stay distinct where names share a first '
        'character', (tester) async {
      // Chinese abbreviations are 1月 to 12月: a first character would
      // label October, November and December all "1".
      await pumpPanel(
        tester,
        const DivesPerMonthPanel(),
        locale: const Locale('zh'),
        overrides: [
          homeMonthlyDivesProvider.overrideWith(
            (ref) async => [
              for (var m = 1; m <= 12; m++) MonthCount(2026, m, 1),
            ],
          ),
        ],
      );
      expect(find.text('10'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });

  testWidgets('dives per month says no total while loading', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPanel(
      tester,
      const DivesPerMonthPanel(),
      overrides: [
        homeMonthlyDivesProvider.overrideWith(
          (ref) => Completer<List<MonthCount>>().future,
        ),
      ],
    );
    expect(find.bySemanticsLabel('Dives per month'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('dives per month with no dives in the year says so', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const DivesPerMonthPanel(),
      overrides: [
        homeMonthlyDivesProvider.overrideWith(
          (ref) async => [for (var m = 1; m <= 12; m++) MonthCount(2026, m, 0)],
        ),
      ],
    );
    expect(find.text('No dives yet'), findsOneWidget);
  });

  group('SAC trend', () {
    testWidgets('one point renders without error', (tester) async {
      await pumpPanel(
        tester,
        const SacTrendPanel(),
        overrides: [
          homeSacSeriesProvider.overrideWith(
            (ref) async => [
              TrendDataPoint(date: DateTime(2026), value: 14, label: ''),
            ],
          ),
        ],
      );
      expect(find.text('RMV TREND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no gas data says so', (tester) async {
      await pumpPanel(
        tester,
        const SacTrendPanel(),
        overrides: [homeSacSeriesProvider.overrideWith((ref) async => [])],
      );
      expect(find.text('No dives with gas data yet'), findsOneWidget);
    });

    testWidgets("reads the latest value in the diver's unit", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPanel(
        tester,
        const SacTrendPanel(),
        settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
        overrides: [
          homeSacSeriesProvider.overrideWith(
            (ref) async => [
              TrendDataPoint(date: DateTime(2026), value: 14),
              TrendDataPoint(date: DateTime(2026, 2), value: 16),
            ],
          ),
        ],
      );
      expect(find.bySemanticsLabel('RMV trend, 0.57 cuft/min'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('depth mix', () {
    testWidgets('trims empty deep bands and opens Insights', (tester) async {
      final nav = await pumpPanel(
        tester,
        const DepthMixPanel(),
        overrides: [
          diveStatisticsProvider.overrideWith(
            (ref) async => _stats(depths: _depths),
          ),
        ],
      );
      expect(find.textContaining('20-30'), findsOneWidget);
      expect(find.textContaining('40-50'), findsNothing);
      await tester.tap(find.byType(DepthMixPanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/insights');
    });

    testWidgets('reads its bands and counts to a screen reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPanel(
        tester,
        const DepthMixPanel(),
        overrides: [
          diveStatisticsProvider.overrideWith(
            (ref) async => _stats(depths: _depths),
          ),
        ],
      );
      // The bars are the panel's only numbers, so the label carries them.
      expect(
        find.bySemanticsLabel(RegExp(r'^Depth mix, .*10-20.*: 8')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('labels bands in feet for an imperial diver', (tester) async {
      await pumpPanel(
        tester,
        const DepthMixPanel(),
        settings: const AppSettings(depthUnit: DepthUnit.feet),
        overrides: [
          diveStatisticsProvider.overrideWith(
            (ref) async => _stats(depths: _depths),
          ),
        ],
      );
      expect(find.textContaining('ft'), findsWidgets);
    });

    // Shallow to deep in the Insights depth chart's colours. On a dark
    // theme the ramp starts at its lightest, as Insights does; on a light
    // one it starts at the mid shades, whose lightest bar still stands at
    // about 3:1 against the panel.
    for (final (brightness, first) in [
      (Brightness.dark, 0),
      (Brightness.light, 5),
    ]) {
      testWidgets('colours each band shallow to deep (${brightness.name})', (
        tester,
      ) async {
        await pumpPanel(
          tester,
          const DepthMixPanel(),
          theme: ThemeData(brightness: brightness),
          overrides: [
            diveStatisticsProvider.overrideWith(
              (ref) async => _stats(depths: _depths),
            ),
          ],
        );
        final bars = tester.widget<HomeBars>(find.byType(HomeBars));
        expect(bars.colors, depthBucketColors.sublist(first, first + 3));
      });
    }

    // A log reaching the deepest bands has no room for the shifted start:
    // the light ramp starts only as far in as the band count allows, so
    // every band keeps a colour of its own.
    test('every band keeps its own colour however deep the log', () {
      final total = depthBucketColors.length;
      for (final brightness in Brightness.values) {
        for (var bands = 1; bands <= total; bands++) {
          final colours = {
            for (var i = 0; i < bands; i++)
              depthBandColor(i, brightness, bands: bands),
          };
          expect(colours, hasLength(bands), reason: '$brightness $bands');
        }
      }
      // A shallow log on a light theme still starts at the mid shades.
      expect(
        depthBandColor(0, Brightness.light, bands: 3),
        depthBucketColors[5],
      );
      expect(
        depthBandColor(0, Brightness.dark, bands: 3),
        depthBucketColors[0],
      );
    });

    testWidgets('no dives shows the empty text', (tester) async {
      await pumpPanel(
        tester,
        const DepthMixPanel(),
        overrides: [
          diveStatisticsProvider.overrideWith((ref) async => _stats()),
        ],
      );
      expect(find.text('No dives yet'), findsOneWidget);
    });
  });

  group('distributions', () {
    testWidgets('gas mix shows its top three shares', (tester) async {
      await pumpPanel(
        tester,
        const GasMixPanel(),
        overrides: [
          homeGasMixProvider.overrideWith(
            (ref) async => [
              DistributionSegment(label: 'Nitrox', count: 6, percentage: 61),
              DistributionSegment(label: 'Air', count: 3, percentage: 33),
              DistributionSegment(label: 'Trimix', count: 1, percentage: 6),
            ],
          ),
        ],
      );
      expect(find.text('Nitrox'), findsOneWidget);
      expect(find.text('61%'), findsOneWidget);
    });

    // The gas names are the app's own strings, not the query's English
    // keys: in German air is Luft, in Chinese 空气.
    testWidgets('gas mix names each gas in the diver\'s language', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        const GasMixPanel(),
        locale: const Locale('de'),
        overrides: [
          homeGasMixProvider.overrideWith(
            (ref) async => [
              DistributionSegment(label: 'Nitrox', count: 6, percentage: 61),
              DistributionSegment(label: 'Air', count: 3, percentage: 33),
            ],
          ),
        ],
      );
      expect(find.text('Luft'), findsOneWidget);
      expect(find.text('Air'), findsNothing);
    });

    // Each gas in its colour from the dive profile: air orange, nitrox
    // green, trimix purple.
    testWidgets('gas mix colours each gas as the profile does', (tester) async {
      await pumpPanel(
        tester,
        const GasMixPanel(),
        overrides: [
          homeGasMixProvider.overrideWith(
            (ref) async => [
              DistributionSegment(label: 'Nitrox', count: 6, percentage: 61),
              DistributionSegment(label: 'Air', count: 3, percentage: 33),
              DistributionSegment(label: 'Trimix', count: 1, percentage: 6),
            ],
          ),
        ],
      );
      final rows = tester.widgetList<HomeBarRow>(find.byType(HomeBarRow));
      expect(
        {for (final r in rows) r.label: r.color},
        {
          'Nitrox': GasColors.nitrox,
          'Air': GasColors.air,
          'Trimix': GasColors.trimix,
        },
      );
    });

    testWidgets('dive types name their types', (tester) async {
      await pumpPanel(
        tester,
        const DiveTypesPanel(),
        overrides: [
          homeDiveTypesProvider.overrideWith(
            (ref) async => [
              DistributionSegment(
                label: 'recreational',
                key: 'recreational',
                count: 6,
                percentage: 60,
              ),
            ],
          ),
        ],
      );
      expect(find.text('DIVE TYPES'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });
  });

  group('rankings', () {
    testWidgets('top sites lists sites and opens the site list', (
      tester,
    ) async {
      final nav = await pumpPanel(
        tester,
        const TopSitesPanel(),
        width: 390,
        overrides: [
          diveStatisticsProvider.overrideWith(
            (ref) async => _stats(
              sites: [
                TopSiteStat(
                  siteId: 's1',
                  siteName:
                      'Salt Pier, a very long name that keeps going past the edge',
                  diveCount: 14,
                ),
                TopSiteStat(siteId: 's2', siteName: 'Bari', diveCount: 7),
              ],
            ),
          ),
        ],
      );
      expect(find.text('14'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(TopSitesPanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/sites');
    });

    testWidgets('top buddies with none says so', (tester) async {
      await pumpPanel(
        tester,
        const TopBuddiesPanel(),
        overrides: [homeTopBuddiesProvider.overrideWith((ref) async => [])],
      );
      expect(find.text('No buddies logged yet'), findsOneWidget);
    });

    testWidgets('top buddies opens the buddy list', (tester) async {
      final nav = await pumpPanel(
        tester,
        const TopBuddiesPanel(),
        overrides: [
          homeTopBuddiesProvider.overrideWith(
            (ref) async => [RankingItem(id: 'b', name: 'Sam', count: 31)],
          ),
        ],
      );
      expect(find.text('Sam'), findsOneWidget);
      await tester.tap(find.byType(TopBuddiesPanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/buddies');
    });
  });

  testWidgets('trend panels survive text scale 2 at phone width', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const Column(
        children: [
          Expanded(child: DepthMixPanel()),
          Expanded(child: TopSitesPanel()),
        ],
      ),
      width: 195,
      height: 360,
      textScale: 2,
      overrides: [
        diveStatisticsProvider.overrideWith(
          (ref) async => _stats(
            depths: _depths,
            sites: [TopSiteStat(siteId: 's', siteName: 'Salt', diveCount: 1)],
          ),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
  });
}
