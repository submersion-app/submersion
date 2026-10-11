import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/presentation/pages/trip_day_map_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_summary_card.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_anchored_scroll_view.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

/// The assembled trip story, one plain scroll (#2845): hero, stat strip, the
/// cylinders line while under way, and one chapter per day, each with its
/// own map. While the trip is under way it opens at today: today's chapter is
/// the scroll's anchor, with the hero and earlier days above it.
class TripStoryView extends ConsumerWidget {
  /// Marks the sliver that opens at the top of the view on a trip under way.
  static const _todayKey = ValueKey('trip-story-today');

  final TripStory story;
  final TripWithStats stats;
  final VoidCallback? onScanForDives;

  const TripStoryView({
    super.key,
    required this.story,
    required this.stats,
    this.onScanForDives,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripId = story.trip.id;
    // One read for the whole story, shared by every chapter heading.
    final storedWeather =
        ref.watch(tripDayWeatherProvider(tripId)).asData?.value ??
        const <int, TripDayWeather>{};
    // Fire and forget: the backfill's writes come back through the provider
    // above via the table tick, so a row landing re-renders its day header.
    ref.watch(tripDayWeatherBackfillProvider(tripId));

    return TodayAnchoredScrollView(
      center: _opensAtToday ? _todayKey : null,
      slivers: _contentSlivers(context, storedWeather),
    );
  }

  /// Whether the story opens at today: the trip is under way. A story can
  /// reach today without that (a dive logged today after the trip ended
  /// stretches its span), and such a trip opens at the top like any other.
  bool get _opensAtToday => story.todayIndex != null && story.trip.isInProgress;

  /// Distinct dive sites visited across the whole trip (for the stat strip).
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

  /// One day chapter: its header, then its card (the day's own map, dives,
  /// photos, sightings). Every day gets the same header, surface days
  /// included; theirs simply has no body under it. Today's header carries its
  /// own Today chip.
  Widget _dayChapter(
    BuildContext context,
    int index,
    Map<int, TripDayWeather> storedWeather,
  ) {
    final day = story.days[index];
    // Keyed through the same helper the repository stores under, so the
    // lookup cannot drift from the write. Computing the key inline here was
    // how the two came apart: it silently found nothing and every badge
    // disappeared.
    final stored = storedWeather[tripDayMillis(day.date)];
    return Column(
      key: ValueKey(day.date),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ordinary scrolling content: nothing on the story is pinned (#2845).
        TripStoryDayHeader(day: day, storedWeather: stored?.toStoryWeather()),
        // Its 8px bottom inset is the gap between consecutive chapters; the
        // headings carry a surfaceContainer tint, so the page-surface gap
        // reads as air between one chapter's card and the next chapter's
        // tinted band. The card gets the day's own map points.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TripStoryDayCard(
            key: ValueKey(day.date),
            day: day,
            tripId: story.trip.id,
            mapPoints: story.mapGeometry.pointsForDay(index),
            onExpandMap: (day, points) =>
                showTripDayMapPage(context, day: day, points: points),
          ),
        ),
      ],
    );
  }

  /// Day chapters [from] to [to] (exclusive), built lazily: each chapter
  /// carries a map that loads tiles, so only the chapters near the viewport
  /// exist. Keyed by date, so a story whose days shift (a new start, a dive
  /// before the trip) moves each day's state with it rather than handing it
  /// to whichever day lands in its slot.
  Widget _daysSliver(int from, int to, Map<int, TripDayWeather> storedWeather) {
    return SliverList.builder(
      itemCount: to - from,
      itemBuilder: (context, i) =>
          _dayChapter(context, from + i, storedWeather),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<DateTime>) return null;
        final index = story.days.indexWhere((d) => d.date == key.value);
        return index < from || index >= to ? null : index - from;
      },
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    Map<int, TripDayWeather> storedWeather,
  ) {
    final trip = story.trip;
    final todayIndex = _opensAtToday ? story.todayIndex : null;
    final header = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: TripStoryHero(story: story, onScanForDives: onScanForDives),
        ),
      ),
      SliverToBoxAdapter(
        child: TripStatStrip(stats: stats, siteCount: _siteCount),
      ),
    ];
    // The cards that matter while the trip is under way: what is left in the
    // cylinders, and how long until the no-fly window before the flight home.
    // When the story opens at today they open with it.
    final underWay = <Widget>[
      SliverToBoxAdapter(child: TripCylindersSummaryCard(trip: trip)),
      // Return-flight dive-window countdown, shown while the trip is
      // underway. The card hides itself once the flight departs.
      if (trip.returnFlightAt != null && trip.isInProgress)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: TripFlightCountdownCard(tripId: trip.id),
          ),
        ),
    ];
    final vessel = <Widget>[
      if (trip.isLiveaboard)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(child: TripVesselSection(tripId: trip.id)),
        ),
    ];
    final trailing = <Widget>[
      if (trip.notes.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.trips_detail_sectionTitle_notes,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(trip.notes),
                  ],
                ),
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        sliver: SliverToBoxAdapter(
          child: DocumentsSection(
            owner: DocumentOwner(DocumentOwnerKind.trip, trip.id),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
    final dayCount = story.days.length;
    if (todayIndex == null) {
      return [
        ...header,
        ...underWay,
        ...vessel,
        _daysSliver(0, dayCount, storedWeather),
        ...trailing,
      ];
    }
    // Opening at today: the center sliver starts with the under-way cards and
    // then today's chapter, so scroll offset 0 is the top of that group. The
    // list stays in reading order; the slivers before the center are laid
    // out upward from it, so a list there builds its index 0 nearest the
    // center: the earlier days are indexed yesterday first.
    return [
      ...header,
      ...vessel,
      SliverList.builder(
        itemCount: todayIndex,
        itemBuilder: (context, i) =>
            _dayChapter(context, todayIndex - 1 - i, storedWeather),
        // Keyed by date like the days below, so a shifted story moves each
        // earlier chapter's state with it.
        findChildIndexCallback: (key) {
          if (key is! ValueKey<DateTime>) return null;
          final index = story.days.indexWhere((d) => d.date == key.value);
          return index < 0 || index >= todayIndex
              ? null
              : todayIndex - 1 - index;
        },
      ),
      SliverMainAxisGroup(
        key: _todayKey,
        slivers: [
          ...underWay,
          _daysSliver(todayIndex, dayCount, storedWeather),
        ],
      ),
      ...trailing,
    ];
  }
}
