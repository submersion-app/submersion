import 'dart:async';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_profile_batcher.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/services/trip_picker_model.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_picker.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_trip_page.dart';

/// Which page of the trip story shows: the whole trip, or one day.
class TripStorySelection extends Equatable {
  /// The Trip page.
  const TripStorySelection.trip() : date = null;

  /// The page of the day on [date].
  const TripStorySelection.day(DateTime this.date);

  /// The selected day's date; null is the Trip page. A date, not an index,
  /// so a story whose days shift (a new start, a dive before the trip) keeps
  /// the day that was chosen.
  final DateTime? date;

  @override
  List<Object?> get props => [date];
}

/// The trip story, one day at a time: a fixed strip that draws the trip as
/// its dives, over one scrolling page that is either the whole trip or the
/// day picked in the strip.
///
/// A trip under way opens on today; every other trip opens on the Trip page.
/// The picker stays put while the page scrolls under it: changing day is a
/// tap, never a scroll back up to find the picker.
class TripStoryView extends ConsumerStatefulWidget {
  const TripStoryView({
    super.key,
    required this.story,
    required this.stats,
    this.selection,
    this.onScanForDives,
  });

  final TripStory story;
  final TripWithStats stats;

  /// Which page shows, held by whoever outlives this view. The trip page
  /// keeps it above its tabs, so that leaving for another tab and coming
  /// back returns to the same day. Null until a page is chosen; the view
  /// keeps a selection of its own when it is handed none.
  final ValueNotifier<TripStorySelection?>? selection;

  final VoidCallback? onScanForDives;

  @override
  ConsumerState<TripStoryView> createState() => _TripStoryViewState();
}

class _TripStoryViewState extends ConsumerState<TripStoryView> {
  ValueNotifier<TripStorySelection?>? _ownSelection;

  ValueNotifier<TripStorySelection?> get _selection =>
      widget.selection ?? (_ownSelection ??= ValueNotifier(null));

  TripStory get _story => widget.story;

  /// How many dives one profile request covers: the dive list's page size,
  /// so a long trip costs the batcher what scrolling the list would.
  static const _profilesPerRequest = 50;

  /// Counts the requests started, so a newer one ends an older one's loop.
  int _profileRequest = 0;

  @override
  void initState() {
    super.initState();
    _requestProfiles();
  }

  @override
  void didUpdateWidget(TripStoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new story is a new read of the trip: a dive was added, removed or
    // changed. Asking again is cheap, because the batcher skips every dive
    // it already holds samples for, and it is how a dive that has gained a
    // profile since loses its estimated outline.
    if (!identical(oldWidget.story, _story)) _requestProfiles();
  }

  @override
  void dispose() {
    _ownSelection?.dispose();
    super.dispose();
  }

  /// Asks the app's shared mini-profile batcher for every dive on the trip,
  /// a list page at a time in the story's order. The page is already on
  /// screen from the story alone; the picker's shapes arrive after.
  ///
  /// Started in a microtask: that is after the build this may be called
  /// from, and it does not wait for a frame, which a profile written while
  /// nothing on screen changes would never bring.
  void _requestProfiles() {
    final ids = [
      for (final day in _story.days)
        for (final dive in day.dives) dive.id,
    ];
    if (ids.isEmpty) return;
    final request = ++_profileRequest;
    unawaited(
      Future.microtask(() async {
        for (final page in ids.slices(_profilesPerRequest)) {
          if (!mounted || request != _profileRequest) return;
          await ref.read(diveProfileBatcherProvider).load(page);
        }
      }),
    );
  }

  /// The page a trip opens on before one is chosen: today while the trip is
  /// under way. A story can reach today without that (a dive logged today
  /// after the trip ended stretches its span), and such a trip opens on the
  /// Trip page like any other.
  TripStorySelection get _opening {
    final todayIndex = _story.todayIndex;
    return todayIndex != null && _story.trip.isInProgress
        ? TripStorySelection.day(_story.days[todayIndex].date)
        : const TripStorySelection.trip();
  }

  void _select(DateTime? date) => _selection.value = date == null
      ? const TripStorySelection.trip()
      : TripStorySelection.day(date);

  @override
  Widget build(BuildContext context) {
    final tripId = _story.trip.id;
    // A profile written for a dive on the trip: ask again, so its estimated
    // outline gives way to what was recorded.
    ref.listen(tripProfileWritesProvider, (_, next) {
      if (next.hasValue) _requestProfiles();
    });
    // One read for the whole story, shared by every day's head.
    final storedWeather =
        ref.watch(tripDayWeatherProvider(tripId)).asData?.value ??
        const <int, TripDayWeather>{};
    // Fire and forget: the backfill's writes come back through the provider
    // above via the table tick, so a row landing re-renders its day's head.
    ref.watch(tripDayWeatherBackfillProvider(tripId));

    return ValueListenableBuilder<TripStorySelection?>(
      valueListenable: _selection,
      builder: (context, chosen, _) {
        // The opening page is worked out here, never written back: writing
        // during build would notify mid-frame.
        final selection = chosen ?? _opening;
        final date = selection.date;
        // A day that is no longer part of the story (its last dive moved,
        // the trip's dates changed) falls back to the Trip page.
        final dayIndex = date == null
            ? -1
            : _story.days.indexWhere((day) => day.date == date);
        final day = dayIndex < 0 ? null : _story.days[dayIndex];

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= TripStoryDayPage.twoColumnMinWidth;
            return Column(
              children: [
                _Picker(
                  story: _story,
                  selectedDate: day?.date,
                  chartHeight: wide ? 76 : 60,
                  onSelect: _select,
                ),
                Expanded(
                  child: day == null
                      ? TripStoryTripPage(
                          story: _story,
                          stats: widget.stats,
                          onSelectDay: _select,
                          onScanForDives: widget.onScanForDives,
                        )
                      : TripStoryDayPage(
                          // Keyed by date: a new day starts at its top.
                          key: ValueKey(day.date),
                          story: _story,
                          day: day,
                          mapPoints: _story.mapGeometry.pointsForDay(dayIndex),
                          // Keyed through the same helper the repository
                          // stores under, so the lookup cannot drift from
                          // the write.
                          storedWeather: storedWeather[tripDayMillis(day.date)]
                              ?.toStoryWeather(),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The day picker, fed from the app's shared mini-profile cache.
///
/// It watches the cache itself, so a profile landing redraws the strip and
/// nothing else: the page under it is not rebuilt.
class _Picker extends ConsumerStatefulWidget {
  const _Picker({
    required this.story,
    required this.selectedDate,
    required this.chartHeight,
    required this.onSelect,
  });

  final TripStory story;
  final DateTime? selectedDate;
  final double chartHeight;
  final ValueChanged<DateTime?> onSelect;

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  /// Choosing a day rebuilds the picker; it does not change what it draws.
  final _model = TripPickerModelMemo();

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final profiles = ref.watch(batchProfileCacheProvider);
    final undived = ref.watch(tripUndivedPlanIdsProvider(story.trip.id));
    // Null until the read answers, and while it is failing: then a plan is
    // not drawn at all. Drawn solid, it would say it was dived.
    final undivedPlanIds = undived.valueOrNull;
    return TripDayPicker(
      days: story.days,
      model: _model.resolve(
        days: story.days,
        profiles: profiles,
        undivedPlanIds: undivedPlanIds,
      ),
      selectedDate: widget.selectedDate,
      onSelect: widget.onSelect,
      chartHeight: widget.chartHeight,
    );
  }
}
