import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
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

    // The day title, subtitle, and Planned chip live in the sticky
    // TripStoryDayHeader above this card; the card is body-only. A planned
    // day whose itinerary has nothing to show would produce an empty card,
    // so skip it entirely. A surface day has nothing by definition and takes
    // the same exit: its header is the whole chapter.
    // Blank is not content: a whitespace-only port or note would otherwise
    // defeat this guard and render a card with nothing in it. The edit sheet
    // normalizes empties away, but sync and import payloads do not.
    final itinerary = day.itineraryDay;
    final hasPlannedExtras =
        _isPlanned &&
        ((itinerary?.notes.trim().isNotEmpty ?? false) ||
            (itinerary?.portName?.trim().isNotEmpty ?? false));
    final hasBody =
        day.dives.isNotEmpty ||
        day.media.isNotEmpty ||
        day.sightings.isNotEmpty ||
        hasPlannedExtras;
    if (!hasBody) {
      return const SizedBox.shrink();
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
          // Three zones with deliberate visual weight: a tinted day-at-a-glance
          // band (stats + rhythm), the untinted dive rows as the dominant
          // middle, and captioned photo/species clusters at the tail. Gaps
          // follow the grouping: tight inside a zone, 16 between zones.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (day.dives.isNotEmpty) ...[
                _DaySummaryBand(day: day, units: units),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                _SectionCaption(text: context.l10n.trips_photos_sectionTitle),
                const SizedBox(height: 6),
                _PhotoStrip(tripId: tripId, media: day.media),
              ],
              if (day.sightings.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCaption(
                  text: context.l10n.trips_detail_stat_speciesSeen,
                ),
                const SizedBox(height: 6),
                _SightingChips(day: day),
              ],
              if (_isPlanned) _PlannedExtras(day: day, units: units),
            ],
          ),
        ),
      ),
    );
  }
}

/// The day-at-a-glance cluster: stat strip plus 24h rhythm bar, visually
/// bounded by a subtle tint so it reads as one summary unit above the dive
/// rows rather than as loose siblings of them.
class _DaySummaryBand extends StatelessWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  const _DaySummaryBand({required this.day, required this.units});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('day-summary-band'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayStatStrip(day: day, units: units),
          const SizedBox(height: 10),
          DayRhythmBar(dives: day.dives),
        ],
      ),
    );
  }
}

/// Tiny muted heading over a tail-of-card cluster (photos, species) so those
/// strips stop reading as unlabeled debris after the dive rows.
class _SectionCaption extends StatelessWidget {
  final String text;

  const _SectionCaption({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
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
    final runtime = day.totalRuntime;
    final runtimeLabel = runtime.inHours > 0
        ? '${runtime.inHours}h ${runtime.inMinutes % 60}m'
        : '${runtime.inMinutes}m';
    final stats = <(String, String)>[
      (l10n.trips_detail_stat_totalDives, '${day.diveCount}'),
      (l10n.trips_detail_stat_totalRuntime, runtimeLabel),
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
        name: localizedSpeciesName(
          context.l10n,
          sighting.speciesId,
          sighting.speciesName,
        ),
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
    // Same blank-is-absent rule the card's hasPlannedExtras guard applies, so a
    // whitespace-only port cannot render an empty note or send a blank site
    // name to the history lookup.
    final itinerary = day.itineraryDay;
    final notes = itinerary?.notes.trim() ?? '';
    final portName = itinerary?.portName?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(notes, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (portName.isNotEmpty)
          _HistoryPills(siteName: portName, units: units),
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
