import 'package:flutter/material.dart';

import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/widgets/active_course_progress_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/gauge_strip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/on_this_day_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/media_ribbon_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/year_in_review_card.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/pre_dive_dashboard_card.dart';

/// Maximum side cards a LeadSideGroup absorbs (mirrors the legacy layout).
const int _maxSideCards = 2;

bool _isSideCapable(HomeCardType card) =>
    card == HomeCardType.quickActions || card == HomeCardType.milestones;

Widget _sideWidget(HomeCardType card) => switch (card) {
  HomeCardType.quickActions => const QuickActionsCard(),
  HomeCardType.milestones => const MilestonesCard(),
  _ => throw ArgumentError('not side-capable: $card'),
};

DashboardEntry _standaloneEntry(HomeCardType card) => switch (card) {
  HomeCardType.hero => const FullBlock(HeroHeader()),
  HomeCardType.gaugeStrip => const FullBlock(GaugeStrip()),
  HomeCardType.preDive => const FullBlock(PreDiveDashboardCard()),
  HomeCardType.recentDives => const FullBlock(RecentDivesCard()),
  HomeCardType.quickActions => const ThirdBlock(QuickActionsCard()),
  HomeCardType.milestones => const ThirdBlock(MilestonesCard()),
  // The enum value keeps its photoRibbon name: it is persisted verbatim in
  // SharedPreferences as the user's home-card order, so renaming it would
  // drop the card from every existing layout and re-append it as new.
  HomeCardType.photoRibbon => const FullBlock(MediaRibbonCard()),
  HomeCardType.onThisDay => const ThirdBlock(OnThisDayCard()),
  HomeCardType.yearInReview => const ThirdBlock(YearInReviewCard()),
  HomeCardType.activeCourses => const ThirdBlock(ActiveCourseProgressCard()),
  HomeCardType.recentSitesMap => const FullBlock(RecentSitesMapCard()),
};

/// Packs the ordered visible cards into grid entries. Side-capable cards
/// (quickActions, milestones) directly following recentDives are absorbed
/// into its LeadSideGroup side column, exactly like the legacy hardcoded
/// layout; everywhere else every card has one fixed block shape.
List<DashboardEntry> buildDashboardEntries(List<HomeCardType> visibleCards) {
  final entries = <DashboardEntry>[];
  var i = 0;
  while (i < visibleCards.length) {
    final card = visibleCards[i];
    if (card == HomeCardType.recentDives) {
      final side = <Widget>[];
      var j = i + 1;
      while (j < visibleCards.length &&
          side.length < _maxSideCards &&
          _isSideCapable(visibleCards[j])) {
        side.add(_sideWidget(visibleCards[j]));
        j++;
      }
      entries.add(
        side.isEmpty
            ? const FullBlock(RecentDivesCard())
            : LeadSideGroup(lead: const RecentDivesCard(), side: side),
      );
      i = j;
    } else {
      entries.add(_standaloneEntry(card));
      i++;
    }
  }
  return entries;
}
