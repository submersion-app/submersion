import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';

/// A section showing recent dives with the same tile format as the dive list
class RecentDivesCard extends ConsumerWidget {
  const RecentDivesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentDivesAsync = ref.watch(recentDivesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with padding to match the card margins
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Dives',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/dives'),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        recentDivesAsync.when(
          data: (dives) {
            if (dives.isEmpty) {
              return _buildEmptyState(context);
            }

            // Calculate depth range for relative depth coloring
            final depthsWithValues = dives
                .where((d) => d.maxDepth != null)
                .map((d) => d.maxDepth!);
            final minDepth = depthsWithValues.isNotEmpty
                ? depthsWithValues.reduce((a, b) => a < b ? a : b)
                : null;
            final maxDepth = depthsWithValues.isNotEmpty
                ? depthsWithValues.reduce((a, b) => a > b ? a : b)
                : null;

            return Column(
              children: dives.asMap().entries.map((entry) {
                final index = entry.key;
                final dive = entry.value;
                return DiveListTile(
                  diveId: dive.id,
                  diveNumber: dive.diveNumber ?? index + 1,
                  dateTime: dive.dateTime,
                  siteName: dive.site?.name,
                  siteLocation: dive.site?.locationString,
                  maxDepth: dive.maxDepth,
                  duration: dive.duration,
                  waterTemp: dive.waterTemp,
                  rating: dive.rating,
                  isFavorite: dive.isFavorite,
                  tags: dive.tags,
                  minDepthInList: minDepth,
                  maxDepthInList: maxDepth,
                  siteLatitude: dive.site?.location?.latitude,
                  siteLongitude: dive.site?.location?.longitude,
                  onTap: () => context.push('/dives/${dive.id}'),
                );
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load dives',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.waves_outlined,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No dives logged yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/dives/new'),
              icon: const Icon(Icons.add),
              label: const Text('Log Your First Dive'),
            ),
          ],
        ),
      ),
    );
  }
}
