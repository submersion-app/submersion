import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Multi-step dialog for merging another dive into the current one
/// as an additional computer reading.
///
/// Step 1: Shows candidate dives from the same calendar day, sorted by
///         time proximity. User selects one.
/// Step 2: Confirmation screen explaining what the fold does.
class MergeDiveDialog extends ConsumerStatefulWidget {
  final String currentDiveId;
  final DateTime currentDiveDate;

  /// Called with the selected dive's id wrapped in a single-element list --
  /// the shape [DiveConsolidationService.apply]'s `secondaryDiveIds`
  /// parameter expects, since it supports folding in more than one computer
  /// at a time even though this dialog currently only lets the user pick one.
  final void Function(List<String> secondaryDiveIds) onMerge;

  const MergeDiveDialog({
    super.key,
    required this.currentDiveId,
    required this.currentDiveDate,
    required this.onMerge,
  });

  @override
  ConsumerState<MergeDiveDialog> createState() => _MergeDiveDialogState();
}

class _MergeDiveDialogState extends ConsumerState<MergeDiveDialog> {
  Dive? _selectedDive;
  bool _showConfirmation = false;

  @override
  Widget build(BuildContext context) {
    final divesAsync = ref.watch(diveListNotifierProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: _showConfirmation && _selectedDive != null
            ? _buildConfirmationScreen(context)
            : _buildSelectionScreen(context, divesAsync),
      ),
    );
  }

  Widget _buildSelectionScreen(
    BuildContext context,
    AsyncValue<List<Dive>> divesAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.merge, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.diveLog_mergeDialog_title,
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.diveLog_mergeDialog_subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: divesAsync.when(
              data: (allDives) => _buildCandidateList(context, allDives),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(l10n.diveLog_mergeDialog_loadError('$error')),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.common_action_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selectedDive == null
                    ? null
                    : () => setState(() => _showConfirmation = true),
                child: Text(l10n.diveLog_mergeDialog_next),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateList(BuildContext context, List<Dive> allDives) {
    final candidates = _getCandidateDives(allDives);

    if (candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.diveLog_mergeDialog_empty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: candidates.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final dive = candidates[index];
        final isSelected = _selectedDive?.id == dive.id;
        final settings = ref.watch(settingsProvider);
        final units = UnitFormatter(settings);
        return _DiveCandidateTile(
          dive: dive,
          isSelected: isSelected,
          timePattern: ref.watch(timeFormatProvider).pattern,
          depthStr: dive.maxDepth != null
              ? units.formatDepth(dive.maxDepth!)
              : null,
          onTap: () => setState(() => _selectedDive = dive),
        );
      },
    );
  }

  Widget _buildConfirmationScreen(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final dive = _selectedDive!;

    final timeLabel = dive.entryTime != null
        ? DateFormat(
            ref.watch(timeFormatProvider).pattern,
          ).format(dive.entryTime!)
        : DateFormat(
            ref.watch(timeFormatProvider).pattern,
          ).format(dive.dateTime);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.diveLog_mergeDialog_confirmTitle,
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.diveLog_mergeDialog_confirmSubtitle(timeLabel),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Card(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.diveLog_mergeDialog_whatThisDoes,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.diveLog_mergeDialog_explanation,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showConfirmation = false),
                child: Text(l10n.common_action_back),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onMerge([dive.id]);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                ),
                child: Text(l10n.diveLog_mergeDialog_merge),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Dive> _getCandidateDives(List<Dive> allDives) {
    final targetDate = widget.currentDiveDate;

    final sameDay = allDives.where((dive) {
      if (dive.id == widget.currentDiveId) return false;
      final diveDate = dive.entryTime ?? dive.dateTime;
      return diveDate.year == targetDate.year &&
          diveDate.month == targetDate.month &&
          diveDate.day == targetDate.day;
    }).toList();

    // Sort by time proximity to the target dive
    final targetTime = targetDate.millisecondsSinceEpoch;
    sameDay.sort((a, b) {
      final aTime = (a.entryTime ?? a.dateTime).millisecondsSinceEpoch;
      final bTime = (b.entryTime ?? b.dateTime).millisecondsSinceEpoch;
      final aDiff = (aTime - targetTime).abs();
      final bDiff = (bTime - targetTime).abs();
      return aDiff.compareTo(bDiff);
    });

    return sameDay;
  }
}

/// A single candidate dive tile in the merge selection list.
class _DiveCandidateTile extends StatelessWidget {
  final Dive dive;
  final bool isSelected;
  final VoidCallback onTap;
  final String timePattern;
  final String? depthStr;

  const _DiveCandidateTile({
    required this.dive,
    required this.isSelected,
    required this.timePattern,
    required this.onTap,
    this.depthStr,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final entryTime = dive.entryTime ?? dive.dateTime;
    final timeStr = DateFormat(timePattern).format(entryTime);

    final durationStr = dive.bottomTime != null
        ? _formatDuration(dive.bottomTime!)
        : null;

    final computerStr = dive.diveComputerModel;

    final subtitle = [
      if (depthStr != null) depthStr,
      ?durationStr,
      ?computerStr,
    ].join(' \u00b7 ');

    return ListTile(
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      onTap: onTap,
      leading: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : const Icon(Icons.scuba_diving_outlined),
      title: Text(
        dive.site?.name != null
            ? '${dive.site!.name} \u2013 $timeStr'
            : timeStr,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : null,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: dive.diveNumber != null
          ? Text(
              '#${dive.diveNumber}',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) return '${minutes}min';
    final hours = duration.inHours;
    final remaining = minutes - hours * 60;
    return remaining > 0 ? '${hours}h ${remaining}min' : '${hours}h';
  }
}

/// Shows the merge dive dialog and returns the selected dive ID,
/// or null if cancelled.
Future<void> showMergeDiveDialog({
  required BuildContext context,
  required String currentDiveId,
  required DateTime currentDiveDate,
  required void Function(List<String> secondaryDiveIds) onMerge,
}) {
  return showDialog(
    context: context,
    builder: (context) => MergeDiveDialog(
      currentDiveId: currentDiveId,
      currentDiveDate: currentDiveDate,
      onMerge: onMerge,
    ),
  );
}
