import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

class SpeciesDetailPage extends ConsumerWidget {
  final String speciesId;

  const SpeciesDetailPage({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesAsync = ref.watch(speciesProvider(speciesId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit species',
            onPressed: () => context.push('/species/$speciesId/edit'),
          ),
        ],
      ),
      body: speciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (species) {
          if (species == null) {
            return const Center(child: Text('Species not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  context,
                  species.commonName,
                  species.scientificName,
                  species.category,
                ),
                if (species.taxonomyClass != null) ...[
                  const SizedBox(height: 8),
                  _buildTaxonomyBadge(context, species.taxonomyClass!),
                ],
                if (species.description != null &&
                    species.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDescription(context, species.description!),
                ],
                const SizedBox(height: 24),
                _buildStatisticsSection(context, ref),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String commonName,
    String? scientificName,
    SpeciesCategory category,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commonName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (scientificName != null && scientificName.isNotEmpty)
                    Text(
                      scientificName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(178),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(category.displayName),
          backgroundColor: _getCategoryColor(category).withAlpha(30),
          side: BorderSide(color: _getCategoryColor(category).withAlpha(77)),
        ),
      ],
    );
  }

  Widget _buildTaxonomyBadge(BuildContext context, String taxonomyClass) {
    return Row(
      children: [
        Icon(
          Icons.science_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
        ),
        const SizedBox(width: 4),
        Text(
          'Class: $taxonomyClass',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(speciesStatisticsProvider(speciesId));

    return statsAsync.when(
      loading: () => const Card(
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(77),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No sightings recorded yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildStatsCards(context, ref, stats);
      },
    );
  }

  Widget _buildStatsCards(
    BuildContext context,
    WidgetRef ref,
    SpeciesStatistics stats,
  ) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sighting Statistics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        // Summary row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.visibility,
                label: 'Total Sightings',
                value: stats.totalSightings.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.scuba_diving,
                label: 'Dives',
                value: stats.diveCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.place,
                label: 'Sites',
                value: stats.siteCount.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Depth range
        if (stats.minDepthMeters != null && stats.maxDepthMeters != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Depth Range'),
              subtitle: Text(
                '${units.formatDepth(stats.minDepthMeters)} - '
                '${units.formatDepth(stats.maxDepthMeters)}',
              ),
            ),
          ),
        // Date range
        if (stats.firstSeen != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Sighting Period'),
              subtitle: Text(
                stats.lastSeen != null && stats.firstSeen != stats.lastSeen
                    ? '${units.formatDate(stats.firstSeen)} - '
                          '${units.formatDate(stats.lastSeen)}'
                    : units.formatDate(stats.firstSeen),
              ),
            ),
          ),
        // Top sites
        if (stats.topSites.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Top Sites',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...stats.topSites.map(
            (site) => Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(site.name),
                trailing: Text(
                  '${site.count} sighting${site.count == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => context.push('/sites/${site.id}'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(SpeciesCategory category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Icons.water;
      case SpeciesCategory.shark:
        return Icons.water;
      case SpeciesCategory.ray:
        return Icons.water;
      case SpeciesCategory.mammal:
        return Icons.water;
      case SpeciesCategory.turtle:
        return Icons.water;
      case SpeciesCategory.invertebrate:
        return Icons.bug_report;
      case SpeciesCategory.coral:
        return Icons.park;
      case SpeciesCategory.plant:
        return Icons.grass;
      case SpeciesCategory.other:
        return Icons.pets;
    }
  }

  Color _getCategoryColor(SpeciesCategory category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Colors.blue;
      case SpeciesCategory.shark:
        return Colors.blueGrey;
      case SpeciesCategory.ray:
        return Colors.indigo;
      case SpeciesCategory.mammal:
        return Colors.teal;
      case SpeciesCategory.turtle:
        return Colors.green;
      case SpeciesCategory.invertebrate:
        return Colors.orange;
      case SpeciesCategory.coral:
        return Colors.pink;
      case SpeciesCategory.plant:
        return Colors.lightGreen;
      case SpeciesCategory.other:
        return Colors.grey;
    }
  }
}
