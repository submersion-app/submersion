import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/gauge_strip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/on_this_day_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/media_ribbon_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/year_in_review_card.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Counts how many times a refreshed provider was rebuilt.
int refreshBuilds = 0;

/// Gauges carrying one dive-safety alert (an expired policy), the state that
/// hardens the strip against being hidden.
final _expiredInsuranceGauges = DashboardGauges(
  hasGear: false,
  insurance: DiverInsurance(provider: 'DAN', expiryDate: DateTime(2020, 1, 1)),
  noFlyStatus: null,
  daysSinceLastDive: null,
);

/// The other way into the same override: a lapsed service clock rather than
/// an expired policy.
final _overdueGearGauges = DashboardGauges(
  gearOverdue: GearSeverityGroup(
    count: 1,
    worst: GearGauge(
      type: EquipmentType.regulator,
      itemId: 'reg-1',
      itemName: 'Regulator',
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 'schedule',
          equipmentId: 'reg-1',
          serviceKindId: 'kind',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        kind: ServiceKind(
          id: 'kind',
          name: 'Annual service',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        anchor: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 6, 1),
        severity: ServiceClockSeverity.overdue,
        now: DateTime(2026, 9, 1),
      ),
    ),
  ),
  hasGear: true,
  insurance: null,
  noFlyStatus: null,
  daysSinceLastDive: null,
);

