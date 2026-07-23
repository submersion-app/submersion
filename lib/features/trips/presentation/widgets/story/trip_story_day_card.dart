import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const int _maxPhotoThumbnails = 6;

/// One day chapter of the trip story.
class TripStoryDayCard extends ConsumerWidget {
  final TripStoryDay day;
  final String tripId;

  const TripStoryDayCard({super.key, required this.day, required this.tripId});

  bool get _isPlanned => day.kind == TripStoryDayKind.future;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Built once for the day's dives rather than per row.
    final diveTypeLabelResolver = watchDiveTypeLabelResolver(ref, context.l10n);

    if (!day.hasContent && day.kind != TripStoryDayKind.future) {
      return _SurfaceDayRow(day: day);
    }

    return Card(
      shape: _isPlanned
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            )
          : null,
      child: Opacity(
        opacity: _isPlanned ? 0.85 : 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, theme),
              if (day.dives.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DayStatStrip(day: day, units: units),
                const SizedBox(height: 12),
                DayRhythmBar(dives: day.dives),
                const SizedBox(height: 8),
                ...day.dives.mapIndexed(
                  (index, dive) => DiveListItem(
                    summary: DiveSummary.fromDive(dive),
                    diveTypeLabelResolver: diveTypeLabelResolver,
                    // The story already holds the full Dive; pass it so the
                    // configurable card can resolve fields absent from the
                    // summary (tanks, SAC, buddies, weights).
                    fullDive: dive,
                    diveNumber: dive.diveNumber ?? index + 1,
                    onTap: () => context.push('/dives/${dive.id}'),
                  ),
                ),
              ],
              if (day.media.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PhotoStrip(tripId: tripId, media: day.media),
              ],
              if (day.sightings.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SightingChips(day: day),
              ],
              if (_isPlanned) _PlannedExtras(day: day, units: units),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final dateFormat = DateFormat.MMMEd();
    final itinerary = day.itineraryDay;
    final subtitleParts = <String>[
      if (itinerary != null) itinerary.dayType.localizedName(context),
      if (itinerary?.portName != null) itinerary!.portName!,
      ...day.siteNames,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.l10n.trips_story_dayLabel(day.dayNumber)}'
                ' - ${dateFormat.format(day.date)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitleParts.isNotEmpty)
                Text(
                  subtitleParts.join(' - '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (_isPlanned)
          Chip(
            label: Text(context.l10n.trips_story_planned),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Slim row for a day with no dives, media, or itinerary entry.
class _SurfaceDayRow extends StatelessWidget {
  final TripStoryDay day;

  const _SurfaceDayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMEd();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.waves,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${context.l10n.trips_story_dayLabel(day.dayNumber)}'
              ' - ${dateFormat.format(day.date)}'
              ' - ${context.l10n.trips_story_surfaceDay}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStatStrip extends StatelessWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  const _DayStatStrip({required this.day, required this.units});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = day.totalBottomTime;
    final bottomLabel = bottom.inHours > 0
        ? '${bottom.inHours}h ${bottom.inMinutes % 60}m'
        : '${bottom.inMinutes}m';
    final stats = <(String, String)>[
      (l10n.trips_detail_stat_totalDives, '${day.diveCount}'),
      (l10n.trips_detail_stat_totalBottomTime, bottomLabel),
      if (day.maxDepth != null)
        (l10n.trips_detail_stat_maxDepth, units.formatDepth(day.maxDepth)),
      // siteCount dedupes by site id (siteNames dedupes by display name), so two
      // distinct same-named sites count as two here, matching the map and the
      // trip-level stat strip.
      (l10n.trips_breakdown_column_sites, '${day.siteCount}'),
    ];

    return Row(
      children: [
        for (final (label, value) in stats)
          Expanded(
            child: Semantics(
              label: '$label: $value',
              child: Column(
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _PhotoStrip extends StatelessWidget {
  final String tripId;
  final List<MediaItem> media;

  const _PhotoStrip({required this.tripId, required this.media});

  @override
  Widget build(BuildContext context) {
    final visible = media.take(_maxPhotoThumbnails).toList();
    final remaining = media.length - visible.length;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length + (remaining > 0 ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return _MoreThumbnail(count: remaining, tripId: tripId);
          }
          // MediaItemView renders the image without a semantic label, so label
          // the tap target as a button that opens the trip gallery.
          return Semantics(
            button: true,
            label: context.l10n.trips_story_openGallery,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => context.push('/trips/$tripId/gallery'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: MediaItemView(
                    item: visible[index],
                    thumbnail: true,
                    targetSize: const Size(128, 128),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoreThumbnail extends StatelessWidget {
  final int count;
  final String tripId;

  const _MoreThumbnail({required this.count, required this.tripId});

  @override
  Widget build(BuildContext context) {
    // The bare "+N" is a context-free accessible name; label it as a button
    // that opens the trip gallery.
    return Semantics(
      button: true,
      label: context.l10n.trips_story_openGallery,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/trips/$tripId/gallery'),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text('+$count', style: Theme.of(context).textTheme.labelLarge),
        ),
      ),
    );
  }
}

class _SightingChips extends StatelessWidget {
  final TripStoryDay day;

  const _SightingChips({required this.day});

  @override
  Widget build(BuildContext context) {
    // Merge the same species across the day's dives, keyed by the stable
    // speciesId so distinct species that share a common name stay separate.
    final merged = <String, ({String name, int count})>{};
    for (final sighting in day.sightings) {
      final existing = merged[sighting.speciesId];
      merged[sighting.speciesId] = (
        name: sighting.speciesName,
        count: (existing?.count ?? 0) + sighting.count,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final entry in merged.values)
          Chip(
            label: Text(
              entry.count > 1 ? '${entry.name} x${entry.count}' : entry.name,
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Itinerary notes and site-history context pills for planned days.
class _PlannedExtras extends ConsumerWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  const _PlannedExtras({required this.day, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itinerary = day.itineraryDay;
    final notes = itinerary?.notes ?? '';
    final portName = itinerary?.portName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(notes, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (portName != null) _HistoryPills(siteName: portName, units: units),
      ],
    );
  }
}

class _HistoryPills extends ConsumerWidget {
  final String siteName;
  final UnitFormatter units;

  const _HistoryPills({required this.siteName, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(siteHistoryByNameProvider(siteName));
    final history = historyAsync.valueOrNull;
    if (history == null || history.diveCount == 0) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          Chip(
            label: Text(l10n.trips_story_history_dives(history.diveCount)),
            visualDensity: VisualDensity.compact,
          ),
          if (history.avgWaterTemp != null)
            Chip(
              label: Text(
                l10n.trips_story_history_avgTemp(
                  units.formatTemperature(history.avgWaterTemp),
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          if (history.avgMaxDepth != null)
            Chip(
              label: Text(
                l10n.trips_story_history_avgDepth(
                  units.formatDepth(history.avgMaxDepth),
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
