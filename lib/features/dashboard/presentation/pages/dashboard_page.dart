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
import 'package:submersion/features/dashboard/presentation/widgets/gauge_strip.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dashboard home page: monitor-first status gauges over a responsive
/// card grid that reflows from one phone column to a 3-column desktop
/// layout (one ordered block list drives both). The user's card order and
/// visibility come from settings, except that a live safety alert forces
/// the gauge strip to render (see [_hasSafetyAlert]).
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

    final gauges = ref.watch(dashboardGaugesProvider);
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

    // A live safety alert overrides the diver's choice to hide the gauge
    // strip: hardened chips are useless if the whole card they live in can
    // be switched off. Keyed off the same provider the strip itself reads,
    // so there is one definition of what counts as urgent.
    final forceGaugeStrip = show(gauges, _hasSafetyAlert);

    final orderedCards = reconcileHomeCardOrder(homeCardOrder);

    // The cards the diver actually asked for. Tracked separately from
    // visibleCards so a forced gauge strip cannot masquerade as "you still
    // have cards" and suppress the all-hidden CTA.
    final chosenCards = [
      for (final card in orderedCards)
        if (!hiddenHomeCards.contains(card.name) && hasContent(card)) card,
    ];

    // The forced strip keeps its natural position in the order rather than
    // being pinned to the top: it is a card that came back, not a banner.
    final visibleCards = [
      for (final card in orderedCards)
        if ((!hiddenHomeCards.contains(card.name) ||
                (card == HomeCardType.gaugeStrip && forceGaugeStrip)) &&
            hasContent(card))
          card,
    ];

    final entries = buildDashboardEntries(visibleCards);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(diveStatisticsProvider);
            ref.invalidate(recentDivesProvider);
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
            // Keyed off chosenCards, not visibleCards: a strip forced back
            // by a safety alert renders above the CTA rather than replacing
            // it, so the diver keeps the route to re-enable their cards.
            child: chosenCards.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (forceGaugeStrip) ...[
                        const GaugeStrip(),
                        const SizedBox(height: 16),
                      ],
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

/// Whether the gauge strip is currently carrying a dive-safety fact the diver
/// cannot dismiss: lapsed gear service, an expired insurance policy, or a
/// flight window that is shut.
///
/// GaugeStrip hardens these three chip types against the hidden-chips setting;
/// this is the matching guard one level up, so hiding the whole strip card
/// cannot suppress them either. Currency and backup-age chips can also go red
/// but are deliberately absent: they are habit nags, and hiding one is a
/// legitimate choice.
bool _hasSafetyAlert(DashboardGauges g) {
  final insurance = g.insurance;
  // Mirrors GaugeStrip's expired branch, which only fires on a real policy:
  // a diver with no insurance recorded gets a neutral chip, not an alert, so
  // it must not force the strip open either.
  final expiredPolicy =
      insurance != null &&
      insurance.providerLabel != null &&
      insurance.isExpired;
  // Overflow counts as overdue gear in its own right. With the shipped caps
  // it can only be positive alongside a shown overdue gauge, so this clause
  // is currently redundant; it is here so the guard states the same rule
  // GaugeStrip does (an alert-tone "+N more overdue" chip), rather than
  // depending on the cap values to keep the two in agreement.
  return g.gearOverdueOverflow > 0 ||
      g.gearGauges.any(
        (gauge) => gauge.status.severity == ServiceClockSeverity.overdue,
      ) ||
      expiredPolicy ||
      g.flightWindow?.state == FlightWindowState.closed ||
      g.flightWindow?.state == FlightWindowState.conflict;
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
