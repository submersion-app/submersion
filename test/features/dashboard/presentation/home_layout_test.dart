import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';

void main() {
  group('buildDashboardEntries', () {
    test('default order reproduces the legacy block structure', () {
      final entries = buildDashboardEntries(HomeCardType.values);
      // hero, gaugeStrip, preDive as FullBlocks; recentDives absorbs
      // quickActions + milestones into a LeadSideGroup; then photoRibbon
      // (Full), onThisDay/yearInReview/activeCourses (Thirds),
      // recentSitesMap (Full).
      expect(entries, hasLength(9));
      expect(entries[0], isA<FullBlock>());
      expect(entries[1], isA<FullBlock>());
      expect(entries[2], isA<FullBlock>());
      final group = entries[3] as LeadSideGroup;
      expect(group.lead, isA<RecentDivesCard>());
      expect(group.side, hasLength(2));
      expect(group.side[0], isA<QuickActionsCard>());
      expect(group.side[1], isA<MilestonesCard>());
      expect(entries[4], isA<FullBlock>());
      expect(entries[5], isA<ThirdBlock>());
      expect(entries[6], isA<ThirdBlock>());
      expect(entries[7], isA<ThirdBlock>());
      expect(entries.last, isA<FullBlock>());
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
