import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:submersion/features/dashboard/presentation/widgets/urgent_banner.dart';
import 'package:submersion/features/dashboard/presentation/widgets/year_in_review_card.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Counts how many times a refreshed provider was rebuilt.
int refreshBuilds = 0;

Future<void> pumpDashboard(
  WidgetTester tester, {
  DashboardMilestones? milestones,
  List<MediaItem> photos = const [],
  List<Dive> onThisDay = const [],
  YearInReview? yearInReview,
  List<RecentSitePin> sites = const [],
  MockSettingsNotifier? settingsNotifier,
  DashboardAlerts? alerts,
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
        dashboardAlertsProvider.overrideWith(
          (ref) async =>
              alerts ??
              const DashboardAlerts(
                insuranceExpiringSoon: false,
                insuranceExpired: false,
              ),
        ),
        dashboardGaugesProvider.overrideWith(
          (ref) async => const DashboardGauges(
            gearGauges: [],
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

    expect(find.byType(UrgentBanner), findsNothing);
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
    expect(find.byType(MilestonesCard), findsOneWidget);
  });

  testWidgets('populated data shows the conditional cards', (tester) async {
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
    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(AppSettings(homeCardOrder: order)),
    );

    // SingleChildScrollView lays out ALL children (it is not lazy), so both
    // widgets are measurable without scrolling and share a coordinate space.
    final recentDivesY = tester.getTopLeft(find.byType(RecentDivesCard)).dy;
    final heroY = tester.getTopLeft(find.byType(HeroHeader)).dy;
    expect(heroY, greaterThan(recentDivesY));
  });

  testWidgets('urgent banner stays above all cards regardless of order', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      alerts: const DashboardAlerts(
        insuranceExpiringSoon: false,
        insuranceExpired: true,
      ),
    );

    expect(find.byType(UrgentBanner), findsOneWidget);
    final bannerY = tester.getTopLeft(find.byType(UrgentBanner)).dy;
    final heroY = tester.getTopLeft(find.byType(HeroHeader)).dy;
    expect(bannerY, lessThan(heroY));
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
    'all cards hidden with active urgent banner shows banner AND empty state',
    (tester) async {
      await pumpDashboard(
        tester,
        settingsNotifier: MockSettingsNotifier(
          AppSettings(
            hiddenHomeCards: {for (final c in HomeCardType.values) c.name},
          ),
        ),
        alerts: const DashboardAlerts(
          insuranceExpiringSoon: false,
          insuranceExpired: true,
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byType(UrgentBanner), findsOneWidget);
      expect(find.text(l10n.dashboard_allHidden_message), findsOneWidget);
      final bannerY = tester.getTopLeft(find.byType(UrgentBanner)).dy;
      final messageY = tester
          .getTopLeft(find.text(l10n.dashboard_allHidden_message))
          .dy;
      expect(bannerY, lessThan(messageY));
    },
  );
}
