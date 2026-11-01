import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_conditions_line.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_format.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_card_shape.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_map.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_plan.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One day chapter of the trip story (#2845): the day's header over its own
/// map when it has points, the day summary (stats, rhythm bar, conditions),
/// then the dive rows, photos and sightings, all in one card (#4106). The
/// header sits in the map's fade the way the dive detail header does; a day
/// with no map points leads with the header on the plain card, and a surface
/// day is nothing but that header.
class TripStoryDayCard extends ConsumerStatefulWidget {
  /// How much of the day's map shows above the header row. The backdrop fade
  /// turns opaque under the row, so the row stays readable while the pins
  /// above it stay tappable.
  static const double mapPeekHeight = 120;

  final TripStoryDay day;
  final String tripId;

  /// Weather stored for this day, passed down by the story view from one
  /// per-trip read. Null when nothing is stored yet.
  final TripStoryDayWeather? storedWeather;

  /// The day's map points (`TripStoryMapGeometry.pointsForDay`); none hides
  /// the map.
  final List<TripStoryMapPoint> mapPoints;

  /// Opens the day's map fullscreen; null hides the expand button.
  final void Function(TripStoryDay day, List<TripStoryMapPoint> points)?
  onExpandMap;

  const TripStoryDayCard({
    super.key,
    required this.day,
    required this.tripId,
    this.storedWeather,
    this.mapPoints = const [],
    this.onExpandMap,
  });

  @override
  ConsumerState<TripStoryDayCard> createState() => _TripStoryDayCardState();
}

class _TripStoryDayCardState extends ConsumerState<TripStoryDayCard> {
  /// The dive whose row a pin tap lit up; cleared by the same pin, another
  /// pin, or opening the row.
  String? _highlightedDiveId;
  final Map<String, GlobalKey> _rowKeys = {};

  TripStoryDay get day => widget.day;
  String get tripId => widget.tripId;
  bool get _isPlanned => day.kind == TripStoryDayKind.future;

  void _onPinTap(String? diveId) {
    setState(() => _highlightedDiveId = diveId);
    final keyContext = diveId == null ? null : _rowKeys[diveId]?.currentContext;
    if (keyContext == null) return;
    // Only when the row is below the fold: the rows sit under the map, so a
    // scroll for a row already in view would push the map off the top and
    // every next pin tap would start with scrolling back up.
    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);

    // Built once for the day's dives rather than per row.
    final diveTypeLabelResolver = watchDiveTypeLabelResolver(ref, context.l10n);
    final diveTypeShortLabelResolver = watchDiveTypeShortLabelResolver(
      ref,
      context.l10n,
    );
    final diveTypeListVisibilityPredicate =
        watchDiveTypeListVisibilityPredicate(ref);

    // The card is the whole chapter: the header row leads it, over the
    // day's map when there is one. A day with nothing else to show (a
    // surface day, a planned day with no plan) is just that row.
    final historySite = TripStoryDayPlan.historySite(day);
    final hasHistory =
        historySite != null &&
        (ref
                    .watch(siteHistoryByNameProvider(historySite))
                    .valueOrNull
                    ?.diveCount ??
                0) >
            0;
    final hasPlan = TripStoryDayPlan.hasContent(day, hasHistory: hasHistory);
    final hasMap = widget.mapPoints.isNotEmpty;
    final hasBody =
        day.dives.isNotEmpty ||
        day.media.isNotEmpty ||
        day.sightings.isNotEmpty ||
        hasPlan;

    // Today's card carries the header's emphasis down its edge; a day ahead
    // keeps the quiet outline that marks it as only a plan.
    final ShapeBorder? shape = switch (day.kind) {
      TripStoryDayKind.today => todayCardShape(theme),
      TripStoryDayKind.future => dayCardShape(
        theme,
        BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      TripStoryDayKind.past => null,
    };

    final header = TripStoryDayHeader(
      day: day,
      storedWeather: widget.storedWeather,
    );
    // With a map the header sits in its fade: the backdrop fills the stack,
    // which the padded header sizes, so the map runs mapPeekHeight above the
    // row and the fade is opaque under it. Scaled text grows the row and the
    // stack with it rather than pushing the row out of the opaque band.
    final Widget top = hasMap
        ? Stack(
            children: [
              // Resolved under the Card, so the fade ends in the colour the
              // card actually paints.
              Positioned.fill(
                child: Builder(
                  builder: (context) => HeaderMapBackdrop(
                    fadeColor: backdropColorOf(context),
                    child: TripDayMap(
                      day: day,
                      points: widget.mapPoints,
                      highlightedDiveId: _highlightedDiveId,
                      onDiveTap: _onPinTap,
                      // Panning and zooming live in the fullscreen view; in
                      // the card a drag scrolls the story.
                      interactive: false,
                      onExpand: widget.onExpandMap == null
                          ? null
                          : () => widget.onExpandMap!(day, widget.mapPoints),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  TripStoryDayCard.mapPeekHeight,
                  16,
                  0,
                ),
                child: header,
              ),
            ],
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: header,
          );

    return Card(
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: _isPlanned ? 0.85 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            top,
            // Three zones with deliberate visual weight: the day summary
            // (stats, rhythm, conditions) under the header, the dive rows as
            // the dominant middle, and captioned photo/species clusters at
            // the tail. Gaps follow the grouping: tight inside a zone, 16
            // between zones.
            Padding(
              padding: EdgeInsets.fromLTRB(16, hasBody ? 12 : 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The plan reads first: what the day was meant to be, then
                  // what it became.
                  if (hasPlan) ...[
                    TripStoryDayPlan(
                      day: day,
                      units: units,
                      hasHistory: hasHistory,
                    ),
                    if (day.dives.isNotEmpty) const SizedBox(height: 12),
                  ],
                  if (day.dives.isNotEmpty) ...[
                    _DaySummary(day: day, units: units),
                    const SizedBox(height: 12),
                    ...day.dives.mapIndexed(
                      (index, dive) => KeyedSubtree(
                        key: _rowKeys.putIfAbsent(dive.id, GlobalKey.new),
                        child: DiveListItem(
                          summary: DiveSummary.fromDive(dive),
                          diveTypeLabelResolver: diveTypeLabelResolver,
                          diveTypeShortLabelResolver:
                              diveTypeShortLabelResolver,
                          diveTypeListVisibilityPredicate:
                              diveTypeListVisibilityPredicate,
                          // Pass the story's Dive so the configurable card
                          // can resolve fields absent from the summary
                          // (tanks, SAC, buddies, weights). Its profile is
                          // empty unless the dive's row needed its samples
                          // (issue #3831).
                          fullDive: dive,
                          diveNumber: dive.diveNumber ?? index + 1,
                          isHighlighted: dive.id == _highlightedDiveId,
                          onTap: () {
                            if (_highlightedDiveId == dive.id) {
                              setState(() => _highlightedDiveId = null);
                            }
                            context.push('/dives/${dive.id}');
                          },
                        ),
                      ),
                    ),
                  ],
                  if (day.media.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCaption(
                      text: context.l10n.trips_photos_sectionTitle,
                    ),
                    const SizedBox(height: 6),
                    _PhotoStrip(
                      tripId: tripId,
                      media: day.media,
                      totalCount: day.mediaCount,
                    ),
                  ],
                  if (day.sightings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCaption(
                      text: context.l10n.trips_detail_stat_speciesSeen,
                    ),
                    const SizedBox(height: 6),
                    _SightingChips(day: day),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day-at-a-glance cluster: stat strip, 24h rhythm bar and conditions,
/// grouped by spacing alone under the header so the card's top reads as one
/// hero rather than a tinted box inside a card (#4106).
class _DaySummary extends StatelessWidget {
  final TripStoryDay day;
  final UnitFormatter units;

  const _DaySummary({required this.day, required this.units});

  @override
  Widget build(BuildContext context) {
    final conditions = DayConditions.fromDives(day.dives);
    return Column(
      key: const Key('day-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayStatStrip(day: day, units: units),
        const SizedBox(height: 10),
        DayRhythmBar(dives: day.dives),
        if (!conditions.isEmpty) ...[
          const SizedBox(height: 8),
          DayConditionsLine(conditions: conditions, units: units),
        ],
      ],
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
    final runtimeLabel = formatDayRuntime(day.totalRuntime);
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
  final int totalCount;

  const _PhotoStrip({
    required this.tripId,
    required this.media,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalCount - media.length;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length + (remaining > 0 ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index >= media.length) {
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
                    item: media[index],
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
