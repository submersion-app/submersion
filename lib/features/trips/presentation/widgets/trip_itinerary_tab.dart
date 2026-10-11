import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_anchored_scroll_view.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Itinerary tab showing the day-by-day timeline of a trip, any type
/// (#2845): Generate fills the dates, each day opens its edit sheet.
///
/// Groups dives by date under each itinerary day. Each day row is tappable
/// to edit day type, port name, and notes via a bottom sheet.
class TripItineraryTab extends ConsumerWidget {
  /// Marks the sliver an in-progress trip opens on.
  static const _anchorKey = ValueKey('itinerary-today');

  final String tripId;

  const TripItineraryTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(numberedItineraryDaysProvider(tripId));
    final divesAsync = ref.watch(divesForTripProvider(tripId));
    // The trip types the days Generate writes and labels the sheet's place
    // field; a trip that is gone shows the list without the button.
    final trip = ref.watch(tripByIdProvider(tripId)).value;

    // Keep the list on a reload: the numbered itinerary rebuilds whenever
    // the itinerary, the trip or its dives change (an edit-sheet save among
    // them), and `when` shows its loading branch on a reload by default,
    // which would swap the list for a spinner and lose the scroll position.
    return daysAsync.when(
      skipLoadingOnReload: true,
      data: (days) => divesAsync.when(
        data: (dives) => _buildTimeline(context, ref, days, dives, trip),
        loading: () => const Center(child: CircularProgressIndicator()),
        // The repositories log the failure; the diver gets a plain line.
        error: (_, _) =>
            Center(child: Text(context.l10n.trips_itinerary_error_loading)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.l10n.trips_itinerary_error_loading)),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    WidgetRef ref,
    List<ItineraryDay> days,
    List<Dive> dives,
    Trip? trip,
  ) {
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.trips_itinerary_empty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (trip != null) ...[
                const SizedBox(height: 16),
                TripItineraryGenerateButton(trip: trip, days: days),
              ],
            ],
          ),
        ),
      );
    }

    // Group dives by date (year-month-day key)
    final divesByDate = <String, List<Dive>>{};
    for (final dive in dives) {
      // By entry time, as the story buckets its dives, so a dive and its
      // photos and sightings land on the same day's card.
      final key = _dateKey(dive.effectiveEntryTime);
      divesByDate.putIfAbsent(key, () => []).add(dive);
    }

    // Sort each group by time (creating sorted copies to avoid mutation)
    final sortedDivesByDate = divesByDate.map(
      (key, group) => MapEntry(
        key,
        List<Dive>.of(
          group,
        )..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime)),
      ),
    );

    // Photos and sightings come from the trip story, best effort: while it
    // loads or if it fails the cards simply go without their media line.
    final story = ref.watch(tripStoryProvider(tripId)).valueOrNull;
    final storyDays = <DateTime, TripStoryDay>{
      for (final d in story?.days ?? const <TripStoryDay>[]) tripDay(d.date): d,
    };
    final storedWeather =
        ref.watch(tripDayWeatherProvider(tripId)).asData?.value ??
        const <int, TripDayWeather>{};
    // Rebuilt at midnight, so the Today card moves on while the tab is open.
    final now = ref.watch(tripTodayProvider);

    // The fill-in button renders nothing once every date has a row.
    final header = trip == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TripItineraryGenerateButton(trip: trip, days: days),
            ),
          );

    Widget card(int index, {double bottomGap = 8}) {
      final day = days[index];
      final dayDives = sortedDivesByDate[_dateKey(day.date)] ?? [];
      final storyDay = storyDays[tripDay(day.date)];
      return ItineraryDayCard(
        day: day,
        dives: dayDives,
        tripId: tripId,
        isLiveaboard: trip?.isLiveaboard ?? false,
        kind: tripDayKind(day.date, now),
        media: storyDay?.media ?? const [],
        sightings: storyDay?.sightings ?? const [],
        storedWeather: storedWeather[tripDayMillis(day.date)]?.toStoryWeather(),
        bottomGap: bottomGap,
      );
    }

    Widget padded(Widget sliver) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: sliver,
    );

    final headerSliver = header == null
        ? null
        : padded(SliverToBoxAdapter(child: header));
    const gap = SliverToBoxAdapter(child: SizedBox(height: 16));
    final anchor = trip != null && trip.isInProgress
        ? itineraryAnchorIndex(days, now)
        : null;

    if (anchor == null) {
      return TodayAnchoredScrollView(
        slivers: [
          gap,
          ?headerSliver,
          padded(
            SliverList.builder(
              itemCount: days.length,
              itemBuilder: (context, i) => card(i),
            ),
          ),
          gap,
        ],
      );
    }
    // Opening at today: the anchor row starts the center sliver, so scroll
    // offset 0 is its top. The list stays in reading order; slivers before
    // the center are laid out upward from it, so the earlier rows' list
    // builds its index 0 nearest the center (the row just before today).
    return TodayAnchoredScrollView(
      center: _anchorKey,
      slivers: [
        gap,
        ?headerSliver,
        padded(
          SliverList.builder(
            itemCount: anchor,
            // The row just above today takes no gap of its own: the anchored
            // sliver's top padding is the gap, as between any two rows.
            itemBuilder: (context, i) =>
                card(anchor - 1 - i, bottomGap: i == 0 ? 0 : 8),
          ),
        ),
        SliverPadding(
          key: _anchorKey,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.builder(
            itemCount: days.length - anchor,
            itemBuilder: (context, i) => card(anchor + i),
          ),
        ),
        gap,
      ],
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

/// The row an in-progress trip opens on: the first dated today or later, so
/// a day without a row anchors on the next planned one. Null when every row
/// is in the past.
int? itineraryAnchorIndex(List<ItineraryDay> days, DateTime now) {
  final today = tripDay(now);
  final index = days.indexWhere((d) => !tripDay(d.date).isBefore(today));
  return index < 0 ? null : index;
}
