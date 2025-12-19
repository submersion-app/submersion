import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/diver.dart';
import '../providers/diver_providers.dart';

class DiverListPage extends ConsumerWidget {
  const DiverListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diversAsync = ref.watch(diverListNotifierProvider);
    final currentDiverId = ref.watch(currentDiverIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diver Profiles'),
      ),
      body: diversAsync.when(
        data: (divers) => divers.isEmpty
            ? _buildEmptyState(context)
            : _buildDiverList(context, ref, divers, currentDiverId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading divers: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(diverListNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/divers/new'),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Diver'),
      ),
    );
  }

  Widget _buildDiverList(
    BuildContext context,
    WidgetRef ref,
    List<Diver> divers,
    String? currentDiverId,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(diverListNotifierProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: divers.length,
        itemBuilder: (context, index) {
          final diver = divers[index];
          final isCurrentDiver = diver.id == currentDiverId;
          return DiverListTile(
            diver: diver,
            isCurrentDiver: isCurrentDiver,
            onTap: () => context.push('/divers/${diver.id}'),
            onSwitchTo: () async {
              await ref.read(currentDiverIdProvider.notifier).setCurrentDiver(diver.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to ${diver.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No divers yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add diver profiles to track dive logs for multiple people',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/divers/new'),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Diver'),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying a diver
class DiverListTile extends ConsumerWidget {
  final Diver diver;
  final bool isCurrentDiver;
  final VoidCallback? onTap;
  final VoidCallback? onSwitchTo;

  const DiverListTile({
    super.key,
    required this.diver,
    this.isCurrentDiver = false,
    this.onTap,
    this.onSwitchTo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diverStatsProvider(diver.id));
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isCurrentDiver
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: diver.photoPath != null
                        ? AssetImage(diver.photoPath!)
                        : null,
                    child: diver.photoPath == null
                        ? Text(
                            diver.initials,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  if (isCurrentDiver)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            diver.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isCurrentDiver
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isCurrentDiver)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Active',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    statsAsync.when(
                      data: (stats) => Text(
                        '${stats.diveCount} dives${stats.totalBottomTimeSeconds > 0 ? ' - ${stats.formattedBottomTime}' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      loading: () => Text(
                        'Loading...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      error: (_, __) => Text(
                        'Error loading stats',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    if (diver.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        diver.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Switch button (if not current)
              if (!isCurrentDiver && onSwitchTo != null)
                IconButton(
                  onPressed: onSwitchTo,
                  icon: const Icon(Icons.switch_account),
                  tooltip: 'Switch to this diver',
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