Future<void> pumpDashboard(
  WidgetTester tester, {
  DashboardMilestones? milestones,
  List<MediaItem> photos = const [],
  List<Dive> onThisDay = const [],
  YearInReview? yearInReview,
  List<RecentSitePin> sites = const [],
  MockSettingsNotifier? settingsNotifier,
  DashboardGauges? gauges,
}) async {
  refreshBuilds = 0;
  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
      GoRoute(path: '/dives', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/equipment',
        builder: (_, _) => const Scaffold(),
        routes: [GoRoute(path: 'new', builder: (_, _) => const Scaffold())],
      ),
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
        currentDiverProvider.overrideWith((ref) async => null),
        recentDivesProvider.overrideWith((ref) async {
          refreshBuilds++;
          return <Dive>[];
        }),
        diveStatisticsProvider.overrideWith(
          (ref) async => DiveStatistics(
            totalDives: 0,
            totalTimeSeconds: 0,
            maxDepth: 0,
            avgMaxDepth: 0,
            totalSites: 0,
          ),
        ),
        dashboardQuickStatsProvider.overrideWith(
          (ref) async => const DashboardQuickStats(),
        ),
        dashboardGaugesProvider.overrideWith(
          (ref) async =>
              gauges ??
              const DashboardGauges(
                hasGear: false,
                insurance: null,
                noFlyStatus: null,
                daysSinceLastDive: null,
              ),
        ),
        milestonesProvider.overrideWith(
          (ref) async =>
              milestones ??
              const DashboardMilestones(
                nextMilestone: null,
                divesRemaining: null,
                anniversaries: [],
              ),
        ),
        recentMediaProvider.overrideWith((ref) async => photos),
        onThisDayProvider.overrideWith((ref) async => onThisDay),
        yearInReviewProvider.overrideWith((ref) async => yearInReview),
        activeCoursesProgressProvider.overrideWith((ref) async => []),
        recentSitesProvider.overrideWith((ref) async => sites),
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  // Cannot pumpAndSettle: the hero's ocean animation never settles.
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('empty data renders always-on blocks, hides conditional cards', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.byType(HeroHeader), findsOneWidget);
    expect(find.byType(GaugeStrip), findsOneWidget);
    expect(find.byType(RecentDivesCard), findsOneWidget);
    expect(find.byType(QuickActionsCard), findsOneWidget);

    expect(find.byType(MilestonesCard), findsNothing);
    expect(find.byType(MediaRibbonCard), findsNothing);
    expect(find.byType(OnThisDayCard), findsNothing);
    expect(find.byType(YearInReviewCard), findsNothing);
    expect(find.byType(RecentSitesMapCard), findsNothing);
  });

  testWidgets('pull-to-refresh refetches the dashboard providers', (
    tester,
  ) async {
    await pumpDashboard(tester);

    // Providers are counted through the shared build counter below; showing
    // the indicator runs onRefresh directly, which is what a drag does.
    final indicator = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    unawaited(indicator.show());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(refreshBuilds, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without layout errors at phone width', (tester) async {
    // Regression: QuickActionsCard once used an internal Expanded that
    // threw in the unbounded 1-column scroll layout, collapsing the page.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpDashboard(
      tester,
      milestones: const DashboardMilestones(
        nextMilestone: 250,
        divesRemaining: 3,
        anniversaries: [],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(HeroHeader), findsOneWidget);
    expect(find.byType(QuickActionsCard), findsOneWidget);
    // Below this fold, but built for the band a lazy list keeps ready.
    expect(find.byType(MilestonesCard, skipOffstage: false), findsOneWidget);
  });

  testWidgets('populated data shows the conditional cards', (tester) async {
    // Tall enough for every row: below the fold they are built on approach.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpDashboard(
      tester,
      milestones: const DashboardMilestones(
        nextMilestone: 250,
        divesRemaining: 3,
        anniversaries: [],
      ),
      photos: [
        MediaItem(
          id: 'p1',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.platformGallery,
          filePath: '/tmp/p1.jpg',
          takenAt: DateTime(2026, 7, 1),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      ],
      onThisDay: [Dive(id: 'otd', dateTime: DateTime(2023, 7, 24))],
      yearInReview: const YearInReview(
        year: 2026,
        current: YearStats(diveCount: 34, totalSeconds: 147600, maxDepth: 48),
        previous: YearStats(diveCount: 28, totalSeconds: 100800, maxDepth: 40),
      ),
    );

    expect(find.byType(MilestonesCard), findsOneWidget);
    expect(find.byType(MediaRibbonCard), findsOneWidget);
    expect(find.byType(OnThisDayCard), findsOneWidget);
    expect(find.byType(YearInReviewCard), findsOneWidget);
  });

  testWidgets('hidden card is absent', (tester) async {
    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(hiddenHomeCards: {HomeCardType.quickActions.name}),
      ),
    );

    expect(find.byType(QuickActionsCard), findsNothing);
    expect(find.byType(RecentDivesCard), findsOneWidget);
  });

  testWidgets('custom order is respected', (tester) async {
    // Recent dives first, hero last.
    final order = [
      HomeCardType.recentDives.name,
      for (final c in HomeCardType.values)
        if (c != HomeCardType.recentDives && c != HomeCardType.hero) c.name,
      HomeCardType.hero.name,
    ];
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(AppSettings(homeCardOrder: order)),
    );

    // The rows are lazy, so the tall view above is what puts both widgets
    // in the tree without scrolling, in one coordinate space.
    final recentDivesY = tester.getTopLeft(find.byType(RecentDivesCard)).dy;
    final heroY = tester.getTopLeft(find.byType(HeroHeader)).dy;
    expect(heroY, greaterThan(recentDivesY));
  });

  group('first load (#3819)', () {
    const sites = [
      RecentSitePin(siteName: 'Site A', latitude: 36.0, longitude: 25.0),
      RecentSitePin(siteName: 'Site B', latitude: 35.0, longitude: 24.0),
    ];

    /// A phone page tall with cards, so the map sits far below the fold.
    Future<void> pumpPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpDashboard(
        tester,
        milestones: const DashboardMilestones(
          nextMilestone: 250,
          divesRemaining: 3,
          anniversaries: [],
        ),
        yearInReview: const YearInReview(
          year: 2026,
          current: YearStats(diveCount: 34, totalSeconds: 147600, maxDepth: 48),
          previous: YearStats(
            diveCount: 28,
            totalSeconds: 100800,
            maxDepth: 40,
          ),
        ),
        onThisDay: [Dive(id: 'otd', dateTime: DateTime(2023, 7, 24))],
        sites: sites,
      );
    }

    testWidgets('leaves cards and the map below the fold unbuilt', (
      tester,
    ) async {
      await pumpPhone(tester);

      expect(find.byType(HeroHeader), findsOneWidget);
      expect(find.byType(RecentDivesCard), findsOneWidget);
      expect(
        find.byType(RecentSitesMapCard, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(OnThisDayCard, skipOffstage: false), findsNothing);
      expect(find.byType(FlutterMap, skipOffstage: false), findsNothing);
    });

    testWidgets('scrolling down builds the card and mounts its map', (
      tester,
    ) async {
      await pumpPhone(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(RecentSitesMapCard), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the map survives scrolling back to the top', (tester) async {
      await pumpPhone(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final mapState = tester.state(find.byType(FlutterMap));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        tester.state(find.byType(FlutterMap, skipOffstage: false)),
        same(mapState),
      );
    });

    testWidgets('a short page can still be pulled to refresh', (tester) async {
      await pumpDashboard(tester);

      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics,
        isA<AlwaysScrollableScrollPhysics>(),
      );
    });
  });

  testWidgets('a live alert no longer pushes anything above the hero', (
    tester,
  ) async {
    await pumpDashboard(tester, gauges: _expiredInsuranceGauges);

    // The alert now lives in the gauge strip, so the greeting stays the
    // first thing on the page instead of being pushed down by a banner.
    expect(find.byType(GaugeStrip), findsOneWidget);
    final heroY = tester.getTopLeft(find.byType(HeroHeader)).dy;
    final stripY = tester.getTopLeft(find.byType(GaugeStrip)).dy;
    expect(heroY, lessThan(stripY));
  });

  testWidgets('a safety alert forces the gauge strip back on when hidden', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      gauges: _expiredInsuranceGauges,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(hiddenHomeCards: {HomeCardType.gaugeStrip.name}),
      ),
    );

    expect(find.byType(GaugeStrip), findsOneWidget);
    // The override is scoped to the strip: other hidden cards stay hidden.
    final heroY = tester.getTopLeft(find.byType(HeroHeader)).dy;
    final stripY = tester.getTopLeft(find.byType(GaugeStrip)).dy;
    expect(heroY, lessThan(stripY));
  });

  testWidgets('overdue gear also forces the gauge strip back on', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      gauges: _overdueGearGauges,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(hiddenHomeCards: {HomeCardType.gaugeStrip.name}),
      ),
    );

    expect(find.byType(GaugeStrip), findsOneWidget);
  });

  testWidgets('hiding the gauge strip works when no alert is live', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(hiddenHomeCards: {HomeCardType.gaugeStrip.name}),
      ),
    );

    expect(find.byType(GaugeStrip), findsNothing);
    expect(find.byType(HeroHeader), findsOneWidget);
  });

  testWidgets('all cards hidden shows empty state with settings link', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(
          hiddenHomeCards: {for (final c in HomeCardType.values) c.name},
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.dashboard_allHidden_message), findsOneWidget);

    await tester.tap(find.text(l10n.dashboard_allHidden_customize));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all cards hidden with a live alert shows the strip AND the empty state',
    (tester) async {
      await pumpDashboard(
        tester,
        settingsNotifier: MockSettingsNotifier(
          AppSettings(
            hiddenHomeCards: {for (final c in HomeCardType.values) c.name},
          ),
        ),
        gauges: _expiredInsuranceGauges,
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The forced strip must not swallow the CTA: without it the diver has
      // no route back to re-enabling their cards.
      expect(find.byType(GaugeStrip), findsOneWidget);
      expect(find.text(l10n.dashboard_allHidden_message), findsOneWidget);
      final stripY = tester.getTopLeft(find.byType(GaugeStrip)).dy;
      final messageY = tester
          .getTopLeft(find.text(l10n.dashboard_allHidden_message))
          .dy;
      expect(stripY, lessThan(messageY));
    },
  );
}
