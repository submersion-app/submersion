import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripStoryHero');

/// Story header: trip identity plus mode-specific extras (countdown and
/// checklist for planned trips, progress line for in-progress trips, empty
/// state with CTAs for bare trips).
class TripStoryHero extends ConsumerWidget {
  final TripStory story;
  final VoidCallback? onScanForDives;

  const TripStoryHero({super.key, required this.story, this.onScanForDives});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = story.trip;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    // Every trip day has its row: a single planned day (the board's day
    // strip) is not an itinerary, so Generate stays until each day has one.
    final coversTrip = story.days
        .where((d) => trip.containsDate(d.date))
        .every((d) => d.itineraryDay != null);

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
        if (trip.isInProgress) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_story_dayOfTrip(
              (story.todayIndex ?? 0) + 1,
              story.days.length,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else if (trip.isUpcoming) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_story_daysUntil(trip.daysUntilStart),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (trip.isUpcoming && !story.checklist.isEmpty) ...[
          const SizedBox(height: 12),
          _ChecklistCard(story: story),
        ],
        // Only liveaboards get itinerary generation: generateForTrip emits
        // embark/disembark day types, and only the liveaboard layout exposes an
        // itinerary editor, so a shore/resort trip could otherwise mint
        // maritime days it can never edit.
        if (trip.isLiveaboard && trip.isUpcoming && !coversTrip) ...[
          const SizedBox(height: 8),
          _GenerateItineraryButton(story: story),
        ],
        if (story.isEmpty) ...[
          const SizedBox(height: 16),
          _EmptyState(onScanForDives: onScanForDives),
        ],
      ],
    );
  }
}

class _ChecklistCard extends ConsumerWidget {
  final TripStory story;

  const _ChecklistCard({required this.story});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final checklist = story.checklist;
    final progress = checklist.total == 0
        ? 0.0
        : checklist.done / checklist.total;
    final units = UnitFormatter(ref.watch(settingsProvider));

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

class _GenerateItineraryButton extends ConsumerStatefulWidget {
  final TripStory story;

  const _GenerateItineraryButton({required this.story});

  @override
  ConsumerState<_GenerateItineraryButton> createState() =>
      _GenerateItineraryButtonState();
}

class _GenerateItineraryButtonState
    extends ConsumerState<_GenerateItineraryButton> {
  bool _saving = false;

  Future<void> _generate() async {
    // Guard against a second tap while the first save is in flight: the
    // itinerary table has no (trip_id, day_number) uniqueness constraint, so a
    // double tap would insert the missing days twice and duplicate their
    // chapters.
    if (_saving) return;
    setState(() => _saving = true);
    final trip = widget.story.trip;
    try {
      // Only the days the itinerary lacks: a planned day keeps its row.
      final covered = {
        for (final d in widget.story.days)
          if (d.itineraryDay != null) tripDay(d.date),
      };
      final days = ItineraryDay.generateForTrip(
        tripId: trip.id,
        startDate: trip.startDate,
        endDate: trip.endDate,
      ).where((d) => !covered.contains(tripDay(d.date))).toList();
      await ref.read(itineraryDayRepositoryProvider).saveAll(days);
      ref.invalidate(itineraryDaysProvider(trip.id));
      ref.invalidate(tripStoryProvider(trip.id));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to generate trip itinerary',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_story_generateItineraryError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.event_note, size: 18),
      label: Text(context.l10n.trips_story_generateItinerary),
      onPressed: _saving ? null : _generate,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onScanForDives;

  const _EmptyState({required this.onScanForDives});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.auto_stories,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_story_empty_title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.trips_story_empty_subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (onScanForDives != null)
            FilledButton.icon(
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(context.l10n.trips_diveScan_findButton),
              onPressed: onScanForDives,
            ),
        ],
      ),
    );
  }
}
