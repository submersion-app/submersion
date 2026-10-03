import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/presentation/pages/trip_day_map_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_summary_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The assembled trip story, one plain scroll (#2845): hero, stat strip, the
/// cylinders line while under way, and one chapter per day, each with its
/// own map.
class TripStoryView extends ConsumerWidget {
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

    return CustomScrollView(slivers: _contentSlivers(context, storedWeather));
  }

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

  /// One day chapter: the Today divider when it is today, its header, then
  /// its card (the day's own map, dives, photos, sightings). Every day gets
  /// the same header, surface days included; theirs simply has no body
  /// under it.
  Widget _dayChapter(
    BuildContext context,
    int index,
    int? todayIndex,
    Map<int, TripDayWeather> storedWeather,
  ) {
    final day = story.days[index];
    // Keyed through the same helper the repository stores under, so the
    // lookup cannot drift from the write. Computing the key inline here was
    // how the two came apart: it silently found nothing and every badge
    // disappeared.
    final stored = storedWeather[tripDayMillis(day.date)];
    final showTodayDivider = todayIndex != null && index == todayIndex;
    return Column(
      key: ValueKey(day.date),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTodayDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _TodayDivider(),
          ),
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

  List<Widget> _contentSlivers(
    BuildContext context,
    Map<int, TripDayWeather> storedWeather,
  ) {
    final trip = story.trip;
    final todayIndex = story.todayIndex;
    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: TripStoryHero(story: story, onScanForDives: onScanForDives),
        ),
      ),
      SliverToBoxAdapter(
        child: TripStatStrip(stats: stats, siteCount: _siteCount),
      ),
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
      if (trip.isLiveaboard)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(child: TripVesselSection(tripId: trip.id)),
        ),
      // Built lazily: each chapter carries a map that loads tiles, so only
      // the chapters near the viewport exist. Keyed by date, so a story whose
      // days shift (a new start, a dive before the trip) moves each day's
      // state with it rather than handing it to whichever day lands in its
      // slot.
      SliverList.builder(
        itemCount: story.days.length,
        itemBuilder: (context, index) =>
            _dayChapter(context, index, todayIndex, storedWeather),
        findChildIndexCallback: (key) {
          if (key is! ValueKey<DateTime>) return null;
          final index = story.days.indexWhere((d) => d.date == key.value);
          return index < 0 ? null : index;
        },
      ),
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
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

class _TodayDivider extends StatelessWidget {
  const _TodayDivider();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: colorScheme.primary)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              context.l10n.trips_story_today,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: colorScheme.primary)),
        ],
      ),
    );
  }
}
