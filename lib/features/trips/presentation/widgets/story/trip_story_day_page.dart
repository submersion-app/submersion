import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';
import 'package:submersion/features/trips/presentation/pages/trip_day_map_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_conditions_line.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_map.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_sections.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_head.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_plan.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_under_way_cards.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One day of a trip, as a page of its own: the day's head, its map, its
/// plan, its timeline, its dives, then photos and species.
///
/// The day is the page. Nothing wraps it: no card, no tinted band, and the
/// dives are the diver's own dive cards sitting straight on the page. Today's
/// page, while the trip is under way, leads with the cylinders summary and
/// the return flight countdown, so the page a trip opens on shows the no-fly
/// countdown without a tap.
class TripStoryDayPage extends ConsumerStatefulWidget {
  const TripStoryDayPage({
    super.key,
    required this.story,
    required this.day,
    required this.mapPoints,
    this.storedWeather,
  });

  final TripStory story;
  final TripStoryDay day;

  /// The day's map points (`TripStoryMapGeometry.pointsForDay`); none hides
  /// the map.
  final List<TripStoryMapPoint> mapPoints;

  /// Weather stored for this day; null when nothing is stored yet.
  final TripStoryDayWeather? storedWeather;

  /// The width from which the map sits beside the dives.
  static const double twoColumnMinWidth = 600;

  static const noDivesKey = Key('trip-day-no-dives');
  static const twoColumnsKey = Key('trip-day-two-columns');

  @override
  ConsumerState<TripStoryDayPage> createState() => _TripStoryDayPageState();
}

class _TripStoryDayPageState extends ConsumerState<TripStoryDayPage> {
  /// The dive whose card a pin tap lit up; cleared by the same pin, another
  /// pin, or opening the card.
  String? _highlightedDiveId;
  final Map<String, GlobalKey> _cardKeys = {};

  TripStoryDay get _day => widget.day;

  void _onPinTap(String? diveId) {
    setState(() => _highlightedDiveId = diveId);
    final keyContext = diveId == null
        ? null
        : _cardKeys[diveId]?.currentContext;
    if (keyContext == null) return;
    // Only when the card is below the fold: a scroll for a card already in
    // view would push the map off the top and every next pin tap would start
    // with scrolling back up.
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
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final trip = widget.story.trip;
    final day = _day;

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
    final conditions = DayConditions.fromDives(day.dives);

    Widget? mapOf(double height) => widget.mapPoints.isEmpty
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: height,
              child: TripDayMap(
                day: day,
                points: widget.mapPoints,
                highlightedDiveId: _highlightedDiveId,
                onDiveTap: _onPinTap,
                // Panning and zooming live in the fullscreen view; on the
                // page a drag scrolls the page.
                interactive: false,
                onExpand: () => showTripDayMapPage(
                  context,
                  day: day,
                  points: widget.mapPoints,
                ),
              ),
            ),
          );

    // The plan reads first: what the day was meant to be, then what it
    // became.
    final plan = hasPlan
        ? TripStoryDayPlan(day: day, units: units, hasHistory: hasHistory)
        : null;
    final timeline = day.dives.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DayRhythmBar(dives: day.dives, units: units),
              if (!conditions.isEmpty) ...[
                const SizedBox(height: 8),
                DayConditionsLine(conditions: conditions, units: units),
              ],
            ],
          );
    final photos = day.media.isEmpty
        ? null
        : _captioned(
            l10n.trips_photos_sectionTitle,
            TripDayPhotoStrip(
              tripId: trip.id,
              media: day.media,
              totalCount: day.mediaCount,
            ),
          );
    final species = day.sightings.isEmpty
        ? null
        : _captioned(
            l10n.trips_detail_stat_speciesSeen,
            TripDaySightingChips(day: day),
          );
    final noDives = day.dives.isEmpty && !hasPlan
        ? Text(
            l10n.trips_story_noDivesThisDay,
            key: TripStoryDayPage.noDivesKey,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        : null;

    // Built here, in build, not in the LayoutBuilder below: the cards watch
    // providers, and that callback runs during layout, after this build has
    // already settled what it listens to.
    final dives = day.dives.isEmpty ? null : _dives(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Beside each other only when there is room and both sides have
        // something: a map with no dives beside it would face an empty
        // column. Measured, not asked of the platform, so a narrow desktop
        // window gets the single column too.
        final twoColumns =
            constraints.maxWidth >= TripStoryDayPage.twoColumnMinWidth &&
            widget.mapPoints.isNotEmpty &&
            day.dives.isNotEmpty;
        final Widget body = twoColumns
            ? Row(
                key: TripStoryDayPage.twoColumnsKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _stacked([
                      mapOf(230),
                      plan,
                      timeline,
                      photos,
                      species,
                    ]),
                  ),
                  const SizedBox(width: 16),
                  // A tapped pin lights up a card that is already in view.
                  Expanded(child: dives!),
                ],
              )
            : _stacked([
                mapOf(180),
                plan,
                timeline,
                dives,
                photos,
                species,
                noDives,
              ]);

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The cards pad themselves, as they do on the Trip page.
              if (day.kind == TripStoryDayKind.today && trip.isInProgress)
                TripUnderWayCards(trip: trip),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TripStoryDayHead(
                      day: day,
                      dayCount: widget.story.days.length,
                      storedWeather: widget.storedWeather,
                    ),
                    const SizedBox(height: 16),
                    body,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The sections that exist, one under the other, 16 apart.
  Widget _stacked(List<Widget?> sections) {
    final present = sections.nonNulls.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, section) in present.indexed) ...[
          if (index > 0) const SizedBox(height: 16),
          section,
        ],
      ],
    );
  }

  Widget _captioned(String caption, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      TripDaySectionCaption(text: caption),
      const SizedBox(height: 6),
      child,
    ],
  );

  /// The day's dives as the diver's own dive cards, the same card the Dives
  /// list, the Home page and search show.
  Widget _dives(BuildContext context) {
    // Built once for the day's dives rather than per card.
    final diveTypeLabelResolver = watchDiveTypeLabelResolver(ref, context.l10n);
    final diveTypeShortLabelResolver = watchDiveTypeShortLabelResolver(
      ref,
      context.l10n,
    );
    final diveTypeListVisibilityPredicate =
        watchDiveTypeListVisibilityPredicate(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._day.dives.mapIndexed(
          (index, dive) => KeyedSubtree(
            key: _cardKeys.putIfAbsent(dive.id, GlobalKey.new),
            child: DiveListItem(
              summary: DiveSummary.fromDive(dive),
              diveTypeLabelResolver: diveTypeLabelResolver,
              diveTypeShortLabelResolver: diveTypeShortLabelResolver,
              diveTypeListVisibilityPredicate: diveTypeListVisibilityPredicate,
              // Pass the story's Dive so the configurable card can resolve
              // fields absent from the summary (tanks, SAC, buddies,
              // weights). Its profile is empty unless the dive's row needed
              // its samples (issue #3831).
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
    );
  }
}
