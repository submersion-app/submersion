import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

/// Page displaying a list of saved dive computers.
class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computersAsync = ref.watch(allDiveComputersProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Computers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
      ),
      body: computersAsync.when(
        data: (computers) {
          if (computers.isEmpty) {
            return _buildEmptyState(context, colorScheme);
          }
          return _buildComputerList(context, ref, computers);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load dive computers',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(allDiveComputersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dive-computers/discover'),
        icon: const Icon(Icons.add),
        label: const Text('Add Computer'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.watch_outlined,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Dive Computers',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your dive computer to download dives directly into the app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/dive-computers/discover'),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Find Computers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComputerList(
    BuildContext context,
    WidgetRef ref,
    List<DiveComputer> computers,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88), // FAB clearance
      itemCount: computers.length,
      itemBuilder: (context, index) {
        final computer = computers[index];
        return _ComputerCard(
          computer: computer,
          onTap: () => context.push('/dive-computers/${computer.id}'),
          onDownload: () => _startQuickDownload(context, ref, computer),
        );
      },
    );
  }

  void _startQuickDownload(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    // Navigate to download page for this computer
    context.push('/dive-computers/${computer.id}/download');
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dive Computer Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Supported Connections',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Bluetooth LE (most modern computers)'),
              Text('• Bluetooth Classic (older models)'),
              Text('• USB (desktop only)'),
              SizedBox(height: 16),
              Text('Tips', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Ensure your computer is in transfer mode'),
              Text('• Keep devices close during download'),
              Text('• Make sure Bluetooth is enabled'),
              SizedBox(height: 16),
              Text(
                'Supported Brands',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Shearwater, Suunto, Garmin, Mares, Scubapro, '
                'Oceanic, Aqualung, Cressi, and 50+ more models.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Card widget displaying a single dive computer.
class _ComputerCard extends StatelessWidget {
  final DiveComputer computer;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _ComputerCard({
    required this.computer,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: computer.isFavorite
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getConnectionIcon(computer.connectionType),
                  color: computer.isFavorite
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
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
                            computer.displayName,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (computer.isFavorite)
                          Icon(
                            Icons.star,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      computer.fullName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.scuba_diving,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${computer.diveCount} dives',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          computer.lastDownloadFormatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Download button
              IconButton(
                onPressed: onDownload,
                icon: const Icon(Icons.download),
                tooltip: 'Download dives',
              ),
            ],
          ),
        ),
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
}
