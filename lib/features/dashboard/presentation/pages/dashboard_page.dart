import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/home_presets.dart';
import 'package:submersion/features/dashboard/presentation/panels/activity_calendar_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/coming_due_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/conditional_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/depth_mix_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/distribution_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/dives_per_month_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/first_dive_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/gear_service_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/key_numbers_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/latest_profile_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/latest_vs_average_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/next_trip_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/ranking_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/recent_outings_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/recent_dives_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/sac_trend_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/species_seen_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_header_bar.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_exit_entries.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/home_species_banner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Home as a technical dashboard (issue #4824): a slim header with the
/// status lights over a grid of panels whose rows always run edge to edge.
/// Which panels show, and in what order, comes from the diver's layout
/// (a preset they may have customised).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = resolveHomeLayout(
      storedOrder: ref.watch(settingsProvider.select((s) => s.homePanelOrder)),
      storedHidden: ref.watch(
        settingsProvider.select((s) => s.hiddenHomePanels),
      ),
      legacyHiddenCards: ref.watch(
        settingsProvider.select((s) => s.hiddenHomeCards),
      ),
    );
    final hiddenTiles = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeKeyNumbers),
    );

    // A conditional panel joins the grid only once its data resolves to
    // something worth showing: loading and error both leave it out, so the
    // grid never lays out an empty box. A hidden panel's provider is never
    // watched (issue #4251): hiding a panel spares Home its work.
    bool show<T>(AsyncValue<T>? value, bool Function(T data) hasContent) =>
        value?.maybeWhen(data: hasContent, orElse: () => false) ?? false;
    AsyncValue<T>? watchIfShown<T>(
      HomePanelType panel,
      ProviderListenable<AsyncValue<T>> provider,
    ) => layout.hidden.contains(panel) ? null : ref.watch(provider);

    final media = watchIfShown(HomePanelType.photoRibbon, recentMediaProvider);
    final sites = watchIfShown(
      HomePanelType.recentSitesMap,
      recentSitesProvider,
    );
    final onThisDay = watchIfShown(HomePanelType.onThisDay, onThisDayProvider);
    final courses = watchIfShown(
      HomePanelType.activeCourses,
      activeCoursesProgressProvider,
    );
    final drafts = watchIfShown(
      HomePanelType.waitingForDownload,
      draftDivesProvider,
    );
    final species = watchIfShown(
      HomePanelType.speciesSeen,
      homeRecentSpeciesProvider,
    );
    final gauges = ref.watch(dashboardGaugesProvider);
    final preDive =
        !layout.hidden.contains(HomePanelType.preDive) &&
        preDivePanelHasContent(ref);
    // Watched only when shown (issue #4251): the numbers read ten sources.
    final keyNumbers = layout.hidden.contains(HomePanelType.keyNumbers)
        ? null
        : ref.watch(homeKeyNumbersProvider).value;

    bool hasContent(HomePanelType panel) => switch (panel) {
      HomePanelType.photoRibbon => show(media, (m) => m.isNotEmpty),
      // Waits for the first photo result: photos arriving later would join
      // the map's row and change the panel the row is keyed by, which would
      // remount the map. A hidden photo panel never joins, so nothing waits.
      HomePanelType.recentSitesMap =>
        (media == null || media.hasValue || !media.isLoading) &&
            show(sites, (s) => s.isNotEmpty),
      HomePanelType.onThisDay => show(onThisDay, (d) => d.isNotEmpty),
      HomePanelType.activeCourses => show(courses, (c) => c.isNotEmpty),
      HomePanelType.waitingForDownload => show(
        drafts,
        (d) => draftsWaitingForDownload(d).isNotEmpty,
      ),
      HomePanelType.speciesSeen => show(species, (s) => s.isNotEmpty),
      HomePanelType.nextTrip => show(gauges, (g) => g.nextTrip != null),
      HomePanelType.preDive => preDive,
      // With every tile off, or none with anything to say yet, the row would
      // be an empty box.
      HomePanelType.keyNumbers =>
        KeyNumbersPanel.enabledTiles(hiddenTiles).isNotEmpty &&
            (keyNumbers == null ||
                KeyNumbersPanel.visibleTileCount(keyNumbers, hiddenTiles) > 0),
      _ => true,
    };

    final visible = [
      for (final p in layout.visible)
        if (hasContent(p)) p,
    ];
    final tier = homeWidthTierOf(context);
    final rows = packHomeRows(visible, tier);
    final noDives = ref.watch(diveStatisticsProvider).value?.totalDives == 0;

    double rowHeight(HomeRow row) =>
        row.panels.first == HomePanelType.keyNumbers
        ? KeyNumbersPanel.heightFor(
            context,
            tier,
            KeyNumbersPanel.visibleTileCount(keyNumbers, hiddenTiles),
          )
        : homeRowHeight(row.height, context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeaderBar(),
            const HomeStatusStrip(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(ref),
                child: CustomScrollView(
                  slivers: [
                    // Demo mode's way out heads the page (issue #4436).
                    const SliverToBoxAdapter(child: DemoModeDashboardCard()),
                    // The species model offer, for a diver who would
                    // otherwise never hear of it (issue #4881).
                    const SliverToBoxAdapter(child: HomeSpeciesBanner()),
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      // The first-dive panel cannot be hidden, so an empty
                      // log keeps the grid even with every panel off. With
                      // dives, no panel to show (all off, or the ones on
                      // have nothing today) points at the settings.
                      sliver: visible.isEmpty && !noDives
                          ? const SliverToBoxAdapter(child: _AllHiddenState())
                          : DashboardGrid(
                              rows: rows,
                              panelBuilder: _panel,
                              rowHeight: rowHeight,
                              leadingFirst:
                                  rows.isEmpty ||
                                  rows.first.panels.first !=
                                      HomePanelType.keyNumbers,
                              leading: noDives
                                  ? SizedBox(
                                      height: homeRowHeight(
                                        HomePanelHeight.medium,
                                        context,
                                      ),
                                      child: const FirstDivePanel(),
                                    )
                                  : null,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _panel(HomePanelType panel) => switch (panel) {
    HomePanelType.keyNumbers => const KeyNumbersPanel(),
    HomePanelType.waitingForDownload => const WaitingForDownloadPanel(),
    HomePanelType.preDive => const PreDivePanel(),
    HomePanelType.activeCourses => const ActiveCoursePanel(),
    HomePanelType.activityCalendar => const ActivityCalendarPanel(),
    HomePanelType.recentOutings => const RecentOutingsPanel(),
    HomePanelType.gearService => const GearServicePanel(),
    HomePanelType.comingDue => const ComingDuePanel(),
    HomePanelType.nextTrip => const NextTripPanel(),
    HomePanelType.latestProfile => const LatestProfilePanel(),
    HomePanelType.latestVsAverage => const LatestVsAveragePanel(),
    HomePanelType.recentDives => const RecentDivesPanel(),
    HomePanelType.sacTrend => const SacTrendPanel(),
    HomePanelType.depthMix => const DepthMixPanel(),
    HomePanelType.divesPerMonth => const DivesPerMonthPanel(),
    HomePanelType.gasMix => const GasMixPanel(),
    HomePanelType.diveTypes => const DiveTypesPanel(),
    HomePanelType.topSites => const TopSitesPanel(),
    HomePanelType.topBuddies => const TopBuddiesPanel(),
    HomePanelType.speciesSeen => const SpeciesSeenPanel(),
    HomePanelType.photoRibbon => const PhotosPanel(),
    HomePanelType.recentSitesMap => const RecentSitesPanel(),
    HomePanelType.onThisDay => const OnThisDayPanel(),
  };

  /// Everything Home reads, so a pull to refresh reloads all of it.
  void _refresh(WidgetRef ref) {
    ref.invalidate(diveStatisticsProvider);
    ref.invalidate(recentDivesProvider);
    ref.invalidate(dashboardGaugesProvider);
    ref.invalidate(daysSinceLastDiveProvider);
    ref.invalidate(homeSpeciesCountProvider);
    ref.invalidate(yearInReviewProvider);
    ref.invalidate(recentMediaProvider);
    ref.invalidate(onThisDayProvider);
    ref.invalidate(recentSitesProvider);
    ref.invalidate(certificationListNotifierProvider);
    // The service clocks derive from this; invalidating the base forces a
    // fresh evaluation of every clock.
    ref.invalidate(activeEquipmentClocksProvider);
    ref.invalidate(activeCoursesProgressProvider);
    ref.invalidate(draftDivesProvider);
    ref.invalidate(homeTripChecklistProvider);
    ref.invalidate(homeActivityDaysProvider);
    ref.invalidate(homeMonthlyDivesProvider);
    ref.invalidate(homeSacSeriesProvider);
    ref.invalidate(homeAveragesProvider);
    ref.invalidate(homeGasMixProvider);
    ref.invalidate(homeDiveTypesProvider);
    ref.invalidate(homeTopBuddiesProvider);
    ref.invalidate(homeRecentSpeciesProvider);
    ref.invalidate(homeLatestProfileProvider);
    // Reads the documents itself, so it is not reached through the gauges.
    ref.invalidate(homeComingDueProvider);
    ref.invalidate(homeNewSpeciesThisYearProvider);
    ref.invalidate(homeDeepestThisYearProvider);
    ref.invalidate(homeKeyNumbersProvider);
  }
}

/// Shown when the diver has switched every panel off: points at the
/// settings page where they come back, instead of leaving a blank page.
class _AllHiddenState extends StatelessWidget {
  const _AllHiddenState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Column(
        children: [
          Text(
            l10n.dashboard_allHidden_message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.push('/settings/appearance/home'),
            child: Text(l10n.dashboard_allHidden_customize),
          ),
        ],
      ),
    );
  }
}
