import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dialog for managing dive numbering - detecting gaps and renumbering dives
class DiveNumberingDialog extends ConsumerStatefulWidget {
  const DiveNumberingDialog({super.key});

  @override
  ConsumerState<DiveNumberingDialog> createState() =>
      _DiveNumberingDialogState();
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
                  ExcludeSemantics(
                    child: Icon(
                      Icons.format_list_numbered,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.diveLog_numbering_title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: numberingInfoAsync.when(
                  data: (info) => _buildContent(context, info),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.diveLog_numbering_close),
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
              context.l10n.diveLog_numbering_gapsDetected,
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
                    ExcludeSemantics(
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.diveLog_numbering_unnumberedDives(
                          info.unnumberedDives,
                        ),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
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
            context.l10n.diveLog_numbering_actions,
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
            ExcludeSemantics(
              child: Icon(
                isHealthy ? Icons.check_circle : Icons.info_outline,
                color: isHealthy
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.error,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHealthy
                        ? context.l10n.diveLog_numbering_allCorrect
                        : context.l10n.diveLog_numbering_issuesDetected,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.diveLog_numbering_summary(
                      info.totalDives,
                      info.numberedDives,
                    ),
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
            return Semantics(
              label:
                  '${gap.description}, ${context.l10n.diveLog_numbering_missingCount(gap.count)}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.space_bar,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(gap.description),
                    const Spacer(),
                    Text(
                      context.l10n.diveLog_numbering_missingCount(gap.count),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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
                title: Text(context.l10n.diveLog_numbering_assignMissing),
                subtitle: Text(
                  context.l10n.diveLog_numbering_assignMissingDesc,
                ),
                trailing: _isRenumbering
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _isRenumbering
                    ? null
                    : () => _assignMissingNumbers(context),
              ),

            // Renumber all dives
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_list_numbered),
              title: Text(context.l10n.diveLog_numbering_renumberAll),
              subtitle: Text(context.l10n.diveLog_numbering_renumberAllDesc),
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
      ref.invalidate(paginatedDiveListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_numbering_snackbar_assigned),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isRenumbering = false);
    }
  }

  Future<void> _showRenumberDialog(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveLog_numbering_renumberDialog_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.diveLog_numbering_renumberDialog_content),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText:
                    context.l10n.diveLog_numbering_renumberDialog_startFrom,
                border: const OutlineInputBorder(),
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
            child: Text(context.l10n.diveLog_numbering_renumberDialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_startFrom),
            child: Text(context.l10n.diveLog_numbering_renumberDialog_renumber),
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
      ref.invalidate(paginatedDiveListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_numbering_snackbar_renumbered(startFrom),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
