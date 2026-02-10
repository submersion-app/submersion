import 'package:flutter/material.dart';
import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';

/// Page for managing offline map regions.
///
/// Displays cache statistics, active download progress, and a list of
/// downloaded regions. Allows users to delete individual regions or
/// clear all cached map data.
class OfflineMapsPage extends ConsumerWidget {
  const OfflineMapsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(cachedRegionsProvider);
    final cacheStatsAsync = ref.watch(cacheStatsProvider);
    final downloadState = ref.watch(downloadProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All Cache',
            onPressed: () => _showClearCacheDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cachedRegionsProvider);
          ref.invalidate(cacheStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cache statistics card
            cacheStatsAsync.when(
              data: (stats) => _buildStatsCard(context, stats),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading stats: $e'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Download progress (if active)
            if (downloadState.isDownloading) ...[
              _buildDownloadProgressCard(context, ref, downloadState),
              const SizedBox(height: 16),
            ],

            // Downloaded regions header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloaded Regions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.invalidate(cachedRegionsProvider);
                    ref.invalidate(cacheStatsProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Regions list
            regionsAsync.when(
              data: (regions) => regions.isEmpty
                  ? _buildEmptyState(context)
                  : Column(
                      children: regions
                          .map((r) => _buildRegionTile(context, ref, r))
                          .toList(),
                    ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Error: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, CacheStats stats) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text('Cache Statistics', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.grid_view,
                    label: 'Tiles',
                    value: stats.tileCount.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.data_usage,
                    label: 'Size',
                    value: stats.formattedSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.check_circle_outline,
                    label: 'Cache Hits',
                    value: stats.hits.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.cancel_outlined,
                    label: 'Cache Misses',
                    value: stats.misses.toString(),
                  ),
                ),
              ],
            ),
            if (stats.hits + stats.misses > 0) ...[
              const SizedBox(height: 12),
              Semantics(
                label:
                    'Cache hit rate: ${stats.hitRate.toStringAsFixed(1)} percent',
                child: LinearProgressIndicator(
                  value: stats.hitRate / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hit Rate: ${stats.hitRate.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      label: statLabel(name: label, value: value),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgressCard(
    BuildContext context,
    WidgetRef ref,
    DownloadState state,
  ) {
    final theme = Theme.of(context);
    final progressPercent = state.progress.clamp(0.0, 100.0);
    final notifier = ref.read(downloadProgressProvider.notifier);

    return Semantics(
      label:
          'Downloading ${state.regionName ?? "Region"}, '
          '${progressPercent.toStringAsFixed(1)} percent complete, '
          '${state.downloadedTiles} of ${state.totalTiles} tiles',
      liveRegion: true,
      child: Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.downloading,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Downloading: ${state.regionName ?? "Region"}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.cancel,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    tooltip: 'Cancel Download',
                    onPressed: () => notifier.cancelDownload(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progressPercent / 100,
                backgroundColor: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.2),
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progressPercent.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${state.downloadedTiles} / ${state.totalTiles} tiles',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              if (state.tilesPerSecond > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${state.tilesPerSecond.toStringAsFixed(1)} tiles/sec',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
              if (state.failedTiles > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${state.failedTiles} failed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.map_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Offline Regions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download map regions from the site detail page '
              'to use maps while offline.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionTile(
    BuildContext context,
    WidgetRef ref,
    CachedRegion region,
  ) {
    final theme = Theme.of(context);

    return Semantics(
      label: listItemLabel(
        title: region.name,
        subtitle:
            '${region.formattedSize}, ${region.tileCount} tiles, '
            'zoom ${region.minZoom} to ${region.maxZoom}',
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.map, color: theme.colorScheme.onPrimaryContainer),
          ),
          title: Text(region.name),
          subtitle: Text(
            '${region.formattedSize} | ${region.tileCount} tiles | '
            'Zoom ${region.minZoom}-${region.maxZoom}',
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            tooltip: 'Delete ${region.name} region',
            onPressed: () => _confirmDeleteRegion(context, ref, region),
          ),
          onTap: () => _showRegionDetails(context, region),
        ),
      ),
    );
  }

  void _showRegionDetails(BuildContext context, CachedRegion region) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(region.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildDetailRow(context, 'Size', region.formattedSize),
            _buildDetailRow(context, 'Tiles', region.tileCount.toString()),
            _buildDetailRow(
              context,
              'Zoom Range',
              '${region.minZoom} - ${region.maxZoom}',
            ),
            _buildDetailRow(context, 'Created', _formatDate(region.createdAt)),
            _buildDetailRow(
              context,
              'Last Accessed',
              _formatDate(region.lastAccessedAt),
            ),
            const SizedBox(height: 16),
            Text(
              'Bounds',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SW: ${region.minLat.toStringAsFixed(4)}, '
              '${region.minLng.toStringAsFixed(4)}\n'
              'NE: ${region.maxLat.toStringAsFixed(4)}, '
              '${region.maxLng.toStringAsFixed(4)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDeleteRegion(
    BuildContext context,
    WidgetRef ref,
    CachedRegion region,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region?'),
        content: Text(
          'Delete "${region.name}" and its ${region.tileCount} cached tiles?\n\n'
          'This will free up ${region.formattedSize} of storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(cachedRegionsNotifierProvider.notifier)
          .deleteRegion(region.id);
    }
  }

  Future<void> _showClearCacheDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final cacheStats = ref.read(cacheStatsProvider);

    final statsText = cacheStats.whenOrNull(
      data: (stats) =>
          'This will delete ${stats.tileCount} tiles (${stats.formattedSize}).',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache?'),
        content: Text(
          'Delete all downloaded map regions and cached tiles?\n\n'
          '${statsText ?? ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(cachedRegionsNotifierProvider.notifier).clearAllCache();
    }
  }
}
