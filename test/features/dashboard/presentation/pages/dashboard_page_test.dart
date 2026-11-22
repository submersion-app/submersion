import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/home_presets.dart';
import 'package:submersion/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:submersion/features/dashboard/presentation/panels/conditional_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/first_dive_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/key_numbers_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/recent_dives_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_outings_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_header_bar.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_exit_entries.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/home_species_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// How often each counted provider was built, by name.
final builds = <String, int>{};

T _count<T>(String name, T value) {
  builds.update(name, (n) => n + 1, ifAbsent: () => 1);
  return value;
}

final _dives = [
  Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 11, 8, 10),
    maxDepth: 18.4,
    runtime: const Duration(minutes: 52),
    site: const DiveSite(id: 's1', name: 'Salt Pier'),
  ),
];

DiveStatistics _stats(int dives) => DiveStatistics(
  totalDives: dives,
  totalTimeSeconds: dives * 3000,
  maxDepth: 30,
  avgMaxDepth: 20,
  totalSites: dives == 0 ? 0 : 1,
);

const _gauges = DashboardGauges(
  hasGear: true,
  insurance: null,
  noFlyStatus: null,
  daysSinceLastDive: 12,
);

Future<void> pumpHome(
  WidgetTester tester, {
  double width = 1280,
  double height = 3000,
  double textScale = 1,
  int dives = 1,
  AppSettings settings = const AppSettings(),
  bool demo = false,
  List<Dive> onThisDay = const [],
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  builds.clear();
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
      GoRoute(
        path: '/settings/appearance/home',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        demoModeActiveProvider.overrideWithValue(demo),
        currentDiverProvider.overrideWith((ref) async => null),
        diverCountProvider.overrideWith((ref) async => 1),
        dashboardDiverProvider.overrideWith((ref) async => null),
        dashboardGaugesProvider.overrideWith(
          (ref) async => _count('gauges', _gauges),
        ),
        diveStatisticsProvider.overrideWith(
          (ref) async => _count('stats', _stats(dives)),
        ),
        recentDivesProvider.overrideWith(
          (ref) async => _count('recentDives', dives == 0 ? <Dive>[] : _dives),
        ),
        homeKeyNumbersProvider.overrideWith(
          (ref) async => _count(
            'keyNumbers',
            HomeKeyNumbers(careerDives: dives, careerTimeSeconds: dives * 3000),
          ),
        ),
        homeActivityDaysProvider.overrideWith(
          (ref) async => _count('activity', <DateTime, int>{}),
        ),
        homeRecentOutingsProvider.overrideWith(
          (ref) async => _count('outings', <HomeOuting>[]),
        ),
        homeMonthlyDivesProvider.overrideWith(
          (ref) async => _count('months', [
            for (var m = 1; m <= 12; m++) MonthCount(2026, m, m % 4),
          ]),
        ),
        homeSacSeriesProvider.overrideWith((ref) async => _count('sac', [])),
        homeAveragesProvider.overrideWith(
          (ref) async => _count('averages', (
            averages: const HomeAverages(
              maxDepth: 20,
              runtimeSeconds: 2800,
              diveCount: 10,
            ),
            sac: null,
          )),
        ),
        homeGasMixProvider.overrideWith(
          (ref) async => _count('gasMix', [
            DistributionSegment(label: 'Air', count: 1, percentage: 100),
          ]),
        ),
        homeDiveTypesProvider.overrideWith(
          (ref) async => _count('diveTypes', <DistributionSegment>[]),
        ),
        homeTopBuddiesProvider.overrideWith(
          (ref) async => _count('buddies', <RankingItem>[]),
        ),
        homeRecentSpeciesProvider.overrideWith(
          (ref) async => _count('species', const <SpeciesSighting>[]),
        ),
        homeGearServiceProvider.overrideWith(
          (ref) async => _count('gear', <GearServiceBar>[]),
        ),
        homeComingDueProvider.overrideWith(
          (ref) async => _count('comingDue', <ComingDueItem>[]),
        ),
        homeLatestProfileProvider.overrideWith(
          (ref) async => _count('profile', null),
        ),
        recentMediaProvider.overrideWith(
          (ref) async => _count('photos', <MediaItem>[]),
        ),
        recentSitesProvider.overrideWith(
          (ref) async => _count('sites', <RecentSitePin>[]),
        ),
        onThisDayProvider.overrideWith(
          (ref) async => _count('onThisDay', onThisDay),
        ),
        activeCoursesProgressProvider.overrideWith(
          (ref) async => _count('courses', []),
        ),
        draftDivesProvider.overrideWith(
          (ref) async => _count('drafts', <Dive>[]),
        ),
        homeTripChecklistProvider.overrideWith((ref) async => null),
        preDiveActiveSessionProvider.overrideWith((ref) async => null),
        preDiveSessionsProvider.overrideWith((ref) async => []),
        preDiveTemplatesProvider.overrideWith((ref) async => []),
        homeSpeciesCountProvider.overrideWith((ref) async => 0),
        ...extra,
      ].cast(),
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('nothing stored shows the header and the Balanced panels', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
    expect(find.byType(KeyNumbersPanel, skipOffstage: false), findsOneWidget);
    expect(find.byType(RecentDivesPanel, skipOffstage: false), findsOneWidget);
    expect(find.text('GAS MIX', skipOffstage: false), findsOneWidget);
    // Not in Balanced.
    expect(find.text('TOP BUDDIES', skipOffstage: false), findsNothing);
  });

  testWidgets('a hidden panel is absent and its data is never read', (
    tester,
  ) async {
    await pumpHome(
      tester,
      settings: const AppSettings(
        homePanelOrder: ['keyNumbers', 'onThisDay', 'gasMix', 'recentDives'],
        hiddenHomePanels: {'onThisDay', 'gasMix'},
      ),
    );
    expect(find.text('GAS MIX', skipOffstage: false), findsNothing);
    expect(builds['gasMix'], isNull);
    expect(builds['onThisDay'], isNull);
    expect(find.byType(RecentDivesPanel, skipOffstage: false), findsOneWidget);
  });

  testWidgets('conditional panels with nothing to show leave no box', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.byType(OnThisDayPanel, skipOffstage: false), findsNothing);
    expect(find.byType(PhotosPanel, skipOffstage: false), findsNothing);
    expect(find.byType(PreDivePanel, skipOffstage: false), findsNothing);
  });

  testWidgets('a conditional panel with content appears', (tester) async {
    await pumpHome(
      tester,
      onThisDay: [
        Dive(
          id: 'old',
          dateTime: DateTime.utc(2024, 11, 20),
          site: const DiveSite(id: 'b', name: 'Blue Hole'),
        ),
      ],
    );
    expect(find.byType(OnThisDayPanel, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a hidden key numbers panel loads nothing', (tester) async {
    final layout = homeLayoutForPreset(
      HomeLayoutPreset.balanced,
    ).withPanelEnabled(HomePanelType.keyNumbers, false);
    await pumpHome(
      tester,
      settings: AppSettings(
        homePanelOrder: layout.orderNames,
        hiddenHomePanels: layout.hiddenNames,
      ),
    );
    expect(find.byType(KeyNumbersPanel, skipOffstage: false), findsNothing);
    expect(builds['keyNumbers'], isNull);
  });

  testWidgets('with every tile off the key numbers row is absent', (
    tester,
  ) async {
    await pumpHome(
      tester,
      settings: AppSettings(
        hiddenHomeKeyNumbers: {for (final t in HomeKeyNumber.values) t.name},
      ),
    );
    expect(find.byType(KeyNumbersPanel, skipOffstage: false), findsNothing);
  });

  testWidgets('the first-dive panel fits a 320 phone at text scale 2', (
    tester,
  ) async {
    await pumpHome(tester, dives: 0, width: 320, height: 4000, textScale: 2);
    expect(find.byType(FirstDivePanel, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no dives and every panel hidden still offers a first dive', (
    tester,
  ) async {
    await pumpHome(
      tester,
      dives: 0,
      settings: AppSettings(
        homePanelOrder: [for (final p in HomePanelType.values) p.name],
        hiddenHomePanels: {for (final p in HomePanelType.values) p.name},
      ),
    );
    expect(find.byType(FirstDivePanel, skipOffstage: false), findsOneWidget);
  });

  testWidgets('with key numbers hidden the first-dive panel leads', (
    tester,
  ) async {
    final layout = homeLayoutForPreset(
      HomeLayoutPreset.balanced,
    ).withPanelEnabled(HomePanelType.keyNumbers, false);
    await pumpHome(
      tester,
      dives: 0,
      settings: AppSettings(
        homePanelOrder: layout.orderNames,
        hiddenHomePanels: layout.hiddenNames,
      ),
    );
    final first = tester.getRect(find.byType(FirstDivePanel));
    final dives = tester.getRect(
      find.byType(RecentDivesPanel, skipOffstage: false),
    );
    expect(first.top, lessThan(dives.top));
    expect(
      tester.getRect(find.text('RECENT OUTINGS')).top,
      greaterThan(first.top),
    );
  });

  testWidgets('a diver with no dives sees the first-dive panel', (
    tester,
  ) async {
    await pumpHome(tester, dives: 0);
    expect(find.byType(FirstDivePanel, skipOffstage: false), findsOneWidget);
  });

  testWidgets('all panels hidden keeps the header and the customise link', (
    tester,
  ) async {
    await pumpHome(
      tester,
      settings: AppSettings(
        homePanelOrder: [for (final p in HomePanelType.values) p.name],
        hiddenHomePanels: {for (final p in HomePanelType.values) p.name},
      ),
    );
    expect(find.byType(HomeHeaderBar), findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.dashboard_allHidden_customize), findsOneWidget);
  });

  testWidgets('panels on but with nothing to show never claim to be hidden', (
    tester,
  ) async {
    // Only On this day is on, and today it has nothing.
    await pumpHome(
      tester,
      settings: AppSettings(
        homePanelOrder: [for (final p in HomePanelType.values) p.name],
        hiddenHomePanels: {
          for (final p in HomePanelType.values)
            if (p != HomePanelType.onThisDay) p.name,
        },
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.dashboard_allHidden_message), findsOneWidget);
    expect(find.textContaining('hidden'), findsNothing);
    expect(find.textContaining('cards'), findsNothing);
  });

  testWidgets('demo mode puts its card above the panels', (tester) async {
    await pumpHome(tester, demo: true);
    final demo = tester.getRect(find.byType(DemoModeDashboardCard));
    final keys = tester.getRect(find.byType(KeyNumbersPanel));
    expect(demo.top, lessThan(keys.top));
  });

  // Issue #4881: the species model offer heads the page, under demo mode's
  // way out and above the panels.
  testWidgets('Home holds the species model banner slot under the demo card', (
    tester,
  ) async {
    // Shown, so it has a size: a hidden banner is a zero-height sliver,
    // which the finder skips as offstage.
    await pumpHome(
      tester,
      demo: true,
      extra: [
        homeSpeciesBannerProvider.overrideWithValue(true),
        speciesDownloadPromptProvider.overrideWithValue(true),
      ],
    );
    final slot = tester.getRect(find.byType(HomeSpeciesBanner));
    expect(slot.height, greaterThan(0));
    final demo = tester.getRect(find.byType(DemoModeDashboardCard));
    final keys = tester.getRect(find.byType(KeyNumbersPanel));
    expect(slot.top, greaterThanOrEqualTo(demo.bottom));
    expect(slot.bottom, lessThanOrEqualTo(keys.top));
  });

  testWidgets('pull to refresh refetches', (tester) async {
    await pumpHome(tester);
    final before = builds['stats'] ?? 0;
    final indicator = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    unawaited(indicator.show());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(builds['stats'], greaterThan(before));
  });

  for (final width in [320.0, 390.0, 799.0, 800.0, 1199.0, 1200.0, 1600.0]) {
    testWidgets('every panel on: no layout error at $width wide', (
      tester,
    ) async {
      await pumpHome(
        tester,
        width: width,
        settings: AppSettings(
          homePanelOrder: [for (final p in HomePanelType.values) p.name],
          hiddenHomePanels: const {},
          hiddenHomeKeyNumbers: const {},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every panel on: no overflow at text scale 2 on a phone', (
    tester,
  ) async {
    await pumpHome(
      tester,
      width: 390,
      height: 6000,
      textScale: 2,
      settings: AppSettings(
        homePanelOrder: [for (final p in HomePanelType.values) p.name],
        hiddenHomePanels: const {},
        hiddenHomeKeyNumbers: const {},
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
