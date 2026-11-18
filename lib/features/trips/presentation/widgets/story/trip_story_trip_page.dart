import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_line.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_empty_state.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_under_way_cards.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_country_flags.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

/// The whole trip on one page: its dates, its totals, a line per day that
/// opens that day, then the vessel, the notes and the documents.
///
/// This is where everything about the trip as a whole lives, so that a day's
/// page can be about the day alone. The trip's name is not repeated here; it
/// is already in the app bar or the pane header above the tabs.
class TripStoryTripPage extends ConsumerWidget {
  const TripStoryTripPage({
    super.key,
    required this.story,
    required this.stats,
    required this.onSelectDay,
    this.onScanForDives,
    this.notesKey,
  });

  final TripStory story;
  final TripWithStats stats;

  /// Called with a day's date when its line is tapped.
  final ValueChanged<DateTime> onSelectDay;

  /// Looks for dives in the trip's dates, from the empty state.
  final VoidCallback? onScanForDives;

  /// Put on the Notes card, so a day's page can scroll the Trip page to it.
  final Key? notesKey;

  static const totalsKey = Key('trip-page-totals');

  /// Distinct dive sites visited across the whole trip.
  int get _siteCount {
    final ids = <String>{};
    for (final day in story.days) {
      for (final dive in day.dives) {
        final id = dive.site?.id;
        if (id != null) ids.add(id);
      }
    }
    return ids.length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final trip = story.trip;
    final dates = Text(
      '${units.formatDate(trip.startDate)}'
      ' - ${units.formatDate(trip.endDate)}'
      ' (${l10n.trips_detail_durationDays(trip.durationDays)})',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The flags follow the dates, or take the next line when
                // they do not fit. With none, the dates stand alone: an
                // empty flag slot would still take the Wrap's spacing.
                if (tripHasFlags(ref, trip.id))
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      dates,
                      TripCountryFlags(tripId: trip.id, flagHeight: 14),
                    ],
                  )
                else
                  dates,
                if (trip.isInProgress) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.trips_story_dayOfTrip(
                      (story.todayIndex ?? 0) + 1,
                      story.days.length,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (story.isEmpty) ...[
            // A trip under way with nothing logged yet still has cylinders
            // to fill and a flight to count down to. Shows nothing otherwise.
            const SizedBox(height: 16),
            TripUnderWayCards(trip: trip),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TripStoryEmptyState(onScanForDives: onScanForDives),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: _Totals(
                key: totalsKey,
                stats: stats,
                siteCount: _siteCount,
              ),
            ),
            // Shows nothing unless the trip is under way; the cards pad
            // themselves.
            TripUnderWayCards(trip: trip),
            Divider(height: 1, color: scheme.outlineVariant),
            for (final day in story.days) ...[
              TripStoryDayLine(day: day, onTap: () => onSelectDay(day.date)),
              Divider(height: 1, color: scheme.outlineVariant),
            ],
          ],
          if (trip.isLiveaboard)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TripVesselSection(tripId: trip.id),
            ),
          if (trip.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                key: notesKey,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.trips_detail_sectionTitle_notes,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      MarkdownNotesView(trip.notes),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DocumentsSection(
              owner: DocumentOwner(DocumentOwnerKind.trip, trip.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// The trip's totals, larger than body text and with nothing behind them:
/// they sit on the page, not in a band.
class _Totals extends ConsumerWidget {
  const _Totals({super.key, required this.stats, required this.siteCount});

  final TripWithStats stats;
  final int siteCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final entries = <(String, String)>[
      (l10n.trips_detail_stat_totalDives, '${stats.diveCount}'),
      (l10n.trips_detail_stat_totalRuntime, stats.formattedRuntime),
      if (stats.maxDepth != null)
        (l10n.trips_detail_stat_maxDepth, units.formatDepth(stats.maxDepth)),
      if (siteCount > 0) (l10n.trips_detail_stat_sitesVisited, '$siteCount'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in entries)
          Expanded(
            child: Semantics(
              label: '$label: $value',
              excludeSemantics: true,
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
