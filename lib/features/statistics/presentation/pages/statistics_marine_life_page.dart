import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';

class StatisticsMarineLifePage extends ConsumerWidget {
  final bool embedded;

  const StatisticsMarineLifePage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(context, ref),
          const SizedBox(height: 16),
          _buildMostCommonSection(context, ref),
          const SizedBox(height: 16),
          _buildBestSitesSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Marine Life')),
      body: content,
    );
  }

  Widget _buildOverviewSection(BuildContext context, WidgetRef ref) {
    final speciesCountAsync = ref.watch(uniqueSpeciesCountProvider);

    return speciesCountAsync.when(
      data: (count) => Row(
        children: [
          Expanded(
            child: StatValueCard(
              icon: Icons.pets,
              label: 'Species Spotted',
              value: count.toString(),
              iconColor: Colors.teal,
            ),
          ),
        ],
      ),
      loading: () => const Card(
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildMostCommonSection(BuildContext context, WidgetRef ref) {
    final sightingsAsync = ref.watch(mostCommonSightingsProvider);

    return StatSectionCard(
      title: 'Most Common Sightings',
      subtitle: 'Species spotted most often',
      child: sightingsAsync.when(
        data: (data) =>
            RankingList(items: data, countLabel: 'sightings', maxItems: 10),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load sighting data',
        ),
      ),
    );
  }

  Widget _buildBestSitesSection(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(bestSitesForMarineLifeProvider);

    return StatSectionCard(
      title: 'Best Sites for Marine Life',
      subtitle: 'Sites with most species variety',
      child: sitesAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: 'species',
          maxItems: 10,
          onItemTap: (item) => context.push('/sites/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load site data',
        ),
      ),
    );
  }
}
