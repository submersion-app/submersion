import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/dive_log/domain/entities/dive_computer.dart';
import '../../../../features/dive_log/presentation/providers/dive_computer_providers.dart';

/// Page displaying details about a specific dive computer.
class DeviceDetailPage extends ConsumerWidget {
  final String computerId;

  const DeviceDetailPage({
    super.key,
    required this.computerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computerAsync = ref.watch(diveComputerByIdProvider(computerId));
    final theme = Theme.of(context);

    return computerAsync.when(
      data: (computer) {
        if (computer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dive Computer')),
            body: const Center(child: Text('Computer not found')),
          );
        }
        return _buildContent(context, ref, computer, theme);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Dive Computer')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Dive Computer')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(computer.displayName),
        actions: [
          if (!computer.isFavorite)
            IconButton(
              icon: const Icon(Icons.star_outline),
              onPressed: () => _setFavorite(ref, computer),
              tooltip: 'Set as favorite',
            ),
          if (computer.isFavorite)
            IconButton(
              icon: Icon(Icons.star, color: colorScheme.primary),
              onPressed: () {},
              tooltip: 'Favorite computer',
            ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleMenuAction(context, ref, action, computer),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete'),
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
            _buildInfoCard(context, computer, colorScheme),
            const SizedBox(height: 16),
            _buildStatsCard(context, computer, colorScheme),
            const SizedBox(height: 16),
            _buildActionsCard(context, computer, colorScheme),
            if (computer.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesCard(context, computer, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    DiveComputer computer,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getConnectionIcon(computer.connectionType),
                    size: 32,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        computer.fullName,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (computer.serialNumber != null)
                        Text(
                          'S/N: ${computer.serialNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Manufacturer',
              computer.manufacturer ?? 'Unknown',
            ),
            _buildInfoRow(
              context,
              'Model',
              computer.model ?? 'Unknown',
            ),
            _buildInfoRow(
              context,
              'Connection',
              _getConnectionName(computer.connectionType),
            ),
            if (computer.bluetoothAddress != null)
              _buildInfoRow(
                context,
                'Bluetooth Address',
                computer.bluetoothAddress!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
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
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    DiveComputer computer,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.scuba_diving,
                    '${computer.diveCount}',
                    'Dives',
                    colorScheme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.download,
                    computer.lastDownloadFormatted,
                    'Last Download',
                    colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    DiveComputer computer,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/dive-computers/${computer.id}/download'),
              icon: const Icon(Icons.download),
              label: const Text('Download Dives'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Show dives from this computer
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View dives coming soon')),
                );
              },
              icon: const Icon(Icons.list),
              label: const Text('View Dives from This Computer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(
    BuildContext context,
    DiveComputer computer,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              computer.notes,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _setFavorite(WidgetRef ref, DiveComputer computer) {
    ref.read(diveComputerNotifierProvider.notifier).setFavorite(computer.id);
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    DiveComputer computer,
  ) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, ref, computer);
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref, computer);
        break;
    }
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    final nameController = TextEditingController(text: computer.name);
    final notesController = TextEditingController(text: computer.notes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Computer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., My Perdix',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final updated = computer.copyWith(
                name: nameController.text.trim(),
                notes: notesController.text.trim(),
              );
              ref.read(diveComputerNotifierProvider.notifier).update(updated);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Computer?'),
        content: Text(
          'Are you sure you want to remove "${computer.displayName}"? '
          'This will not delete any dives that were imported from this computer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(diveComputerNotifierProvider.notifier).delete(computer.id);
              Navigator.of(context).pop();
              context.pop(); // Go back to list
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getConnectionIcon(String? connectionType) {
    switch (connectionType?.toLowerCase()) {
      case 'bluetooth':
        return Icons.bluetooth;
      case 'usb':
        return Icons.usb;
      case 'wifi':
        return Icons.wifi;
      default:
        return Icons.watch;
    }
  }

  String _getConnectionName(String? connectionType) {
    switch (connectionType?.toLowerCase()) {
      case 'bluetooth':
        return 'Bluetooth';
      case 'usb':
        return 'USB';
      case 'wifi':
        return 'Wi-Fi';
      case 'infrared':
        return 'Infrared';
      default:
        return 'Unknown';
    }
  }
}
