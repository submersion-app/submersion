import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';

/// Summary widget shown when no dive center is selected.
class DiveCenterSummaryWidget extends ConsumerWidget {
  const DiveCenterSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centersAsync = ref.watch(diveCenterListNotifierProvider);
    final countriesAsync = ref.watch(diveCenterCountriesProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            centersAsync.when(
              data: (centers) => _buildOverview(context, ref, centers),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 24),
            countriesAsync.when(
              data: (countries) => countries.isNotEmpty
                  ? _buildCountriesSection(context, countries)
                  : const SizedBox(),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.store,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Dive Centers',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select a dive center from the list to view details',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(BuildContext context, WidgetRef ref, List centers) {
    // Find highest rated center
    double? highestRating;
    String? highestRatedName;
    int withCoordinates = 0;

    for (final center in centers) {
      if (center.rating != null) {
        if (highestRating == null || center.rating > highestRating) {
          highestRating = center.rating;
          highestRatedName = center.name;
        }
      }
      if (center.latitude != null && center.longitude != null) {
        withCoordinates++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.store,
              value: '${centers.length}',
              label: 'Total Centers',
              color: Colors.blue,
            ),
            if (highestRating != null)
              _buildStatCard(
                context,
                icon: Icons.star,
                value: highestRating.toStringAsFixed(1),
                label: 'Highest Rating',
                color: Colors.amber.shade700,
              ),
            if (withCoordinates > 0)
              _buildStatCard(
                context,
                icon: Icons.location_on,
                value: '$withCoordinates',
                label: 'With GPS',
                color: Colors.green,
              ),
          ],
        ),
        if (centers.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildCenterListPreview(context, centers),
        ],
        if (highestRatedName != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Rated',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.amber.shade900),
                        ),
                        Text(
                          highestRatedName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
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
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterListPreview(BuildContext context, List centers) {
    final previewCenters = centers.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Dive Centers',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: previewCenters.map((center) {
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(center.name),
                subtitle: center.fullLocationString != null
                    ? Text(center.fullLocationString!)
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (center.rating != null) ...[
                      Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(center.rating!.toStringAsFixed(1)),
                      const SizedBox(width: 8),
                    ],
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  final state = GoRouterState.of(context);
                  final currentPath = state.uri.path;
                  context.go('$currentPath?selected=${center.id}');
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCountriesSection(BuildContext context, List<String> countries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Countries',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: countries.map((country) {
            return Chip(
              avatar: const Icon(Icons.flag, size: 16),
              label: Text(country),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.go('$currentPath?mode=new');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Dive Center'),
            ),
          ],
        ),
      ],
    );
  }
}
