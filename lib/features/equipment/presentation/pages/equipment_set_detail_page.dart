import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/equipment_set.dart';
import '../../domain/entities/equipment_item.dart';
import '../providers/equipment_set_providers.dart';

class EquipmentSetDetailPage extends ConsumerWidget {
  final String setId;

  const EquipmentSetDetailPage({
    super.key,
    required this.setId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setAsync = ref.watch(equipmentSetProvider(setId));

    return setAsync.when(
      data: (set) {
        if (set == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Set Not Found')),
            body: const Center(child: Text('This equipment set no longer exists.')),
          );
        }
        return _buildContent(context, ref, set);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, EquipmentSet set) {
    return Scaffold(
      appBar: AppBar(
        title: Text(set.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/equipment/sets/$setId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value, set),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.folder,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            set.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (set.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              set.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${set.itemCount} ${set.itemCount == 1 ? 'item' : 'items'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Equipment items
            Text(
              'Equipment in This Set',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (set.items == null || set.items!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.backpack_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No equipment in this set',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/equipment/sets/$setId/edit'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Equipment'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...set.items!.map((item) => _buildEquipmentTile(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentTile(BuildContext context, EquipmentItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/equipment/${item.id}'),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          child: Icon(
            _getIconForType(item.type),
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        title: Text(item.name),
        subtitle: Text(item.fullName != item.name ? item.fullName : item.type.displayName),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    EquipmentSet set,
  ) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Equipment Set'),
          content: const Text(
            'Are you sure you want to delete this equipment set? The equipment items in the set will not be deleted.',
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
        await ref.read(equipmentSetListNotifierProvider.notifier).deleteSet(setId);
        if (context.mounted) {
          context.go('/equipment/sets');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment set deleted')),
          );
        }
      }
    }
  }

  IconData _getIconForType(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.accessibility_new;
      case EquipmentType.wetsuit:
      case EquipmentType.drysuit:
        return Icons.checkroom;
      case EquipmentType.fins:
        return Icons.directions_walk;
      case EquipmentType.mask:
        return Icons.visibility;
      case EquipmentType.computer:
        return Icons.watch;
      case EquipmentType.tank:
        return Icons.propane_tank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      default:
        return Icons.backpack;
    }
  }
}
