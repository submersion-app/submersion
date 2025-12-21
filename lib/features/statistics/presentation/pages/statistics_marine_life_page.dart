import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/statistics_providers.dart';
import '../widgets/ranking_list.dart';
import '../widgets/stat_section_card.dart';

class StatisticsMarineLifePage extends ConsumerWidget {
  const StatisticsMarineLifePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marine Life'),
      ),
      body: SingleChildScrollView(
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
      ),
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
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMostCommonSection(BuildContext context, WidgetRef ref) {
    final sightingsAsync = ref.watch(mostCommonSightingsProvider);

    return StatSectionCard(
      title: 'Most Common Sightings',
      subtitle: 'Species spotted most often',
      child: sightingsAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: 'sightings',
          maxItems: 10,
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
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
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load site data',
        ),
      ),
    );
  }
}
