import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Checklist progress for an upcoming trip: done-of-total, a progress bar and
/// the next few due items. Shown under the story's hero; the Prepare
/// overview's summary card carries the same progress in a row instead
/// (#2881).
class TripChecklistCard extends ConsumerWidget {
  final TripStory story;

  const TripChecklistCard({super.key, required this.story});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final checklist = story.checklist;
    final progress = checklist.total == 0
        ? 0.0
        : checklist.done / checklist.total;
    final units = ref.watch(unitFormatterProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.trips_story_checklistProgress(
                checklist.done,
                checklist.total,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
            for (final item in checklist.nextDue)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.dueDate != null)
                      Text(
                        units.formatMonthDay(item.dueDate),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
