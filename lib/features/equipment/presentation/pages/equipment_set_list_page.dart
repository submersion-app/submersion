import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

class EquipmentSetListPage extends ConsumerWidget {
  const EquipmentSetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(equipmentSetListNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Equipment Sets')),
      body: setsAsync.when(
        data: (sets) => sets.isEmpty
            ? _buildEmptyState(context)
            : _buildSetsList(context, sets),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading sets: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref
                    .read(equipmentSetListNotifierProvider.notifier)
                    .refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/equipment/sets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Create Set'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Equipment Sets',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create equipment sets to quickly add commonly used combinations of equipment to your dives.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/equipment/sets/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Set'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsList(BuildContext context, List<EquipmentSet> sets) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sets.length,
      itemBuilder: (context, index) {
        final set = sets[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            onTap: () => context.push('/equipment/sets/${set.id}'),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.folder,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(set.name),
            subtitle: Text(
              set.description.isNotEmpty
                  ? set.description
                  : '${set.itemCount} ${set.itemCount == 1 ? 'item' : 'items'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: set.itemCount > 0
                ? Chip(
                    label: Text('${set.itemCount}'),
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          ),
        );
      },
    );
  }
}
