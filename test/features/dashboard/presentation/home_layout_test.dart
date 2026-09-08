import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/media_ribbon_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/year_in_review_card.dart';

void main() {
  group('buildDashboardEntries', () {
    test('default order builds the reorganized block structure', () {
      final entries = buildDashboardEntries(HomeCardType.values);
      // hero, gaugeStrip, preDive as FullBlocks; recentDives absorbs
      // quickActions + milestones + yearInReview into a LeadSideGroup;
      // photoRibbon + recentSitesMap pair up; onThisDay and activeCourses
      // trail as Thirds.
      expect(entries, hasLength(7));
      expect(entries[0], isA<FullBlock>());
      expect(entries[1], isA<FullBlock>());
      expect(entries[2], isA<FullBlock>());
      final group = entries[3] as LeadSideGroup;
      expect(group.lead, isA<RecentDivesCard>());
      expect(group.side, hasLength(3));
      expect(group.side[0], isA<QuickActionsCard>());
      expect(group.side[1], isA<MilestonesCard>());
      expect(group.side[2], isA<YearInReviewCard>());
      final pair = entries[4] as PairBlock;
      expect(pair.first, isA<MediaRibbonCard>());
      expect(pair.second, isA<RecentSitesMapCard>());
      expect(entries[5], isA<ThirdBlock>());
      expect(entries[6], isA<ThirdBlock>());
    });

    test('paired media ribbon asks for two rows', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.photoRibbon,
        HomeCardType.recentSitesMap,
      ]);
      final pair = entries.single as PairBlock;
      expect((pair.first as MediaRibbonCard).rows, 2);
    });

    test('sites before media pairs in that visual order', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.recentSitesMap,
        HomeCardType.photoRibbon,
      ]);
      final pair = entries.single as PairBlock;
      expect(pair.first, isA<RecentSitesMapCard>());
      expect(pair.second, isA<MediaRibbonCard>());
      expect((pair.second as MediaRibbonCard).rows, 2);
    });

    test('media and sites pair only when adjacent', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.photoRibbon,
        HomeCardType.onThisDay,
        HomeCardType.recentSitesMap,
      ]);
      expect(entries, hasLength(3));
      expect(entries[0], isA<FullBlock>());
      expect(entries[1], isA<ThirdBlock>());
      expect(entries[2], isA<FullBlock>());
    });

    test('an unpaired media ribbon keeps its single row', () {
      final entries = buildDashboardEntries(const [HomeCardType.photoRibbon]);
      final block = entries.single as FullBlock;
      expect((block.child as MediaRibbonCard).rows, 1);
    });

    test('yearInReview is side-capable on its own, without milestones', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.recentDives,
        HomeCardType.yearInReview,
      ]);
      final group = entries.single as LeadSideGroup;
      expect(group.side, hasLength(1));
      expect(group.side.single, isA<YearInReviewCard>());
    });

    test('the side column absorbs at most three cards', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.recentDives,
        HomeCardType.quickActions,
        HomeCardType.milestones,
        HomeCardType.yearInReview,
        HomeCardType.onThisDay,
      ]);
      expect(entries, hasLength(2));
      expect((entries[0] as LeadSideGroup).side, hasLength(3));
      expect(entries[1], isA<ThirdBlock>());
    });

    test('side cards absorb only when immediately after recentDives', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.quickActions,
        HomeCardType.recentDives,
        HomeCardType.milestones,
      ]);
      expect(entries, hasLength(2));
      expect(entries[0], isA<ThirdBlock>());
      final group = entries[1] as LeadSideGroup;
      expect(group.side, hasLength(1));
      expect(group.side.single, isA<MilestonesCard>());
    });

    test('recentDives with no following side cards is a FullBlock', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.recentDives,
        HomeCardType.photoRibbon,
      ]);
      expect(entries[0], isA<FullBlock>());
      expect((entries[0] as FullBlock).child, isA<RecentDivesCard>());
    });

    test('side cards without recentDives render as ThirdBlocks', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.quickActions,
        HomeCardType.milestones,
      ]);
      expect(entries, hasLength(2));
      expect(entries[0], isA<ThirdBlock>());
      expect(entries[1], isA<ThirdBlock>());
    });

    test('a non-side card directly after recentDives is never absorbed', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.recentDives,
        HomeCardType.onThisDay,
      ]);
      expect(entries[0], isA<FullBlock>());
      expect(entries[1], isA<ThirdBlock>());
    });

    test('empty input produces no entries', () {
      expect(buildDashboardEntries(const []), isEmpty);
    });
  });
}
