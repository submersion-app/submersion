import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/photo_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/active_course_progress_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/gauge_strip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/on_this_day_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/photo_ribbon_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/urgent_banner.dart';
import 'package:submersion/features/dashboard/presentation/widgets/year_in_review_card.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/pre_dive_dashboard_card.dart';

/// Dashboard home page: monitor-first status gauges over a responsive
/// card grid that reflows from one phone column to a 3-column desktop
/// layout (one ordered block list drives both).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Conditional-block gating: a block is included only once its provider
    // has resolved to content. Loading and error both resolve to excluded,
    // because these cards render SizedBox.shrink() when they have nothing
    // to show and a zero-height block would still consume a grid row gap
    // (phantom spacing). Always-on blocks contain their own error state.
    bool show<T>(AsyncValue<T> value, bool Function(T data) hasContent) =>
        value.maybeWhen(data: hasContent, orElse: () => false);

    final alerts = ref.watch(dashboardAlertsProvider);
    final milestones = ref.watch(milestonesProvider);
    final photos = ref.watch(recentPhotosProvider);
    final onThisDay = ref.watch(onThisDayProvider);
    final yearInReview = ref.watch(yearInReviewProvider);
    final courses = ref.watch(activeCoursesProgressProvider);
    final sites = ref.watch(recentSitesProvider);

    final entries = <DashboardEntry>[
      const FullBlock(HeroHeader()),
      const FullBlock(GaugeStrip()),
      if (show(
        alerts,
        (a) =>
            a.serviceClocksDue.any(
              (c) => c.status.severity == ServiceClockSeverity.overdue,
            ) ||
            a.insuranceExpired,
      ))
        const FullBlock(UrgentBanner()),
      const FullBlock(PreDiveDashboardCard()),
      LeadSideGroup(
        lead: const RecentDivesCard(),
        side: [
          const QuickActionsCard(),
          if (show(milestones, (m) => !m.isEmpty)) const MilestonesCard(),
        ],
      ),
      if (show(photos, (p) => p.isNotEmpty)) const FullBlock(PhotoRibbonCard()),
      if (show(onThisDay, (d) => d.isNotEmpty))
        const ThirdBlock(OnThisDayCard()),
      if (show(yearInReview, (y) => y != null))
        const ThirdBlock(YearInReviewCard()),
      if (show(courses, (c) => c.isNotEmpty))
        const ThirdBlock(ActiveCourseProgressCard()),
      if (show(sites, (s) => s.isNotEmpty))
        const FullBlock(RecentSitesMapCard()),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(diveStatisticsProvider);
            ref.invalidate(recentDivesProvider);
            ref.invalidate(dashboardAlertsProvider);
            ref.invalidate(dashboardGaugesProvider);
            ref.invalidate(daysSinceLastDiveProvider);
            ref.invalidate(dashboardQuickStatsProvider);
            ref.invalidate(milestonesProvider);
            ref.invalidate(recentPhotosProvider);
            ref.invalidate(onThisDayProvider);
            ref.invalidate(yearInReviewProvider);
            ref.invalidate(recentSitesProvider);
            ref.invalidate(certificationListNotifierProvider);
            // dueClocksProvider derives from this; invalidating the base
            // forces a fresh per-item clock evaluation on pull-to-refresh.
            ref.invalidate(activeEquipmentClocksProvider);
            ref.invalidate(activeCoursesProgressProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: DashboardGrid(entries: entries),
          ),
        ),
      ),
    );
  }
}
