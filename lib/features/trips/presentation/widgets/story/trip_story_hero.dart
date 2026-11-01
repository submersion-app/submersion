import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_checklist_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_progress_line.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_empty_state.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Prepare overview's header: trip identity plus mode-specific extras
/// (countdown and checklist for planned trips, progress line for in-progress
/// trips, empty state with CTAs for bare trips). The story itself opens with
/// the [TripHeroCard] instead (issue #4106).
class TripStoryHero extends ConsumerWidget {
  final TripStory story;
  final VoidCallback? onScanForDives;

  /// The Prepare overview (#2845) has its own rows under the hero, so it
  /// turns the empty state off.
  final bool showEmptyState;

  /// The Prepare overview's summary card has a Checklist row with the same
  /// progress, so it turns the checklist card off (#2881).
  final bool showChecklist;

  const TripStoryHero({
    super.key,
    required this.story,
    this.onScanForDives,
    this.showEmptyState = true,
    this.showChecklist = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = story.trip;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final progress = tripProgressLine(context, story);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                trip.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${units.formatDate(trip.startDate)}'
          ' - ${units.formatDate(trip.endDate)}'
          ' (${context.l10n.trips_detail_durationDays(trip.durationDays)})',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          Text(
            progress,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (showChecklist && trip.isUpcoming && !story.checklist.isEmpty) ...[
          const SizedBox(height: 12),
          TripChecklistCard(story: story),
        ],
        if (showEmptyState && story.isEmpty) ...[
          const SizedBox(height: 16),
          TripStoryEmptyState(onScanForDives: onScanForDives),
        ],
      ],
    );
  }
}
