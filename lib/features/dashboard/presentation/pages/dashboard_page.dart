import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/urgent_banner.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dashboard home page: monitor-first status gauges over a responsive
/// card grid that reflows from one phone column to a 3-column desktop
/// layout (one ordered block list drives both). The user's card order and
/// visibility come from settings; the urgent banner is pinned on top.
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
    final media = ref.watch(recentMediaProvider);
    final onThisDay = ref.watch(onThisDayProvider);
    final yearInReview = ref.watch(yearInReviewProvider);
    final courses = ref.watch(activeCoursesProgressProvider);
    final sites = ref.watch(recentSitesProvider);

    final homeCardOrder = ref.watch(
      settingsProvider.select((s) => s.homeCardOrder),
    );
    final hiddenHomeCards = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeCards),
    );

    bool hasContent(HomeCardType card) => switch (card) {
      HomeCardType.milestones => show(milestones, (m) => !m.isEmpty),
      HomeCardType.photoRibbon => show(media, (m) => m.isNotEmpty),
      HomeCardType.onThisDay => show(onThisDay, (d) => d.isNotEmpty),
      HomeCardType.yearInReview => show(yearInReview, (y) => y != null),
      HomeCardType.activeCourses => show(courses, (c) => c.isNotEmpty),
      HomeCardType.recentSitesMap => show(sites, (s) => s.isNotEmpty),
      _ => true,
    };

    final visibleCards = [
      for (final card in reconcileHomeCardOrder(homeCardOrder))
        if (!hiddenHomeCards.contains(card.name) && hasContent(card)) card,
    ];

    final showUrgent = show(
      alerts,
      (a) =>
          a.serviceClocksDue.any(
            (c) => c.status.severity == ServiceClockSeverity.overdue,
          ) ||
          a.insuranceExpired,
    );

    // The urgent banner is pinned: never hideable, never reorderable,
    // always above all customizable content.
    final entries = <DashboardEntry>[
      if (showUrgent) const FullBlock(UrgentBanner()),
      ...buildDashboardEntries(visibleCards),
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
            ref.invalidate(recentMediaProvider);
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
            // Keyed off visibleCards, not entries: entries includes the
            // pinned urgent banner, which must not suppress the
            // all-cards-hidden CTA (it renders above it instead).
            child: visibleCards.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showUrgent) const UrgentBanner(),
                      const _AllCardsHiddenState(),
                    ],
                  )
                : DashboardGrid(entries: entries),
          ),
        ),
      ),
    );
  }
}

/// Shown when the user has hidden every home card: points at the settings
/// page where cards can be re-enabled instead of leaving a blank page.
class _AllCardsHiddenState extends StatelessWidget {
  const _AllCardsHiddenState();

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
