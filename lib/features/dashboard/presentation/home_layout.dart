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

/// Maximum side cards a LeadSideGroup absorbs. Three short cards stack to
/// roughly the height of the RecentDivesCard they sit beside.
const int _maxSideCards = 3;

bool _isSideCapable(HomeCardType card) =>
    card == HomeCardType.quickActions ||
    card == HomeCardType.milestones ||
    card == HomeCardType.yearInReview;

Widget _sideWidget(HomeCardType card) => switch (card) {
  HomeCardType.quickActions => const QuickActionsCard(),
  HomeCardType.milestones => const MilestonesCard(),
  HomeCardType.yearInReview => const YearInReviewCard(),
  _ => throw ArgumentError('not side-capable: $card'),
};

/// The two cards that share a row when they sit next to each other. The map
/// is the taller of the pair, so the ribbon beside it stacks its tiles into
/// [_pairedMediaRows] rows to reach the same height.
bool _pairsWith(HomeCardType a, HomeCardType b) =>
    (a == HomeCardType.photoRibbon && b == HomeCardType.recentSitesMap) ||
    (a == HomeCardType.recentSitesMap && b == HomeCardType.photoRibbon);

const int _pairedMediaRows = 2;

Widget _pairedWidget(HomeCardType card) => card == HomeCardType.photoRibbon
    ? const MediaRibbonCard(rows: _pairedMediaRows)
    : const RecentSitesMapCard();

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

/// Packs the ordered visible cards into grid entries. Two adjacency rules
/// shape the result, both driven by the diver's own card order rather than
/// overriding it:
/// - side-capable cards (quickActions, milestones, yearInReview) directly
///   following recentDives are absorbed into its LeadSideGroup side column;
/// - an adjacent photoRibbon and recentSitesMap become a PairBlock, sharing
///   one row at desktop widths.
///
/// Everywhere else every card has one fixed block shape.
List<DashboardEntry> buildDashboardEntries(List<HomeCardType> visibleCards) {
  final entries = <DashboardEntry>[];
  var i = 0;
  while (i < visibleCards.length) {
    final card = visibleCards[i];
    if (i + 1 < visibleCards.length && _pairsWith(card, visibleCards[i + 1])) {
      entries.add(
        PairBlock(
          first: _pairedWidget(card),
          second: _pairedWidget(visibleCards[i + 1]),
        ),
      );
      i += 2;
    } else if (card == HomeCardType.recentDives) {
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
