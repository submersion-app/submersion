import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';

class StatisticsGeographicPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsGeographicPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountriesSection(context, ref),
          const SizedBox(height: 16),
          _buildRegionsSection(context, ref),
          const SizedBox(height: 16),
          _buildTripsSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Geographic')),
      body: content,
    );
  }

  Widget _buildCountriesSection(BuildContext context, WidgetRef ref) {
    final countriesAsync = ref.watch(countriesVisitedProvider);

    return StatSectionCard(
      title: 'Countries Visited',
      subtitle: 'Dives by country',
      child: countriesAsync.when(
        data: (data) =>
            RankingList(items: data, countLabel: 'dives', maxItems: 10),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load country data',
        ),
      ),
    );
  }

  Widget _buildRegionsSection(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(regionsExploredProvider);

    return StatSectionCard(
      title: 'Regions Explored',
      subtitle: 'Dives by region',
      child: regionsAsync.when(
        data: (data) =>
            RankingList(items: data, countLabel: 'dives', maxItems: 10),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load region data',
        ),
      ),
    );
  }

  Widget _buildTripsSection(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(divesPerTripProvider);

    return StatSectionCard(
      title: 'Dives Per Trip',
      subtitle: 'Most productive trips',
      child: tripsAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: 'dives',
          maxItems: 10,
          onItemTap: (item) => context.push('/trips/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load trip data',
        ),
      ),
    );
  }
}
