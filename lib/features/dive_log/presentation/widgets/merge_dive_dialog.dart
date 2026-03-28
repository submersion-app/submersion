import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Multi-step dialog for merging another dive into the current one
/// as an additional computer reading.
///
/// Step 1: Shows candidate dives from the same calendar day, sorted by
///         time proximity. User selects one.
/// Step 2: Data-loss warning confirmation screen.
class MergeDiveDialog extends ConsumerStatefulWidget {
  final String currentDiveId;
  final DateTime currentDiveDate;
  final void Function(String selectedDiveId) onMerge;

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
                  'Merge with another dive',
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select a dive from the same day to merge as an additional computer.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: divesAsync.when(
              data: (allDives) => _buildCandidateList(context, allDives),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Error loading dives: $error')),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selectedDive == null
                    ? null
                    : () => setState(() => _showConfirmation = true),
                child: const Text('Next'),
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
                'No other dives found on this day.',
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
                child: Text('Confirm merge', style: textTheme.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Merging dive at $timeLabel into this dive.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Card(
            color: colorScheme.errorContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data loss warning',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The following data from the selected dive will be discarded: '
                    'tanks, equipment links, notes, buddy, rating. '
                    'Only the dive computer\'s profile data and metadata will be kept. '
                    'This action can be reversed with \'Unlink computer\'.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
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
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onMerge(dive.id);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                ),
                child: const Text('Merge'),
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
      if (durationStr != null) durationStr,
      if (computerStr != null) computerStr,
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
  required void Function(String selectedDiveId) onMerge,
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
