import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Dialog for resolving sync conflicts between local and remote data
class ConflictResolutionDialog extends ConsumerStatefulWidget {
  const ConflictResolutionDialog({super.key});

  @override
  ConsumerState<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState
    extends ConsumerState<ConflictResolutionDialog> {
  int _currentIndex = 0;
  final Map<String, ConflictResolution> _resolutions = {};

  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(conflictsProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: conflictsAsync.when(
          data: (conflicts) => _buildContent(context, conflicts),
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('Error loading conflicts: $error')),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<SyncConflict> conflicts) {
    if (conflicts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('No Conflicts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('All sync conflicts have been resolved.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    final conflict = conflicts[_currentIndex];
    final hasResolution = _resolutions.containsKey(_conflictKey(conflict));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, conflicts),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildConflictDetails(context, conflict),
          ),
        ),
        _buildResolutionOptions(context, conflict),
        _buildFooter(context, conflicts, hasResolution),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<SyncConflict> conflicts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolve Conflicts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Conflict ${_currentIndex + 1} of ${conflicts.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictDetails(BuildContext context, SyncConflict conflict) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _getEntityIcon(conflict.entityType),
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        _formatEntityType(conflict.entityType),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Local version
        Text(
          'Local Version',
          style: theme.textTheme.labelLarge?.copyWith(color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.blue.withAlpha(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_android, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Modified: ${_formatDateTime(conflict.localModified)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDataPreview(context, conflict.localData),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Remote version
        Text(
          'Remote Version',
          style: theme.textTheme.labelLarge?.copyWith(color: Colors.green),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.green.withAlpha(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Modified: ${_formatDateTime(conflict.remoteModified)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDataPreview(context, conflict.remoteData),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataPreview(BuildContext context, Map<String, dynamic> data) {
    if (data.isEmpty) {
      return Text(
        'No data available',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    // Show key fields from the data
    final displayFields = _getDisplayFields(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: displayFields.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '${entry.key}:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _getDisplayFields(Map<String, dynamic> data) {
    // Filter to show only important fields
    const importantKeys = [
      'name',
      'title',
      'description',
      'date',
      'location',
      'maxDepth',
      'duration',
      'notes',
    ];

    final result = <String, dynamic>{};
    for (final key in importantKeys) {
      if (data.containsKey(key) && data[key] != null) {
        result[key] = data[key];
      }
    }

    // If no important fields found, show first few fields
    if (result.isEmpty) {
      final entries = data.entries.take(5);
      for (final entry in entries) {
        if (entry.value != null) {
          result[entry.key] = entry.value;
        }
      }
    }

    return result;
  }

  Widget _buildResolutionOptions(BuildContext context, SyncConflict conflict) {
    final key = _conflictKey(conflict);
    final selected = _resolutions[key];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Resolution',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Keep Local'),
                selected: selected == ConflictResolution.keepLocal,
                onSelected: (_) =>
                    _selectResolution(key, ConflictResolution.keepLocal),
                avatar: const Icon(Icons.phone_android, size: 18),
              ),
              ChoiceChip(
                label: const Text('Keep Remote'),
                selected: selected == ConflictResolution.keepRemote,
                onSelected: (_) =>
                    _selectResolution(key, ConflictResolution.keepRemote),
                avatar: const Icon(Icons.cloud, size: 18),
              ),
              ChoiceChip(
                label: const Text('Keep Both'),
                selected: selected == ConflictResolution.keepBoth,
                onSelected: (_) =>
                    _selectResolution(key, ConflictResolution.keepBoth),
                avatar: const Icon(Icons.copy_all, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    List<SyncConflict> conflicts,
    bool hasResolution,
  ) {
    final allResolved = conflicts.every(
      (c) => _resolutions.containsKey(_conflictKey(c)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Navigation buttons
          IconButton(
            onPressed: _currentIndex > 0
                ? () => setState(() => _currentIndex--)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: _currentIndex < conflicts.length - 1
                ? () => setState(() => _currentIndex++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          const Spacer(),
          // Action buttons
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: allResolved ? () => _applyResolutions(conflicts) : null,
            child: const Text('Apply All'),
          ),
        ],
      ),
    );
  }

  void _selectResolution(String key, ConflictResolution resolution) {
    setState(() {
      _resolutions[key] = resolution;
    });
  }

  String _conflictKey(SyncConflict conflict) {
    return '${conflict.entityType}:${conflict.recordId}';
  }

  Future<void> _applyResolutions(List<SyncConflict> conflicts) async {
    final syncNotifier = ref.read(syncStateProvider.notifier);

    for (final conflict in conflicts) {
      final key = _conflictKey(conflict);
      final resolution = _resolutions[key];
      if (resolution != null) {
        await syncNotifier.resolveConflict(
          conflict.entityType,
          conflict.recordId,
          resolution,
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Resolved ${conflicts.length} conflict${conflicts.length == 1 ? '' : 's'}',
          ),
        ),
      );
    }
  }

  IconData _getEntityIcon(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'dive':
      case 'dives':
        return Icons.scuba_diving;
      case 'divesite':
      case 'dive_sites':
        return Icons.place;
      case 'gear':
        return Icons.backpack;
      case 'diver':
      case 'divers':
        return Icons.person;
      case 'trip':
      case 'trips':
        return Icons.card_travel;
      default:
        return Icons.description;
    }
  }

  String _formatEntityType(String entityType) {
    // Convert snake_case to Title Case
    return entityType
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
