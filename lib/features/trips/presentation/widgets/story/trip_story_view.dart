import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_map_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_vessel_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const Duration _scrollThrottle = Duration(milliseconds: 100);

/// The assembled trip story: one pinned band (docked day plus map), hero and
/// day chapters.
class TripStoryView extends ConsumerStatefulWidget {
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
  ConsumerState<TripStoryView> createState() => _TripStoryViewState();
}

class _TripStoryViewState extends ConsumerState<TripStoryView>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late MapCameraAnimator _cameraAnimator;
  late List<GlobalKey> _dayKeys;
  int _activeDayIndex = 0;
  // Throttle keyed off the scheduler's frame timestamp (not DateTime.now) so it
  // advances with rendered frames -- real time on device, fake time in tests --
  // rather than wall-clock, which widget tests never advance.
  Duration _lastResolve = const Duration(days: -1);

  @override
  void initState() {
    super.initState();
    _cameraAnimator = MapCameraAnimator(
      vsync: this,
      controller: _mapController,
    );
    _buildKeys();
  }

  @override
  void didUpdateWidget(TripStoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.days.length != widget.story.days.length) {
      _buildKeys();
      // A refresh can shorten the story (e.g. a day's dives were reassigned).
      // Clamp the active index so the header still highlights a real day and
      // pointsForDay doesn't return empty until the next scroll resolves.
      final lastIndex = widget.story.days.length - 1;
      _activeDayIndex = _activeDayIndex.clamp(0, lastIndex < 0 ? 0 : lastIndex);
    }
  }

  void _buildKeys() {
    _dayKeys = List.generate(widget.story.days.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _cameraAnimator.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _selectDay(int index, {bool animateMap = true}) {
    if (index == _activeDayIndex) return;
    setState(() => _activeDayIndex = index);
    if (!animateMap) return;
    final points = widget.story.mapGeometry.pointsForDay(index);
    if (points.isEmpty) return;
    _cameraAnimator.animateTo(
      center: LatLng(points.first.latitude, points.first.longitude),
      zoom: _mapController.camera.zoom,
    );
  }

  // A named method (not an inline closure) so the delegate's onDaySelected has
  // a stable identity across builds; otherwise shouldRebuild always sees a new
  // closure and rebuilds the pinned FlutterMap on every parent rebuild.
  // Selects the day (easing the camera to its points) and scrolls the story to
  // that chapter, the reverse linkage the design spec calls for so tapping a
  // pin for an off-screen day brings both the map and the chapter into view.
  void _onPinSelected(int index) {
    _selectDay(index);
    _scrollToDay(index);
  }

  void _scrollToDay(int index) {
    if (index < 0 || index >= _dayKeys.length) return;
    final keyContext = _dayKeys[index].currentContext;
    if (keyContext == null) return;
    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  bool _onScroll(ScrollNotification notification) {
    // Horizontal photo strips inside the chapters bubble up their own scroll
    // notifications; ignore them so swiping photos doesn't move the map/active
    // day or consume the throttle window meant for the vertical story scroll.
    if (notification.metrics.axis != Axis.vertical) return false;
    // A scroll coming to rest always resolves, past the throttle. The throttle
    // keeps the first update of each window and drops the rest, so without
    // this the final positions of a fling were never resolved and the band
    // stayed a day behind until the next scroll.
    if (notification is ScrollEndNotification) {
      _resolveDockedDay(notification);
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (now - _lastResolve < _scrollThrottle) return false;
    _lastResolve = now;
    _resolveDockedDay(notification);
    return false;
  }

  void _resolveDockedDay(ScrollNotification notification) {
    final metrics = notification.metrics;
    // Day positions come from localToGlobal (screen coordinates), so anchor the
    // threshold to the scrollable's global top rather than 0: the story may sit
    // below the top of the screen (e.g. under an app bar).
    final scrollBox = notification.context?.findRenderObject() as RenderBox?;
    final viewportTop = (scrollBox != null && scrollBox.attached)
        ? scrollBox.localToGlobal(Offset.zero).dy
        : 0.0;
    final viewportBottom = viewportTop + metrics.viewportDimension;
    final band = _bandExtents(context).docked;

    // At the end of the scroll the last chapters can never climb to the line:
    // the story runs out first. The last day whose heading is at or above the
    // bottom of the screen docks instead, so the tail of a trip is not
    // permanently stranded. That heading is either on screen, or already past
    // the top with its own chapter filling the screen; no later heading can
    // be visible in that case, since every later day sits below it.
    if (metrics.pixels >= metrics.maxScrollExtent - 0.5) {
      for (var i = _dayKeys.length - 1; i >= 0; i--) {
        final top = _headingTop(i);
        if (top != null && top < viewportBottom) {
          _selectDay(i);
          return;
        }
      }
    }

    // The band names the day whose heading most recently crossed a line a
    // third of the way down the space below it: the day that has taken over
    // the screen. Waiting for the heading to reach the band itself switched
    // only as the day's top was about to scroll away, which read as late.
    final threshold =
        viewportTop + band + (metrics.viewportDimension - band) / 3;
    for (var i = _dayKeys.length - 1; i >= 0; i--) {
      final top = _headingTop(i);
      if (top != null && top <= threshold) {
        _selectDay(i);
        return;
      }
    }
    // Scrolled above the first chapter's threshold (near the top): fall back to
    // day 0 so the map doesn't stay stuck on a later day.
    if (_dayKeys.isNotEmpty) _selectDay(0);
  }

  /// Screen-space top of a day's chapter heading, or null when it is not
  /// mounted (scrolled far enough away to be culled).
  double? _headingTop(int index) {
    final keyContext = _dayKeys[index].currentContext;
    if (keyContext == null) return null;
    final box = keyContext.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  /// The band's heights for the current text scale, measured against the
  /// styles the docked panel actually renders with rather than assumed ones.
  TripStoryBandExtents _bandExtents(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TripStoryBandExtents.forScaler(
      MediaQuery.textScalerOf(context),
      title: textTheme.titleMedium,
      subtitle: textTheme.bodySmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.story.trip.id;
    // One read for the whole story, shared by the band's docked panel and
    // every chapter heading.
    final storedWeather =
        ref.watch(tripDayWeatherProvider(tripId)).asData?.value ??
        const <int, TripDayWeather>{};
    // Fire and forget: the backfill's writes come back through the provider
    // above via the table tick, so a row landing re-renders its day header.
    ref.watch(tripDayWeatherBackfillProvider(tripId));

    final extents = _bandExtents(context);
    // Built here rather than inside the delegate so a scroll that changes only
    // the band's shrink offset re-runs layout without rebuilding the map's
    // subtree. Its identity changes when the active day does, which is once
    // per chapter, not once per frame.
    final map = TripStoryMap(
      geometry: widget.story.mapGeometry,
      activeDayIndex: _activeDayIndex,
      mapController: _mapController,
      onDaySelected: _onPinSelected,
    );
    final days = widget.story.days;
    final dockedDay = days.isEmpty
        ? null
        : days[_activeDayIndex.clamp(0, days.length - 1)];

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: TripStoryBandDelegate(
              extents: extents,
              map: map,
              dockedDay: dockedDay,
              dockedWeather: dockedDay == null
                  ? null
                  : storedWeather[tripDayMillis(dockedDay.date)]
                        ?.toStoryWeather(),
              onDockedDayTap: dockedDay == null
                  ? null
                  : () => _scrollToDay(_activeDayIndex),
            ),
          ),
          SliverToBoxAdapter(
            child: TripStatStrip(stats: widget.stats, siteCount: _siteCount),
          ),
          ..._contentSlivers(storedWeather),
        ],
      ),
    );
  }

  /// Distinct dive sites visited across the whole trip (for the stat strip).
  int get _siteCount {
    final ids = <String>{};
    for (final day in widget.story.days) {
      for (final dive in day.dives) {
        final id = dive.site?.id;
        if (id != null) ids.add(id);
      }
    }
    return ids.length;
  }

  /// One day chapter: a SliverMainAxisGroup whose pinned header sticks below
  /// the map until the next day's group pushes it out. Every day gets the same
  /// header, surface days included - theirs simply has no body under it.
  Widget _daySliver(
    TripStory story,
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
    const divider = SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(child: _TodayDivider()),
    );
    // Ordinary scrolling content, not a PinnedHeaderSliver: the band is the
    // only pinned layer now, and it shows this same day in compact form once
    // the heading passes under it. Unconditional, even for days whose card
    // renders nothing (surface days, content-less planned days), because it
    // carries _dayKeys[index], which _onScroll and _scrollToDay read positions
    // from; dropping it would quietly take those days out of docked-day
    // resolution.
    final heading = SliverToBoxAdapter(
      child: KeyedSubtree(
        key: _dayKeys[index],
        child: TripStoryDayHeader(
          day: day,
          storedWeather: stored?.toStoryWeather(),
        ),
      ),
    );
    // Its 8px bottom inset is the gap between consecutive chapters; the
    // headings carry a surfaceContainer tint, so the page-surface gap reads as
    // air between one chapter's card and the next chapter's tinted band.
    final body = SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [TripStoryDayCard(day: day, tripId: story.trip.id)],
        ),
      ),
    );

    return SliverMainAxisGroup(
      slivers: [if (showTodayDivider) divider, heading, body],
    );
  }

  List<Widget> _contentSlivers(Map<int, TripDayWeather> storedWeather) {
    final story = widget.story;
    final trip = story.trip;
    final todayIndex = story.todayIndex;
    // Every non-liveaboard trip gets the closer, in every state. It is the
    // only editable checklist surface such a trip has, so gating it on the
    // checklist already holding items left no way to apply a template in the
    // first place, and gating it on the trip being over hid it from exactly
    // the trips a prep list is for (#1569). Liveaboards stay out: they get a
    // dedicated Checklist tab, and a second copy here would be two editors
    // for one list.
    final showChecklistAtEnd = !trip.isLiveaboard;
    // Open where the checklist is the point of the page: a trip still being
    // planned, or one with nothing in it yet and so nothing to collapse.
    final openChecklist = trip.isUpcoming || story.checklist.isEmpty;

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: TripStoryHero(
            story: story,
            onScanForDives: widget.onScanForDives,
          ),
        ),
      ),
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
      for (var index = 0; index < story.days.length; index++)
        _daySliver(story, index, todayIndex, storedWeather),
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
      if (showChecklistAtEnd)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              clipBehavior: Clip.antiAlias,
              // Open, the section wears its own header (title, progress and
              // the apply/save/clear menu), so an ExpansionTile title would
              // only repeat it. Collapsed, that title is the whole card.
              child: openChecklist
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: TripChecklistSection(trip: trip),
                    )
                  : ExpansionTile(
                      title: Text(
                        context.l10n.trips_story_checklistProgress(
                          story.checklist.done,
                          story.checklist.total,
                        ),
                        // Match the notes card's section title so the two
                        // closers read as one family (ListTile would
                        // otherwise swap in its own font role).
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TripChecklistSection(trip: trip),
                        ),
                      ],
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
