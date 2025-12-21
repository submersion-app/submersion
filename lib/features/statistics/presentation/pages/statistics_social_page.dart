import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/statistics_repository.dart';
import '../providers/statistics_providers.dart';
import '../widgets/ranking_list.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

class StatisticsSocialPage extends ConsumerWidget {
  const StatisticsSocialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social & Buddies'),
      ),
      body: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildSoloVsBuddySection(BuildContext context, WidgetRef ref) {
    final soloVsBuddyAsync = ref.watch(soloVsBuddyCountProvider);

    return StatSectionCard(
      title: 'Solo vs Buddy Dives',
      subtitle: 'Diving with or without companions',
      child: soloVsBuddyAsync.when(
        data: (data) {
          final total = data.solo + data.buddy;
          if (total == 0) {
            return const StatEmptyState(
              icon: Icons.people,
              message: 'No dive data available',
            );
          }

          return DistributionPieChart(
            data: [
              DistributionSegment(
                label: 'With Buddy',
                count: data.buddy,
                percentage: data.buddy / total * 100,
              ),
              DistributionSegment(
                label: 'Solo',
                count: data.solo,
                percentage: data.solo / total * 100,
              ),
            ],
            colors: [Colors.green, Colors.orange],
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load buddy data',
        ),
      ),
    );
  }

  Widget _buildTopBuddiesSection(BuildContext context, WidgetRef ref) {
    final topBuddiesAsync = ref.watch(topBuddiesProvider);

    return StatSectionCard(
      title: 'Top Dive Buddies',
      subtitle: 'Most frequent diving companions',
      child: topBuddiesAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: 'dives',
          maxItems: 5,
          onItemTap: (item) => context.push('/buddies/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load buddy rankings',
        ),
      ),
    );
  }

  Widget _buildTopDiveCentersSection(BuildContext context, WidgetRef ref) {
    final topCentersAsync = ref.watch(topDiveCentersProvider);

    return StatSectionCard(
      title: 'Top Dive Centers',
      subtitle: 'Most visited operators',
      child: topCentersAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: 'dives',
          maxItems: 5,
          onItemTap: (item) => context.push('/dive-centers/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load dive center rankings',
        ),
      ),
    );
  }
}
