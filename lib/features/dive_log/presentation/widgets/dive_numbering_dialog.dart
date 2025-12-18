import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dive_repository_impl.dart';
import '../providers/dive_providers.dart';

/// Dialog for managing dive numbering - detecting gaps and renumbering dives
class DiveNumberingDialog extends ConsumerStatefulWidget {
  const DiveNumberingDialog({super.key});

  @override
  ConsumerState<DiveNumberingDialog> createState() => _DiveNumberingDialogState();
}

class _DiveNumberingDialogState extends ConsumerState<DiveNumberingDialog> {
  bool _isRenumbering = false;
  int _startFrom = 1;

  @override
  Widget build(BuildContext context) {
    final numberingInfoAsync = ref.watch(diveNumberingInfoProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.format_list_numbered,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dive Numbering',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: numberingInfoAsync.when(
                  data: (info) => _buildContent(context, info),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text('Error: $error'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DiveNumberingInfo info) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          _buildSummaryCard(context, info),
          const SizedBox(height: 16),

          // Gaps section
          if (info.hasGaps) ...[
            Text(
              'Gaps Detected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildGapsCard(context, info.gaps),
            const SizedBox(height: 16),
          ],

          // Unnumbered dives
          if (info.hasUnnumbered) ...[
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${info.unnumberedDives} dive(s) without numbers',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          Text(
            'Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildActionsCard(context, info),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DiveNumberingInfo info) {
    final isHealthy = !info.hasGaps && !info.hasUnnumbered;

    return Card(
      color: isHealthy
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.info_outline,
              color: isHealthy
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.error,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHealthy ? 'All dives numbered correctly' : 'Issues detected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info.totalDives} total dives • ${info.numberedDives} numbered',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapsCard(BuildContext context, List<DiveNumberGap> gaps) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: gaps.take(10).map((gap) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.space_bar,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(gap.description),
                  const Spacer(),
                  Text(
                    '${gap.count} missing',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, DiveNumberingInfo info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assign missing numbers
            if (info.hasUnnumbered)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Assign missing numbers'),
                subtitle: const Text('Number unnumbered dives starting after the last numbered dive'),
                trailing: _isRenumbering
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _isRenumbering ? null : () => _assignMissingNumbers(context),
              ),

            // Renumber all dives
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_list_numbered),
              title: const Text('Renumber all dives'),
              subtitle: const Text('Assign sequential numbers based on dive date/time'),
              trailing: _isRenumbering
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isRenumbering ? null : () => _showRenumberDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignMissingNumbers(BuildContext context) async {
    setState(() => _isRenumbering = true);
    try {
      final repository = ref.read(diveRepositoryProvider);
      await repository.assignMissingDiveNumbers();
      ref.invalidate(diveNumberingInfoProvider);
      ref.invalidate(diveListNotifierProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing dive numbers assigned')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isRenumbering = false);
    }
  }

  Future<void> _showRenumberDialog(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renumber All Dives'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will renumber all dives sequentially based on their entry date/time. '
              'This action cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Start from number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _startFrom.toString()),
              onChanged: (value) {
                final num = int.tryParse(value);
                if (num != null && num > 0) {
                  _startFrom = num;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_startFrom),
            child: const Text('Renumber'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      await _renumberAllDives(context, result);
    }
  }

  Future<void> _renumberAllDives(BuildContext context, int startFrom) async {
    setState(() => _isRenumbering = true);
    try {
      final repository = ref.read(diveRepositoryProvider);
      await repository.renumberAllDives(startFrom: startFrom);
      ref.invalidate(diveNumberingInfoProvider);
      ref.invalidate(diveListNotifierProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All dives renumbered starting from #$startFrom')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isRenumbering = false);
    }
  }
}

/// Shows the dive numbering dialog
Future<void> showDiveNumberingDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const DiveNumberingDialog(),
  );
}

