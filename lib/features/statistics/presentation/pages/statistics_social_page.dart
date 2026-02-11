import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsSocialPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsSocialPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSoloVsBuddySection(context, ref),
          const SizedBox(height: 16),
          _buildTopBuddiesSection(context, ref),
          const SizedBox(height: 16),
          _buildTopDiveCentersSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.statistics_social_appBar_title)),
      body: content,
    );
  }

  Widget _buildSoloVsBuddySection(BuildContext context, WidgetRef ref) {
    final soloVsBuddyAsync = ref.watch(soloVsBuddyCountProvider);

    return StatSectionCard(
      title: context.l10n.statistics_social_soloVsBuddy_title,
      subtitle: context.l10n.statistics_social_soloVsBuddy_subtitle,
      child: soloVsBuddyAsync.when(
        data: (data) {
          final total = data.solo + data.buddy;
          if (total == 0) {
            return StatEmptyState(
              icon: Icons.people,
              message: context.l10n.statistics_social_soloVsBuddy_empty,
            );
          }

          return DistributionPieChart(
            data: [
              DistributionSegment(
                label: context.l10n.statistics_social_soloVsBuddy_withBuddy,
                count: data.buddy,
                percentage: data.buddy / total * 100,
              ),
              DistributionSegment(
                label: context.l10n.statistics_social_soloVsBuddy_solo,
                count: data.solo,
                percentage: data.solo / total * 100,
              ),
            ],
            colors: const [Colors.green, Colors.orange],
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_social_soloVsBuddy_error,
        ),
      ),
    );
  }

  Widget _buildTopBuddiesSection(BuildContext context, WidgetRef ref) {
    final topBuddiesAsync = ref.watch(topBuddiesProvider);

    return StatSectionCard(
      title: context.l10n.statistics_social_topBuddies_title,
      subtitle: context.l10n.statistics_social_topBuddies_subtitle,
      child: topBuddiesAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: context.l10n.statistics_ranking_countLabel_dives,
          maxItems: 5,
          onItemTap: (item) => context.push('/buddies/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_social_topBuddies_error,
        ),
      ),
    );
  }

  Widget _buildTopDiveCentersSection(BuildContext context, WidgetRef ref) {
    final topCentersAsync = ref.watch(topDiveCentersProvider);

    return StatSectionCard(
      title: context.l10n.statistics_social_topDiveCenters_title,
      subtitle: context.l10n.statistics_social_topDiveCenters_subtitle,
      child: topCentersAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: context.l10n.statistics_ranking_countLabel_dives,
          maxItems: 5,
          onItemTap: (item) => context.push('/dive-centers/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_social_topDiveCenters_error,
        ),
      ),
    );
  }
}
